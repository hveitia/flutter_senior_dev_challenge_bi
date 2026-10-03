import 'dart:async';
import 'dart:math';

import 'package:app_platform/src/async/delay.dart';
import 'package:app_platform/src/config/home_config.dart';
import 'package:app_platform/src/observability/telemetry.dart';
import 'package:app_platform/src/resilience/failure.dart';

/// Names used when reporting what the policy does. Events carry the service
/// and the attempt number only, never anything about the operation itself.
abstract final class ResilienceTelemetry {
  /// Event: an attempt did not answer in time.
  static const String timeout = 'resilience_timeout';

  /// Event: another attempt is about to start.
  static const String retry = 'resilience_retry';

  /// Event: the last allowed attempt failed too.
  static const String attemptsExhausted = 'resilience_attempts_exhausted';

  /// Event: this build applies the faults published in the configuration.
  /// It must never show up in production reports.
  static const String faultInjectionEnabled =
      'resilience_fault_injection_enabled';

  static const String serviceKey = 'service';
  static const String attemptKey = 'attempt';

  /// Service reported for an operation whose caller named none.
  static const String unnamedService = 'unnamed';
}

/// How every repository calls a backend: a timeout per attempt, retries with
/// backoff for operations that are safe to repeat, a signal when the answer
/// is taking long, and typed failures instead of plugin exceptions.
///
/// It is also the only place where the fault injection published in the
/// configuration takes effect, so a simulated outage goes through exactly the
/// same timeout and retry path as a real one. Injected faults are ignored
/// unless the build allows them explicitly.
final class ResiliencePolicy {
  ResiliencePolicy({
    ResilienceSettings Function()? faults,
    bool allowFaultInjection = false,
    bool Function()? isOffline,
    Telemetry telemetry = const NoopTelemetry(),
    Delay? delay,
    double Function()? random,
    this.timeout = defaultTimeout,
    this.slowThreshold = defaultSlowThreshold,
    this.baseBackoff = defaultBaseBackoff,
  }) : _faults = allowFaultInjection ? faults : null,
       _allowFaultInjection = allowFaultInjection,
       _isOffline = isOffline,
       _telemetry = telemetry,
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random().nextDouble;

  /// Attempts made for an idempotent operation before giving up.
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
  final bool _allowFaultInjection;
  final bool Function()? _isOffline;
  final Telemetry _telemetry;

  /// Waits for backoff and for injected latency. The timeout and the slow
  /// threshold use timers instead, so they can be cancelled.
  final Delay _delay;
  final double Function() _random;

  final StreamController<bool> _slowChanges =
      StreamController<bool>.broadcast();
  int _slowRuns = 0;
  bool _faultInjectionReported = false;

  /// `true` when a run in flight became slow, `false` once none is.
  Stream<bool> get slowChanges => _slowChanges.stream;

  /// Runs [operation] and returns its value or the failure that ended it.
  ///
  /// [idempotent] declares whether [operation] may run more than once without
  /// changing the outcome. Only then is it retried, up to [maxAttempts], after
  /// a timeout or an unavailable service. Anything else runs exactly once.
  ///
  /// The declaration matters because a timeout does not undo anything: the
  /// attempt is abandoned on the device, but a request that already left may
  /// still complete on the server. Retrying a transfer blindly could move the
  /// money twice, so operations that change state either pass `false` here or
  /// send an idempotency key that lets the server recognise the repetition.
  ///
  /// [serviceId] names the backend service, for reports and so fault
  /// injection can take that one service down. [onRetry] receives the number
  /// of the attempt about to start (2, then 3). [onSlow] fires at most once
  /// per run.
  Future<Result<T>> run<T>(
    Future<T> Function() operation, {
    required bool idempotent,
    String? serviceId,
    void Function(int attempt)? onRetry,
    void Function()? onSlow,
  }) async {
    _reportFaultInjectionOnce();

    final attemptsAllowed = idempotent ? maxAttempts : 1;
    final run = _Run(onSlow);
    try {
      for (var attempt = 1; ; attempt++) {
        if (_isOffline?.call() ?? false) {
          return const Failed(OfflineFailure());
        }
        if (attempt > 1) {
          _report(ResilienceTelemetry.retry, serviceId, attempt);
          onRetry?.call(attempt);
        }

        final outcome = await _attempt(operation, serviceId, run);
        switch (outcome) {
          case Success():
            return outcome;
          case Failed(:final failure):
            if (failure is TimeoutFailure) {
              _report(ResilienceTelemetry.timeout, serviceId, attempt);
            }
            if (!_isTransient(failure)) return outcome;
            if (attempt == attemptsAllowed) {
              if (idempotent) {
                _report(
                  ResilienceTelemetry.attemptsExhausted,
                  serviceId,
                  attempt,
                );
              }
              return outcome;
            }
        }

        await _delay(_backoff(attempt));
      }
    } finally {
      _endRun(run);
    }
  }

  /// One attempt, ended by whichever comes first: the operation or the
  /// timeout. Both timers are cancelled as soon as the attempt is over.
  Future<Result<T>> _attempt<T>(
    Future<T> Function() operation,
    String? serviceId,
    _Run run,
  ) async {
    final outcome = Completer<Result<T>>();
    void finish(Result<T> result) {
      if (!outcome.isCompleted) outcome.complete(result);
    }

    final slowTimer = Timer(slowThreshold, () => _markSlow(run));
    final timeoutTimer = Timer(
      timeout,
      () => finish(const Failed(TimeoutFailure())),
    );

    unawaited(
      _withInjectedFaults(
        operation,
        serviceId,
        isAbandoned: () => outcome.isCompleted,
      ).then(
        (value) => finish(Success(value)),
        onError: (Object error, StackTrace stackTrace) =>
            finish(Failed(_asFailure(error, stackTrace))),
      ),
    );

    try {
      return await outcome.future;
    } finally {
      slowTimer.cancel();
      timeoutTimer.cancel();
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

  AppFailure _asFailure(Object error, StackTrace stackTrace) => switch (error) {
    AppFailure() => error,
    TimeoutException() => const TimeoutFailure(),
    _ => UnexpectedFailure(error, stackTrace),
  };

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

  void _report(String event, String? serviceId, int attempt) {
    _telemetry.event(
      event,
      parameters: {
        ResilienceTelemetry.serviceKey:
            serviceId ?? ResilienceTelemetry.unnamedService,
        ResilienceTelemetry.attemptKey: attempt,
      },
    );
  }

  void _reportFaultInjectionOnce() {
    if (!_allowFaultInjection || _faultInjectionReported) return;
    _faultInjectionReported = true;
    _telemetry.event(ResilienceTelemetry.faultInjectionEnabled);
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
