/// Names of what the notifications feature reports. Parameters carry a kind,
/// a result, a step or a failure reason: never a title, a body, a token or
/// who the customer is.
abstract final class NotificationsTelemetry {
  /// Event: the invitation to turn notifications on was shown.
  static const String primerShown = 'notifications_primer_shown';

  /// Event: the customer accepted the invitation.
  static const String primerAccepted = 'notifications_primer_accepted';

  /// Event: the customer chose "Ahora no".
  static const String primerDeclined = 'notifications_primer_declined';

  /// Event: what the system answered after its own prompt.
  static const String permissionResult = 'notifications_permission_result';

  /// Event: this device was registered for the customer.
  static const String deviceRegistered = 'notifications_device_registered';

  /// Event: a step of registering or forgetting the device failed.
  static const String deviceFailed = 'notifications_device_failed';

  /// Event: the customer opened a notification.
  static const String opened = 'notification_opened';

  /// Event: the inbox could not be brought up to date.
  static const String loadFailed = 'notifications_load_failed';

  static const String resultKey = 'result';
  static const String stepKey = 'step';
  static const String kindKey = 'kind';
  static const String reasonKey = 'reason';

  /// Where the notification was opened from, as [sourceKey].
  static const String sourceKey = 'source';
  static const String fromInbox = 'inbox';
  static const String fromSystem = 'system';

  /// Reason attached to an error nobody expected.
  static const String unexpectedError = 'notifications_unexpected';

  /// The backend service, as named to the resilience policy.
  static const String service = 'notifications';
}
