import 'package:app_platform/app_platform.dart';

/// Names of what the transfers report. Events say what happened to an order
/// and why; never how much, between which accounts or for whom.
abstract final class TransfersTelemetry {
  /// The customer opened the transfer form.
  static const String started = 'transfer_started';

  /// The customer confirmed an order.
  static const String confirmed = 'transfer_confirmed';
  static const String completed = 'transfer_completed';

  /// Kept on the device because there was no connection.
  static const String queued = 'transfer_queued';

  /// The server refused it; carries the reason code.
  static const String rejected = 'transfer_rejected';

  /// The server could not be asked; carries the kind of failure.
  static const String notSent = 'transfer_not_sent';

  /// A queued order reached the server; carries the outcome.
  static const String queuedSettled = 'transfer_queued_settled';

  static const String provisioned = 'accounts_provisioned';
  static const String provisionFailed = 'accounts_provision_failed';

  /// How long the server took to settle an order.
  static const String settleTrace = 'transfer_settle';

  /// Reported when the server answers something the app cannot act on.
  static const String contractError = 'transfer_contract_error';

  static const String reasonKey = 'reason';
  static const String outcomeKey = 'outcome';

  static const String completedOutcome = 'completed';
  static const String rejectedOutcome = 'rejected';
  static const String queuedOutcome = 'queued';
  static const String notSentOutcome = 'not_sent';

  /// The service id of the customer API in the resilience policy.
  static const String service = 'transfers';

  /// The kind of failure, as a short word: nothing of its message.
  static String failureKind(AppFailure failure) => switch (failure) {
    OfflineFailure() => 'offline',
    TimeoutFailure() => 'timeout',
    ServiceUnavailableFailure() => 'unavailable',
    UnexpectedFailure() => 'unexpected',
  };
}
