/// Names of what the home reports. Parameters carry module types and
/// counts: never anything about the customer.
abstract final class HomeTelemetry {
  /// Event: the published configuration names a module type this version of
  /// the app cannot draw. Reported once per type and session.
  static const String moduleSkipped = 'home_module_skipped';

  /// Event: the customer asked the whole home to refresh.
  static const String refreshRequested = 'home_refresh_requested';

  /// Event: no module of the home had anything to show.
  static const String nothingToShow = 'home_nothing_to_show';

  static const String typeKey = 'type';
  static const String modulesKey = 'modules';
}
