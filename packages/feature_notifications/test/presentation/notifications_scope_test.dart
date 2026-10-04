import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/testing.dart';

void main() {
  late FakePushMessaging messaging;
  late FakeDeviceStore devices;
  late FakePrimerMemory memory;
  late InMemoryTelemetry telemetry;
  late FakeDestinationResolver resolver;
  DeviceRegistrar? created;
  OpenedNotifications? tapped;
  late int inboxOpened;
  late int invitations;

  Widget scope({String segmentId = 'family'}) {
    return RepositoryProvider<Telemetry>.value(
      value: telemetry,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NotificationsScope(
            repository: FakeNotificationsRepository(),
            // Built inside the test's own zone: a future made in setUp
            // would never complete under the test's fake clock.
            registrar: created ??= DeviceRegistrar(
              uid: 'uid-1',
              memory: FakeRegistrationMemory(),
              messaging: messaging,
              devices: devices,
              identity: const FakeDeviceIdentity(),
            ),
            messaging: messaging,
            opened: tapped ??= OpenedNotifications(messaging)..start(),
            memory: memory,
            settings: FakeSystemSettings(),
            segmentId: segmentId,
            destinations: resolver,
            onOpenInbox: (_) => inboxOpened++,
            onInvite: (_) => invitations++,
            child: const Text('Inicio'),
          ),
        ),
      ),
    );
  }

  setUp(() {
    messaging = FakePushMessaging(current: NotificationPermission.granted);
    devices = FakeDeviceStore();
    memory = FakePrimerMemory();
    telemetry = InMemoryTelemetry();
    resolver = FakeDestinationResolver(available: {'accounts'});
    created = null;
    tapped = null;
    inboxOpened = 0;
    invitations = 0;
  });

  testWidgets('registers the device for the customer when the system '
      'already allows notifications', (tester) async {
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();

    expect(devices.saved, {'device-1': 'token-1'});
    expect(messaging.calls, contains('subscribe:segment-family'));
    expect(invitations, 0);
  });

  testWidgets('invites once a customer the system has not asked, and '
      'registers nothing meanwhile', (tester) async {
    messaging.current = NotificationPermission.notAsked;

    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();

    expect(invitations, 1);
    expect(devices.saved, isEmpty);
    expect(messaging.prompts, 0);
  });

  testWidgets('does not invite a customer who already answered on this '
      'device', (tester) async {
    messaging.current = NotificationPermission.notAsked;
    memory.wasAnswered = true;

    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();

    expect(invitations, 0);
  });

  testWidgets('follows the new topic when the customer changes segment', (
    tester,
  ) async {
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();

    await tester.pumpWidget(scope(segmentId: 'wealth'));
    await tester.pumpAndSettle();

    expect(
      messaging.calls.where((call) => call.contains('subscribe')).toList(),
      [
        'subscribe:segment-family',
        'unsubscribe:segment-family',
        'subscribe:segment-wealth',
      ],
    );
  });

  testWidgets('a tapped notification opens its destination and reports the '
      'kind only', (tester) async {
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();

    messaging.openedMessages.add(
      const PushMessage(
        title: 'Recibiste un pago',
        destination: 'accounts',
        kind: NotificationKind.movement,
      ),
    );
    await tester.pump();

    expect(resolver.opened, ['accounts']);
    expect(inboxOpened, 0);
    final opened = telemetry.events.singleWhere(
      (event) => event.name == NotificationsTelemetry.opened,
    );
    expect(opened.parameters, {
      NotificationsTelemetry.kindKey: 'movement',
      NotificationsTelemetry.sourceKey: NotificationsTelemetry.fromSystem,
    });
  });

  testWidgets('a destination this build cannot open leads to the inbox', (
    tester,
  ) async {
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();

    messaging.openedMessages.add(
      const PushMessage(title: 'Aviso', destination: 'loans'),
    );
    await tester.pump();

    expect(resolver.opened, isEmpty);
    expect(inboxOpened, 1);
  });

  testWidgets('the notification that started the app is opened too', (
    tester,
  ) async {
    messaging.initial = const PushMessage(title: 'Aviso', destination: '');

    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();

    expect(inboxOpened, 1);
  });

  testWidgets('a push that arrives with the app open is said on screen and '
      'leads to the inbox', (tester) async {
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();

    messaging.foregroundMessages.add(
      const PushMessage(title: 'Recibiste un pago', destination: 'accounts'),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Recibiste un pago'), findsOneWidget);

    await tester.tap(find.text('Ver'));

    expect(inboxOpened, 1);
  });

  testWidgets('a notification tapped before the customer could see their '
      'screens is opened once they can, and only once', (tester) async {
    tapped = OpenedNotifications(messaging)..start();
    messaging.openedMessages.add(
      const PushMessage(title: 'Recibiste un pago', destination: 'accounts'),
    );
    await tester.pump();
    expect(resolver.opened, isEmpty);

    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();
    await tester.pumpWidget(scope(segmentId: 'wealth'));
    await tester.pumpAndSettle();

    expect(resolver.opened, ['accounts']);
  });

  testWidgets('removes the registration when the permission was taken away '
      'while the app was in the background', (tester) async {
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();
    expect(devices.saved, {'device-1': 'token-1'});

    messaging.current = NotificationPermission.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(devices.saved, isEmpty);
    expect(messaging.calls, contains('unsubscribe:segment-family'));
    expect(messaging.calls.last, 'deleteToken');
  });

  testWidgets('checks the permission again when the app comes back to the '
      'front', (tester) async {
    messaging.current = NotificationPermission.denied;
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();
    expect(devices.saved, isEmpty);

    messaging.current = NotificationPermission.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(devices.saved, {'device-1': 'token-1'});
  });
}
