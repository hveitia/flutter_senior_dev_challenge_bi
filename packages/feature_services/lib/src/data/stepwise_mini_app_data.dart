import 'package:feature_services/src/ports.dart';

/// One kind of data a partner's pages can leave on the device and how it is
/// removed. The name goes into the error when removing it fails.
typedef MiniAppDataStep = ({String name, Future<void> Function() run});

/// Remembers, across restarts of the app, that a clean-up was started and
/// has not finished.
abstract interface class PendingCleanUp {
  Future<bool> isPending();

  Future<void> setPending({required bool pending});
}

/// Thrown by [StepwiseMiniAppData.clear] when some data could not be
/// removed. It names the steps, never what they held.
final class MiniAppDataNotCleared implements Exception {
  const MiniAppDataNotCleared(this.failedSteps);

  final List<String> failedSteps;

  @override
  String toString() => 'MiniAppDataNotCleared(${failedSteps.join(', ')})';
}

/// [MiniAppData] as a list of independent steps, with a note that survives
/// a failure.
///
/// The note is written before the first step and erased only when every
/// step succeeded. If the app is killed in between, or a step fails, the
/// next customer's first mini app finds the note and cleans again before it
/// shows anything.
final class StepwiseMiniAppData implements MiniAppData {
  const StepwiseMiniAppData({
    required List<MiniAppDataStep> steps,
    required PendingCleanUp pending,
  }) : _steps = steps,
       _pending = pending;

  final List<MiniAppDataStep> _steps;
  final PendingCleanUp _pending;

  @override
  Future<void> clear() async {
    await _pending.setPending(pending: true);

    final failed = <String>[];
    for (final step in _steps) {
      try {
        await step.run();
      } on Object {
        // The rest still run: leaving the storage behind because the
        // cookies could not be removed would only keep more than necessary.
        failed.add(step.name);
      }
    }
    if (failed.isNotEmpty) throw MiniAppDataNotCleared(failed);

    await _pending.setPending(pending: false);
  }

  @override
  Future<void> clearIfPending() async {
    if (await _pending.isPending()) await clear();
  }
}
