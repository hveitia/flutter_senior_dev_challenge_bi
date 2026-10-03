import 'package:app_platform/src/config/config_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last valid configuration in the device preferences.
///
/// The document holds no personal data (anyone signed in can read it), so
/// plain preferences are enough; nothing here needs the secure storage.
final class SharedPreferencesConfigStore implements ConfigStore {
  const SharedPreferencesConfigStore(this._preferences);

  static const String _key = 'app_platform.home_config';

  final SharedPreferences _preferences;

  @override
  Future<String?> read() async => _preferences.getString(_key);

  @override
  Future<void> write(String document) => _preferences.setString(_key, document);
}
