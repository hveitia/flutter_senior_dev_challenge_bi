import 'package:app_platform/app_platform.dart';

/// Names of what the accounts feature reports. Parameters carry the service,
/// a failure kind, an origin and how many items there were: never an amount,
/// an account number, a description or a name.
abstract final class AccountsTelemetry {
  /// Trace: from opening the accounts until there is something to show.
  static const String accountsFirstLoad = 'accounts_first_load';

  /// Trace: from opening an account until its movements can be shown.
  static const String movementsFirstLoad = 'movements_first_load';

  /// Event: a data set could not be brought up to date.
  static const String loadFailed = 'accounts_data_load_failed';

  /// Event: the customer asked to try again after a failure.
  static const String retryRequested = 'accounts_data_retry_requested';

  /// Event: a data set was shown from the device's own copy.
  static const String servedFromCache = 'accounts_data_served_from_cache';

  static const String serviceKey = 'service';
  static const String reasonKey = 'reason';
  static const String countKey = 'count';
  static const String originKey = 'origin';
  static const String outcomeKey = 'outcome';

  /// Value of [outcomeKey] for a first load that ended without data.
  static const String failedOutcome = 'failed';

  /// Reason attached to an error nobody expected.
  static const String unexpectedError = 'accounts_unexpected';

  /// Backend services, as named to the resilience policy. They are distinct
  /// so one can be taken down, or fail, while the other keeps working.
  static const String accountsService = 'accounts';
  static const String movementsService = ServiceIds.movements;
}

/// Times how long a data set takes to have something to show.
///
/// It ends once: with the origin and the number of items when data is
/// shown, as failed when loading ends without data, or with no outcome when
/// the customer leaves first.
final class FirstLoadTrace {
  FirstLoadTrace(Telemetry telemetry, String name)
    : _trace = telemetry.startTrace(name);

  TelemetryTrace? _trace;

  void dataShown({required String origin, required int count}) {
    _trace
      ?..setAttribute(AccountsTelemetry.originKey, origin)
      ..setAttribute(AccountsTelemetry.countKey, '$count');
    end();
  }

  void failed() {
    _trace?.setAttribute(
      AccountsTelemetry.outcomeKey,
      AccountsTelemetry.failedOutcome,
    );
    end();
  }

  void end() {
    _trace?.stop();
    _trace = null;
  }
}
