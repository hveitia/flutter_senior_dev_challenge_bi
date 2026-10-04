/// Names used when reporting what happens with partners' mini apps.
///
/// An event says which service, and at most a reason, a range of time or
/// the origin of an address. Nothing the customer typed into a partner's
/// page, and nothing the page answered, is ever reported.
abstract final class ServicesTelemetry {
  /// Event: the customer opened a mini app.
  static const String opened = 'mini_app_opened';

  /// Event: the partner's page finished loading.
  static const String loaded = 'mini_app_loaded';

  /// Event: the page tried to leave the partner's origin and was kept from
  /// it.
  static const String navigationBlocked = 'mini_app_navigation_blocked';

  /// Event: the mini app could not be shown.
  static const String unavailable = 'mini_app_unavailable';

  /// Event: the page reported that the customer finished.
  static const String completed = 'mini_app_completed';

  /// Event: the page posted something that is not a message of the
  /// contract.
  static const String messageDropped = 'mini_app_message_dropped';

  static const String serviceKey = 'service';
  static const String durationKey = 'duration';
  static const String originKey = 'origin';
  static const String reasonKey = 'reason';

  /// Reported as the origin of an address that has none, such as
  /// `javascript:`.
  static const String noOrigin = 'none';
}
