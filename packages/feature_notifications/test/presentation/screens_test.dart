import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/src/presentation/inbox_screen.dart';
import 'package:feature_notifications/src/presentation/permission_primer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/testing.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

void main() {
  late NotificationsHarness harness;
  late FakeDestinationResolver resolver;
  late int invitations;

  Widget inbox() {
    return InboxScreen(
      destinations: resolver,
      onInvite: () => invitations++,
      now: () => now,
    );
  }

  Future<void> show(
    WidgetTester tester,
    List<InboxItem> items, {
    double textScale = 1,
    Size? size,
  }) async {
    harness.repository.onRefresh = () async => Success(fresh(items));
    harness.inbox.start();
    await harness.permission.check();
    await harness.pump(tester, inbox(), textScale: textScale, size: size);
    await tester.pump();
  }

  setUp(() {
    harness = NotificationsHarness();
    resolver = FakeDestinationResolver(available: {'accounts', 'profile'});
    invitations = 0;
  });

  group('inbox', () {
    testWidgets('draws placeholders while the first answer is on its way', (
      tester,
    ) async {
      harness.repository.onRefresh = () =>
          Completer<Result<InboxSnapshot>>().future;
      harness.inbox.start();

      await harness.pump(tester, inbox());

      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(find.text('Aún no tienes notificaciones'), findsNothing);
    });

    testWidgets('splits the notifications into today and before', (
      tester,
    ) async {
      await show(tester, [salary, signIn, travel, transfer]);

      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('ANTERIORES'), findsOneWidget);
      expect(find.text(r'Recibiste $1,850.00'), findsOneWidget);
      expect(find.text('09:12'), findsOneWidget);
      expect(find.text('Ayer · 15:20'), findsOneWidget);
      expect(find.text('28 sep · 16:04'), findsOneWidget);
    });

    testWidgets('marks what is unread with the word, not only the dot', (
      tester,
    ) async {
      await show(tester, [salary, travel]);

      expect(find.text('Nueva'), findsOneWidget);
    });

    testWidgets('says where a notification leads only when this build can '
        'open it', (tester) async {
      await show(tester, [salary, travel]);

      expect(find.text('Tus cuentas'), findsOneWidget);
      expect(find.text('Servicios de aliados'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping a notification marks it as read, opens its '
        'destination and reports the kind only', (tester) async {
      await show(tester, [salary, signIn]);

      await tester.tap(find.text(r'Recibiste $1,850.00'));
      await tester.pump();

      expect(harness.repository.markedRead, [salary.id]);
      expect(resolver.opened, ['accounts']);
      expect(find.text('Nueva'), findsOneWidget);
      final event = harness.telemetry.events.single;
      expect(event.name, NotificationsTelemetry.opened);
      expect(event.parameters, {
        NotificationsTelemetry.kindKey: 'movement',
        NotificationsTelemetry.sourceKey: NotificationsTelemetry.fromInbox,
      });
    });

    testWidgets('a notification that leads nowhere is still marked as read', (
      tester,
    ) async {
      await show(tester, [
        InboxItem(
          id: 'n-benefit',
          title: 'Un beneficio nuevo',
          body: 'Conócelo.',
          kind: NotificationKind.benefit,
          destination: 'partner:travelInsurance',
          createdAt: now,
          isRead: false,
        ),
      ]);

      await tester.tap(find.text('Un beneficio nuevo'));
      await tester.pump();

      expect(harness.repository.markedRead, ['n-benefit']);
      expect(resolver.opened, isEmpty);
    });

    testWidgets('an empty inbox says so', (tester) async {
      await show(tester, []);

      expect(find.text('Aún no tienes notificaciones'), findsOneWidget);
    });

    testWidgets('a failure with nothing saved offers to try again', (
      tester,
    ) async {
      harness.repository.onRefresh = () async => const Failed(TimeoutFailure());
      harness.inbox.start();
      await harness.pump(tester, inbox());
      await tester.pump();

      expect(find.text('No pudimos cargar tus notificaciones'), findsOneWidget);

      harness.repository.onRefresh = () async => Success(fresh([salary]));
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();

      expect(find.text(r'Recibiste $1,850.00'), findsOneWidget);
    });

    testWidgets('keeps the saved notifications on screen when the refresh '
        'fails, with a notice', (tester) async {
      harness.repository.onRefresh = () async => const Failed(TimeoutFailure());
      harness.inbox.start();
      await harness.pump(tester, inbox());
      harness.repository.inbox.add(saved([salary]));
      await tester.pump();
      await tester.pump();

      expect(find.text(r'Recibiste $1,850.00'), findsOneWidget);
      expect(find.textContaining('Mostramos las guardadas'), findsOneWidget);
    });

    testWidgets('without a connection it shows the saved notifications '
        'under the offline banner', (tester) async {
      harness.monitor.online = false;
      harness.connectivity.start();
      harness.repository.onRefresh = () async => const Failed(OfflineFailure());
      harness.inbox.start();
      await harness.pump(tester, inbox());
      harness.repository.inbox.add(saved([salary]));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Sin conexión'), findsOneWidget);
      expect(find.text(r'Recibiste $1,850.00'), findsOneWidget);
      expect(find.textContaining('Mostramos las guardadas'), findsNothing);
    });

    testWidgets('with notifications switched off in the system, sends the '
        'customer to its settings', (tester) async {
      harness = NotificationsHarness(permission: NotificationPermission.denied);
      await show(tester, [salary]);

      expect(
        find.text('Tienes las notificaciones desactivadas'),
        findsOneWidget,
      );

      await tester.tap(find.text('Activar en Ajustes'));
      await tester.pump();

      expect(harness.settings.opened, 1);
      expect(invitations, 0);
    });

    testWidgets('after "Ahora no", offers the invitation again without '
        'insisting', (tester) async {
      harness = NotificationsHarness(
        permission: NotificationPermission.notAsked,
        primerAnswered: true,
      );
      await show(tester, [salary]);

      await tester.tap(find.text('Activar notificaciones'));

      expect(invitations, 1);
      expect(harness.messaging.prompts, 0);
    });

    testWidgets('shows no notice while notifications are on', (tester) async {
      await show(tester, [salary]);

      expect(find.text('Tienes las notificaciones desactivadas'), findsNothing);
      expect(find.text('Activar notificaciones'), findsNothing);
    });

    testWidgets('meets the tap target, label and contrast guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      harness = NotificationsHarness(permission: NotificationPermission.denied);
      await show(tester, [salary, travel]);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('does not overflow on a narrow screen with large text', (
      tester,
    ) async {
      harness = NotificationsHarness(permission: NotificationPermission.denied);
      await show(
        tester,
        [salary, signIn, travel],
        textScale: 1.3,
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a screen reader hears a notification as one button that '
        'starts with "Nueva"', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, [salary]);

      expect(
        find.bySemanticsLabel(RegExp(r'^Nueva\. Recibiste \$1,850\.00\.')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('permission primer', () {
    late int closed;

    Future<void> pumpPrimer(WidgetTester tester, {double textScale = 1}) async {
      harness = NotificationsHarness(
        permission: NotificationPermission.notAsked,
      );
      await harness.permission.check();
      await harness.pump(
        tester,
        PermissionPrimerScreen(onDone: () => closed++),
        textScale: textScale,
        size: textScale > 1 ? const Size(320, 640) : null,
      );
    }

    setUp(() => closed = 0);

    testWidgets('explains what the notifications are for before the system '
        'asks anything', (tester) async {
      await pumpPrimer(tester);

      expect(find.text('Entérate al instante'), findsOneWidget);
      expect(find.text('Movimientos de tu cuenta'), findsOneWidget);
      expect(find.text('Alertas de seguridad'), findsOneWidget);
      expect(find.text('Beneficios para ti'), findsOneWidget);
      expect(harness.messaging.prompts, 0);
      expect(
        harness.telemetry.events.single.name,
        NotificationsTelemetry.primerShown,
      );
    });

    testWidgets('accepting asks the system and closes', (tester) async {
      await pumpPrimer(tester);

      await tester.tap(find.text('Activar notificaciones'));
      await tester.pump();

      expect(harness.messaging.prompts, 1);
      expect(closed, 1);
    });

    testWidgets('"Ahora no" closes without asking the system and is '
        'remembered', (tester) async {
      await pumpPrimer(tester);

      await tester.tap(find.text('Ahora no'));
      await tester.pump();

      expect(harness.messaging.prompts, 0);
      expect(harness.memory.wasAnswered, isTrue);
      expect(closed, 1);
    });

    testWidgets('meets the accessibility guidelines and fits large text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPrimer(tester, textScale: 1.3);

      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('bell', () {
    late int taps;

    Future<void> pumpBell(WidgetTester tester, List<InboxItem> items) async {
      harness.repository.onRefresh = () async => Success(fresh(items));
      harness.inbox.start();
      await harness.pump(
        tester,
        Scaffold(body: NotificationsBell(onOpen: () => taps++)),
      );
      await tester.pump();
    }

    setUp(() => taps = 0);

    testWidgets('tells a screen reader how many are unread', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBell(tester, [salary, signIn, travel]);

      expect(
        find.bySemanticsLabel('Notificaciones, 2 sin leer'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('is a plain bell when everything is read', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBell(tester, [travel]);

      expect(find.bySemanticsLabel('Notificaciones'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('opens the inbox and is large enough to tap', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBell(tester, [salary]);

      await tester.tap(find.byType(NotificationsBell));

      expect(taps, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
