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

  setUp(() {
    auth = FakeAuthRepository();
    app = TestDependencies(auth: auth);
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

  testWidgets('a tapped notification that names a place this build does not '
      'have opens the inbox', (tester) async {
    await pumpSignedIn(tester);

    app.messaging.openedMessages.add(
      const PushMessage(title: 'Aviso', destination: 'somewhere/else'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes notificaciones'), findsOneWidget);
  });
}
