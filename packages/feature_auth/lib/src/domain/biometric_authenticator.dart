/// The device's biometric check (fingerprint or face).
///
/// It confirms that the person holding the phone is one the device already
/// knows. It unlocks a session that exists; it never creates one.
abstract interface class BiometricAuthenticator {
  /// Whether the device has biometrics set up and ready to use.
  Future<bool> isAvailable();

  /// Shows the system prompt with [reason]. True only when the check passed.
  Future<bool> authenticate({required String reason});
}
