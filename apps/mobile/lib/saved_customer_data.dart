import 'dart:async';

import 'package:app_platform/app_platform.dart';

/// What the device keeps about a customer between two uses of the app: the
/// database's own saved copy and the times it was last in sync.
abstract interface class SavedCustomerData {
  /// Removes it all. It never fails: what could not be removed is reported
  /// and remembered as pending.
  Future<void> clear();

  /// Finishes a removal that was left pending, if there is one. Called
  /// before the first read of a new session, so a customer never starts
  /// over what a failed or timed-out removal left behind.
  Future<void> finishPending();
}

/// One run of a step. The runner abandons it when the step takes too long;
/// from then on the step must not act, however late its awaits complete.
final class StepRun {
  bool _isAbandoned = false;

  /// True once the runner stopped waiting for this run.
  bool get isAbandoned => _isAbandoned;

  void _abandon() => _isAbandoned = true;
}

/// One kind of saved data and how it is removed. The name goes into the
/// report when removing it fails.
typedef ClearStep = ({String name, Future<void> Function(StepRun run) run});

/// Remembers, across restarts, that a removal did not finish. One boolean
/// that says nothing about any customer.
abstract interface class PendingWipe {
  Future<bool> isPending();

  Future<void> setPending({required bool pending});
}

/// [SavedCustomerData] as a list of independent steps.
///
/// A step that fails is reported and the rest still run: leaving the
/// synchronization times behind because the database could not be cleared
/// would only keep more than necessary.
///
/// A step that takes longer than the timeout is abandoned, not cancelled:
/// its [StepRun] is flipped so it does nothing more, and the removal is
/// recorded as pending. A timeout is never a success: the data may still be
/// on the device, which is what the report and the pending mark say.
final class StepwiseSavedCustomerData implements SavedCustomerData {
  StepwiseSavedCustomerData({
    required List<ClearStep> steps,
    required Telemetry telemetry,
    required PendingWipe pending,
    Duration stepTimeout = defaultStepTimeout,
  }) : _steps = steps,
       _telemetry = telemetry,
       _pending = pending,
       _stepTimeout = stepTimeout;

  /// How long one kind of saved data may take to be removed before the
  /// clearing moves on without it.
  static const Duration defaultStepTimeout = Duration(seconds: 10);

  /// Event and error reason: a kind of saved data could not be removed.
  static const String clearFailed = 'saved_customer_data_clear_failed';
  static const String stepKey = 'step';

  /// Why it could not: the step threw, or it did not end in time and the
  /// data may still be on the device.
  static const String causeKey = 'cause';
  static const String causeError = 'error';
  static const String causeTimeout = 'timeout';

  final List<ClearStep> _steps;
  final Telemetry _telemetry;
  final PendingWipe _pending;
  final Duration _stepTimeout;

  /// The clearing in progress, if any. Two at once would close the database
  /// while the other one is removing its files.
  Future<void> _last = Future.value();

  @override
  Future<void> clear() {
    return _last = _last.then((_) => _runSteps());
  }

  @override
  Future<void> finishPending() {
    return _last = _last.then((_) async {
      if (await _isPending()) await _runSteps();
    });
  }

  Future<bool> _isPending() async {
    try {
      return await _pending.isPending();
    } on Object {
      // Not knowing is treated as pending: removing twice costs nothing.
      return true;
    }
  }

  Future<void> _mark({required bool pending}) async {
    try {
      await _pending.setPending(pending: pending);
    } on Object catch (error, stackTrace) {
      _telemetry.recordError(
        RedactedError(error.runtimeType),
        stackTrace,
        reason: clearFailed,
      );
    }
  }

  Future<void> _runSteps() async {
    // Marked before the first step, so an app killed half way finishes the
    // removal the next time it starts.
    await _mark(pending: true);

    var removedAll = true;
    for (final step in _steps) {
      final run = StepRun();
      try {
        await step.run(run).timeout(_stepTimeout);
      } on TimeoutException catch (error, stackTrace) {
        // The step is still running somewhere. It is told to do nothing
        // more, so it cannot act on the next customer's data later.
        run._abandon();
        removedAll = false;
        _report(step.name, causeTimeout, error, stackTrace);
      } on Object catch (error, stackTrace) {
        removedAll = false;
        _report(step.name, causeError, error, stackTrace);
      }
    }

    if (removedAll) await _mark(pending: false);
  }

  void _report(String step, String cause, Object error, StackTrace stackTrace) {
    _telemetry
      ..event(clearFailed, parameters: {stepKey: step, causeKey: cause})
      // The message may name the customer or a file path.
      ..recordError(
        RedactedError(error.runtimeType),
        stackTrace,
        reason: clearFailed,
      );
  }
}

/// The step that removes the database's saved copy from the device.
///
/// The database refuses to delete its files while it is running, so it is
/// shut down first; the next read starts it again by itself. [afterCleared]
/// puts back what a fresh instance loses (the emulator address of a local
/// stack).
///
/// Each action is preceded by a look at [StepRun.isAbandoned]: a shutdown
/// that hangs past the timeout and completes later must not go on to shut
/// down or erase the database the next customer is already using.
Future<void> Function(StepRun run) clearDatabaseStep({
  required Future<void> Function() terminate,
  required Future<void> Function() clearPersistence,
  void Function()? afterCleared,
}) {
  return (run) async {
    if (run.isAbandoned) return;
    await terminate();
    if (run.isAbandoned) return;
    await clearPersistence();
    if (run.isAbandoned) return;
    afterCleared?.call();
  };
}
