import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_dependencies.dart';

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
  final unread = InboxItem(
    id: 'n-1',
    title: 'Nuevo inicio de sesión',
    body: 'Ingresaste desde tu dispositivo habitual.',
    kind: NotificationKind.security,
    destination: 'profile',
    createdAt: DateTime(2026, 10, 3, 8, 30),
    isRead: false,
  );

  late FakeAuthRepository auth;
  late TestDependencies app;

  Future<void> pumpSignedIn(WidgetTester tester) async {
    auth.restored = const ActiveSession(profile, unlockRequired: false);
    await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
    await tester.pumpAndSettle();
  }

  late FakeBiometricAuthenticator biometrics;

  setUp(() {
    auth = FakeAuthRepository();
    biometrics = FakeBiometricAuthenticator();
    app = TestDependencies(auth: auth, biometrics: biometrics);
  });

  const payment = PushMessage(
    title: 'Recibiste un pago',
    destination: 'accounts',
  );

  /// The accounts section is on screen and the home is not.
  void expectAccountsOpened() {
    expect(find.textContaining('Hola, Valentina'), findsNothing);
    expect(find.text('Cuentas'), findsWidgets);
  }

  group('a session that ends', () {
    setUp(() => app.messaging.current = NotificationPermission.granted);

    testWidgets('and starts again for the same customer registers the '
        'device again', (tester) async {
      await pumpSignedIn(tester);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(app.devices.saved, isEmpty);
      app.messaging.calls.clear();

      auth.announce(const ActiveSession(profile, unlockRequired: false));
      await tester.pumpAndSettle();

      expect(app.devices.saved, {'device-1': 'token-1'});
      expect(app.messaging.calls, contains('subscribe:segment-starting'));
    });

    testWidgets('without the customer pressing anything still stops the '
        'topic and deletes the address', (tester) async {
      await pumpSignedIn(tester);
      app.messaging.calls.clear();
      app.devices.calls.clear();

      // As a revoked or expired session is announced by the repository.
      auth.announce(const SignedOutSession());
      await tester.pumpAndSettle();

      expect(app.messaging.calls, [
        'unsubscribe:segment-starting',
        'deleteToken',
      ]);
      expect(app.devices.calls, isEmpty);
      expect(app.registrationMemory.uid, isNull);
    });
  });

  testWidgets('a phone the previous customer left registered is cleaned '
      'before the next one is registered on it', (tester) async {
    app.messaging.current = NotificationPermission.granted;
    await app.registrationMemory.save(
      uid: 'uid-previous',
      topics: {'segment-wealth'},
    );

    await pumpSignedIn(tester);

    expect(app.messaging.calls.take(2), [
      'unsubscribe:segment-wealth',
      'deleteToken',
    ]);
    expect(app.registrationMemory.uid, 'uid-1');
    expect(app.registrationMemory.topics, {'segment-starting'});
  });

  group('a notification tapped', () {
    testWidgets('while the session is locked waits behind the lock and is '
        'opened once the customer is in', (tester) async {
      auth.restored = const ActiveSession(profile, unlockRequired: true);
      biometrics.passes = false;
      await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
      await tester.pumpAndSettle();

      app.messaging.openedMessages.add(payment);
      await tester.pumpAndSettle();

      expect(find.text('Hola de nuevo, Valentina'), findsOneWidget);

      biometrics.passes = true;
      await tester.tap(find.text('Ingresar con huella o rostro'));
      await tester.pumpAndSettle();

      expectAccountsOpened();
    });

    testWidgets('with nobody signed in waits for a customer to sign in', (
      tester,
    ) async {
      await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
      await tester.pumpAndSettle();

      app.messaging.openedMessages.add(payment);
      await tester.pumpAndSettle();

      expect(find.text('Tu banco, sin filas ni sucursales'), findsOneWidget);

      auth.announce(const ActiveSession(profile, unlockRequired: false));
      await tester.pumpAndSettle();

      expectAccountsOpened();
    });

    testWidgets('behind a lock is dropped when that session ends, so it '
        'does not open for whoever signs in next', (tester) async {
      auth.restored = const ActiveSession(profile, unlockRequired: true);
      biometrics.passes = false;
      await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
      await tester.pumpAndSettle();
      app.messaging.openedMessages.add(payment);
      await tester.pumpAndSettle();

      // The locked session ends without ever being opened.
      auth.announce(const SignedOutSession());
      await tester.pumpAndSettle();

      auth.announce(const ActiveSession(profile, unlockRequired: false));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hola, Valentina'), findsOneWidget);
    });
  });

  testWidgets('the invitation does not appear over the lock', (tester) async {
    app.primerMemory.wasAnswered = false;
    auth.restored = const ActiveSession(profile, unlockRequired: true);
    biometrics.passes = false;

    await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
    await tester.pumpAndSettle();

    expect(find.text('Hola de nuevo, Valentina'), findsOneWidget);
    expect(find.text('Entérate al instante'), findsNothing);
    expect(app.messaging.prompts, 0);
  });

  testWidgets('the bell of the home says what is unread and opens the inbox', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    app.inbox.onRefresh = () async =>
        Success(InboxSnapshot(items: [unread], fromCache: false));
    await pumpSignedIn(tester);

    expect(find.bySemanticsLabel('Notificaciones, 1 sin leer'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Notificaciones, 1 sin leer'));
    await tester.pumpAndSettle();

    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('registers the device for the customer and follows their '
      'segment when the system already allows notifications', (tester) async {
    app.messaging.current = NotificationPermission.granted;

    await pumpSignedIn(tester);

    expect(app.devices.saved, {'device-1': 'token-1'});
    expect(app.messaging.calls, contains('subscribe:segment-starting'));
  });

  testWidgets('invites a customer the system has not asked, over the home, '
      'and "Ahora no" registers nothing', (tester) async {
    app.primerMemory.wasAnswered = false;

    await pumpSignedIn(tester);

    expect(find.text('Entérate al instante'), findsOneWidget);
    expect(app.messaging.prompts, 0);

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(find.text('Entérate al instante'), findsNothing);
    expect(find.textContaining('Hola, Valentina'), findsOneWidget);
    expect(app.devices.saved, isEmpty);
    expect(app.primerMemory.wasAnswered, isTrue);
  });

  testWidgets('accepting the invitation asks the system and registers the '
      'device', (tester) async {
    app.primerMemory.wasAnswered = false;
    await pumpSignedIn(tester);

    await tester.tap(find.text('Activar notificaciones'));
    await tester.pumpAndSettle();

    expect(app.messaging.prompts, 1);
    expect(app.devices.saved, {'device-1': 'token-1'});
    expect(find.textContaining('Hola, Valentina'), findsOneWidget);
  });

  testWidgets('forgets the device before the session is closed, so nothing '
      'sent to the customer reaches it afterwards', (tester) async {
    app.messaging.current = NotificationPermission.granted;
    await pumpSignedIn(tester);
    Map<String, String>? devicesWhenSessionClosed;
    List<String>? callsWhenSessionClosed;
    auth.onSignOut = () {
      devicesWhenSessionClosed = {...app.devices.saved};
      callsWhenSessionClosed = [...app.messaging.calls];
    };

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(devicesWhenSessionClosed, isEmpty);
    expect(
      callsWhenSessionClosed,
      containsAllInOrder(['unsubscribe:segment-starting', 'deleteToken']),
    );
  });

  testWidgets('a tapped notification opens the section it names', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    app.messaging.openedMessages.add(
      const PushMessage(title: 'Recibiste un pago', destination: 'accounts'),
    );
    await tester.pumpAndSettle();

    expect(find.text('SALDO TOTAL'), findsNothing);
    expect(find.text('Cuentas'), findsWidgets);
    expect(find.textContaining('Hola, Valentina'), findsNothing);
  });

  testWidgets('a tapped notification can open a partner mini app, like a '
      'home action would', (tester) async {
    await pumpSignedIn(tester);

    app.messaging.openedMessages.add(
      const PushMessage(
        title: 'Tu seguro de viaje',
        destination: 'partner:travelInsurance',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Servicio de Aliado Seguros'), findsOneWidget);
  });

  testWidgets('a tapped notification that names a place this build does not '
      'have opens the inbox', (tester) async {
    await pumpSignedIn(tester);

    app.messaging.openedMessages.add(
      const PushMessage(title: 'Aviso', destination: 'somewhere/else'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes notificaciones'), findsOneWidget);
  });

  for (final destination in ['transfer', 'partner:travelInsurance']) {
    testWidgets('a tapped notification for "$destination" opens the inbox '
        'when that feature is switched off', (tester) async {
      await pumpSignedIn(tester);
      final document = homeDocument(modules: const [], configVersion: 99);
      final segments = document['segments']! as Map<String, Object?>;
      (segments['starting']! as Map<String, Object?>)['features'] = {
        'transfers': false,
        'partnerServices': false,
      };
      app.config.publish(document);
      await tester.pumpAndSettle();

      app.messaging.openedMessages.add(
        PushMessage(title: 'Aviso', destination: destination),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes notificaciones'), findsOneWidget);
      expect(find.text('Servicio de Aliado Seguros'), findsNothing);
    });
  }
}
