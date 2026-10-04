import 'package:feature_accounts/src/data/ports.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SyncTimes] in the device's preferences, kept apart per customer.
///
/// Only moments are stored, never data: what was synchronized stays in the
/// database's own saved copy.
final class SharedPreferencesSyncTimes implements SyncTimes {
  const SharedPreferencesSyncTimes(this._preferences, {required this.uid});

  static const String _prefix = 'accounts.synced_at';

  final SharedPreferences _preferences;
  final String uid;

  /// The preference that holds the time of [dataSet] for the customer.
  static String keyFor(String uid, String dataSet) => '$_prefix.$uid.$dataSet';

  /// Removes the times of every customer. The times are keyed by customer,
  /// so leaving them behind would keep a trace of who used the device.
  static Future<void> clearAll(SharedPreferences preferences) async {
    final keys = preferences.getKeys().where(
      (key) => key.startsWith('$_prefix.'),
    );
    for (final key in keys.toList()) {
      await preferences.remove(key);
    }
  }

  @override
  DateTime? lastSync(String dataSet) {
    return switch (_preferences.get(keyFor(uid, dataSet))) {
      final int milliseconds => DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
      ),
      _ => null,
    };
  }

  @override
  Future<void> record(String dataSet, DateTime at) async {
    await _preferences.setInt(keyFor(uid, dataSet), at.millisecondsSinceEpoch);
  }
}
