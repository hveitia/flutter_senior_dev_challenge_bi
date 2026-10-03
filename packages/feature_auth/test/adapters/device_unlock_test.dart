import 'package:feature_auth/src/adapters/device_unlock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  group('LocalAuthBiometricAuthenticator', () {
    late _MockLocalAuthentication localAuth;
    late LocalAuthBiometricAuthenticator authenticator;

    setUp(() {
      localAuth = _MockLocalAuthentication();
      authenticator = LocalAuthBiometricAuthenticator(localAuth);
    });

    test(
      'is available with supported hardware and something enrolled',
      () async {
        when(localAuth.isDeviceSupported).thenAnswer((_) async => true);
        when(
          localAuth.getAvailableBiometrics,
        ).thenAnswer((_) async => [BiometricType.fingerprint]);

        expect(await authenticator.isAvailable(), isTrue);
      },
    );

    test('is not available when nothing is enrolled', () async {
      when(localAuth.isDeviceSupported).thenAnswer((_) async => true);
      when(localAuth.getAvailableBiometrics).thenAnswer((_) async => []);

      expect(await authenticator.isAvailable(), isFalse);
    });

    test('is not available on unsupported hardware', () async {
      when(localAuth.isDeviceSupported).thenAnswer((_) async => false);

      expect(await authenticator.isAvailable(), isFalse);
      verifyNever(localAuth.getAvailableBiometrics);
    });

    test('asks for biometrics only, with the given reason', () async {
      when(
        () => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenAnswer((_) async => true);

      final passed = await authenticator.authenticate(reason: 'Confirma');

      expect(passed, isTrue);
      verify(
        () => localAuth.authenticate(
          localizedReason: 'Confirma',
          biometricOnly: true,
        ),
      ).called(1);
    });
  });

  group('SharedPreferencesUnlockPreferences', () {
    late SharedPreferencesUnlockPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = SharedPreferencesUnlockPreferences(
        await SharedPreferences.getInstance(),
      );
    });

    test('is off until the customer turns it on', () async {
      expect(await preferences.isEnabled('uid-1'), isFalse);
    });

    test('remembers the choice per account', () async {
      await preferences.setEnabled('uid-1', enabled: true);

      expect(await preferences.isEnabled('uid-1'), isTrue);
      expect(await preferences.isEnabled('uid-2'), isFalse);
    });

    test('can be turned off again', () async {
      await preferences.setEnabled('uid-1', enabled: true);
      await preferences.setEnabled('uid-1', enabled: false);

      expect(await preferences.isEnabled('uid-1'), isFalse);
    });
  });
}
