import 'package:feature_auth/src/data/ports.dart';
import 'package:feature_auth/src/domain/biometric_authenticator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [BiometricAuthenticator] on the platform's biometric prompt.
final class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  const LocalAuthBiometricAuthenticator(this._localAuth);

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    if (!await _localAuth.isDeviceSupported()) return false;
    // Supported hardware with nothing enrolled cannot check anyone.
    return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
  }

  @override
  Future<bool> authenticate({required String reason}) {
    return _localAuth.authenticate(
      localizedReason: reason,
      // The device PIN is not accepted: the fallback is the account's own
      // password, which the app asks for after signing the session out.
      biometricOnly: true,
    );
  }
}

/// [UnlockPreferences] in the device preferences.
///
/// It stores one flag per account id. Neither is personal data, so plain
/// preferences are enough.
final class SharedPreferencesUnlockPreferences implements UnlockPreferences {
  const SharedPreferencesUnlockPreferences(this._preferences);

  static const String _prefix = 'feature_auth.biometric_unlock.';

  final SharedPreferences _preferences;

  @override
  Future<bool> isEnabled(String uid) async =>
      _preferences.getBool('$_prefix$uid') ?? false;

  @override
  Future<void> setEnabled(String uid, {required bool enabled}) =>
      _preferences.setBool('$_prefix$uid', enabled);
}
