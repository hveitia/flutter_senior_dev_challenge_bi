import 'package:banca_digital/app.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_saved_customer_data.dart';
import 'support/test_dependencies.dart';

/// Closing a session takes several clean-ups from different domains. Their
/// order is a contract: each step needs what the next one removes.
void main() {
  const profile = UserProfile(
    uid: 'uid-1',
    email: 'valentina@example.com',
    fullName: 'Valentina Andrade',
    nationalId: '1710034065',
    phone: '0991234567',
    segment: Segment.starting,
    interests: {},
  );

  testWidgets('closing the session stops the configuration, forgets the '
      'device, signs out and only then removes what the device saved', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final savedData = FakeSavedCustomerData();
    final app = TestDependencies(auth: auth, savedData: savedData);
    app.messaging.current = NotificationPermission.granted;
    auth.restored = const ActiveSession(profile, unlockRequired: false);
    await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
    await tester.pumpAndSettle();
    expect(app.config.hasListener, isTrue);
    expect(app.devices.saved, isNotEmpty);
    final clearsBefore = savedData.clears;

    final steps = <String>[];
    bool? configListenedAtSignOut;
    Map<String, String>? devicesAtSignOut;
    List<String>? messagingAtSignOut;
    auth.onSignOut = () {
      steps.add('sign-out');
      configListenedAtSignOut = app.config.hasListener;
      devicesAtSignOut = {...app.devices.saved};
      messagingAtSignOut = [...app.messaging.calls];
    };
    savedData.onClear = () => steps.add('wipe');

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(steps, ['sign-out', 'wipe']);
    expect(configListenedAtSignOut, isFalse);
    expect(devicesAtSignOut, isEmpty);
    expect(
      messagingAtSignOut,
      containsAllInOrder(['unsubscribe:segment-starting', 'deleteToken']),
    );
    expect(savedData.clears, clearsBefore + 1);
  });

  testWidgets('a session that ends by itself still cleans the device and '
      'removes what it saved', (tester) async {
    final auth = FakeAuthRepository();
    final savedData = FakeSavedCustomerData();
    final app = TestDependencies(auth: auth, savedData: savedData);
    app.messaging.current = NotificationPermission.granted;
    auth.restored = const ActiveSession(profile, unlockRequired: false);
    await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
    await tester.pumpAndSettle();
    final clearsBefore = savedData.clears;
    app.messaging.calls.clear();

    // Revoked or expired: nobody pressed "Cerrar sesión".
    auth.announce(const SignedOutSession());
    await tester.pumpAndSettle();

    expect(
      app.messaging.calls,
      containsAllInOrder(['unsubscribe:segment-starting', 'deleteToken']),
    );
    expect(savedData.clears, clearsBefore + 1);
    expect(app.config.hasListener, isFalse);
  });
}
