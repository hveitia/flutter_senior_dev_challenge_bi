import 'package:app_platform/app_platform.dart';

/// What the device keeps about a customer between two uses of the app: the
/// database's own saved copy and the times it was last in sync.
// Kept as an interface so tests can replace it with a named fake.
// ignore: one_member_abstracts
abstract interface class SavedCustomerData {
  /// Removes it all. It never fails: what could not be removed is reported.
  Future<void> clear();
}

/// One kind of saved data and how it is removed. The name goes into the
/// report when removing it fails.
typedef ClearStep = ({String name, Future<void> Function() run});

/// [SavedCustomerData] as a list of independent steps.
///
/// A step that fails is reported and the rest still run: leaving the
/// synchronization times behind because the database could not be cleared
/// would only keep more than necessary.
final class StepwiseSavedCustomerData implements SavedCustomerData {
  StepwiseSavedCustomerData({
    required List<ClearStep> steps,
    required Telemetry telemetry,
  }) : _steps = steps,
       _telemetry = telemetry;

  /// Event and error reason: a kind of saved data could not be removed.
  static const String clearFailed = 'saved_customer_data_clear_failed';
  static const String stepKey = 'step';

  final List<ClearStep> _steps;
  final Telemetry _telemetry;

  /// The clearing in progress, if any. Two at once would close the database
  /// while the other one is removing its files.
  Future<void> _last = Future.value();

  @override
  Future<void> clear() {
    return _last = _last.then((_) => _runSteps());
  }

  Future<void> _runSteps() async {
    for (final step in _steps) {
      try {
        await step.run();
      } on Object catch (error, stackTrace) {
        _telemetry
          ..event(clearFailed, parameters: {stepKey: step.name})
          // The message may name the customer or a file path.
          ..recordError(
            RedactedError(error.runtimeType),
            stackTrace,
            reason: clearFailed,
          );
      }
    }
  }
}
