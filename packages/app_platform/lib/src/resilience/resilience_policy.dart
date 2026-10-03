import 'dart:async';
import 'dart:math';

import 'package:app_platform/src/async/delay.dart';
import 'package:app_platform/src/config/home_config.dart';
import 'package:app_platform/src/resilience/failure.dart';

/// How every repository calls a backend: a timeout per attempt, a bounded
/// number of retries with backoff, a signal when the answer is taking long,
/// and typed failures instead of plugin exceptions.
///
/// It is also the only place where the fault injection published in the
/// configuration takes effect, so a simulated outage goes through exactly the
/// same timeout and retry path as a real one.
final class ResiliencePolicy {
  ResiliencePolicy({
    ResilienceSettings Function()? faults,
    bool Function()? isOffline,
    Delay? delay,
    double Function()? random,
    this.timeout = defaultTimeout,
    this.slowThreshold = defaultSlowThreshold,
    this.baseBackoff = defaultBaseBackoff,
  }) : _faults = faults,
       _isOffline = isOffline,
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random().nextDouble;

  static const int maxAttempts = 3;
  static const Duration defaultTimeout = Duration(seconds: 8);
  static const Duration defaultSlowThreshold = Duration(seconds: 3);
  static const Duration defaultBaseBackoff = Duration(milliseconds: 400);

  /// Time allowed to each attempt, injected latency included.
  final Duration timeout;

  /// How long an attempt may take before the run is reported as slow.
  final Duration slowThreshold;

  /// Nominal wait before the second attempt. It doubles on each retry.
  final Duration baseBackoff;

  final ResilienceSettings Function()? _faults;
  final bool Function()? _isOffline;
  final Delay _delay;
  final double Function() _random;

  final StreamController<bool> _slowChanges =
      StreamController<bool>.broadcast();
  int _slowRuns = 0;

  /// `true` when a run in flight became slow, `false` once none is.
  Stream<bool> get slowChanges => _slowChanges.stream;

  /// Runs [operation] and returns its value or the failure that ended it.
  ///
  /// [serviceId] names the backend service, so fault injection can take that
  /// one service down. [onRetry] receives the number of the attempt about to
  /// start (2, then 3). [onSlow] fires at most once per run.
  Future<Result<T>> run<T>(
    Future<T> Function() operation, {
    String? serviceId,
    void Function(int attempt)? onRetry,
    void Function()? onSlow,
  }) async {
    final run = _Run(onSlow);
    try {
      for (var attempt = 1; ; attempt++) {
        if (_isOffline?.call() ?? false) {
          return const Failed(OfflineFailure());
        }
        if (attempt > 1) onRetry?.call(attempt);

        final outcome = await _attempt(operation, serviceId, run);
        switch (outcome) {
          case Success():
            return outcome;
          case Failed(:final failure):
            final canRetry = _isTransient(failure) && attempt < maxAttempts;
            if (!canRetry) return outcome;
        }

        await _delay(_backoff(attempt));
      }
    } finally {
      _endRun(run);
    }
  }

  Future<Result<T>> _attempt<T>(
    Future<T> Function() operation,
    String? serviceId,
    _Run run,
  ) async {
    var finished = false;
    unawaited(
      _delay(slowThreshold).then((_) {
        if (!finished) _markSlow(run);
      }),
    );

    try {
      final value = await Future.any<T>([
        _withInjectedFaults(operation, serviceId, isAbandoned: () => finished),
        _delay(timeout).then((_) => throw const TimeoutFailure()),
      ]);
      return Success(value);
    } on AppFailure catch (failure) {
      return Failed(failure);
    } on TimeoutException {
      return const Failed(TimeoutFailure());
    } on Object catch (error, stackTrace) {
      return Failed(UnexpectedFailure(error, stackTrace));
    } finally {
      finished = true;
    }
  }

  Future<T> _withInjectedFaults<T>(
    Future<T> Function() operation,
    String? serviceId, {
    required bool Function() isAbandoned,
  }) async {
    final faults = _faults?.call() ?? ResilienceSettings.none;

    if (faults.latency > Duration.zero) {
      await _delay(faults.latency);
      // The attempt already timed out while waiting: starting the operation
      // now would send a request whose answer nobody is waiting for.
      if (isAbandoned()) throw const TimeoutFailure();
    }
    if (serviceId != null && faults.isUnavailable(serviceId)) {
      throw ServiceUnavailableFailure(serviceId);
    }
    return operation();
  }

  bool _isTransient(AppFailure failure) => switch (failure) {
    TimeoutFailure() || ServiceUnavailableFailure() => true,
    OfflineFailure() || UnexpectedFailure() => false,
  };

  /// Exponential backoff with jitter: between half and the whole of the
  /// nominal wait, so clients that failed together do not retry together.
  Duration _backoff(int failedAttempt) {
    final nominal = baseBackoff * pow(2, failedAttempt - 1);
    final half = nominal ~/ 2;
    return half + half * _random();
  }

  void _markSlow(_Run run) {
    if (run.isSlow) return;
    run.isSlow = true;
    run.onSlow?.call();
    if (_slowRuns++ == 0) _slowChanges.add(true);
  }

  void _endRun(_Run run) {
    if (!run.isSlow) return;
    if (--_slowRuns == 0) _slowChanges.add(false);
  }
}

/// State of one call to [ResiliencePolicy.run].
final class _Run {
  _Run(this.onSlow);

  final void Function()? onSlow;
  bool isSlow = false;
}
