import 'package:app_platform/testing.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakePushMessaging messaging;
  late FakePrimerMemory memory;
  late FakeSystemSettings settings;
  late InMemoryTelemetry telemetry;
  late PermissionCubit cubit;

  PermissionCubit build() => PermissionCubit(
    messaging: messaging,
    memory: memory,
    settings: settings,
    telemetry: telemetry,
  );

  setUp(() {
    messaging = FakePushMessaging();
    memory = FakePrimerMemory();
    settings = FakeSystemSettings();
    telemetry = InMemoryTelemetry();
    cubit = build();
  });

  tearDown(() => cubit.close());

  test('invites a customer the system has not asked and who has not '
      'answered on this device', () async {
    await cubit.check();

    expect(cubit.state.isPrimerDue, isTrue);
    expect(messaging.prompts, 0);
  });

  test('does not invite again by itself after "Ahora no", but the customer '
      'can still ask for it', () async {
    await cubit.check();
    await cubit.decline();

    expect(memory.wasAnswered, isTrue);
    expect(cubit.state.isPrimerDue, isFalse);
    expect(cubit.state.canInvite, isTrue);
    expect(messaging.prompts, 0);

    await cubit.check();

    expect(cubit.state.isPrimerDue, isFalse);
  });

  test('asks the system only after the customer accepts', () async {
    await cubit.check();

    await cubit.accept();

    expect(messaging.prompts, 1);
    expect(memory.wasAnswered, isTrue);
    expect(cubit.state.isGranted, isTrue);
    expect(cubit.state.isAsking, isFalse);
  });

  test('a customer who refuses the system prompt is told to use the '
      'settings, not invited again', () async {
    messaging.afterPrompt = NotificationPermission.denied;
    await cubit.check();

    await cubit.accept();

    expect(cubit.state.isDenied, isTrue);
    expect(cubit.state.isPrimerDue, isFalse);
    expect(cubit.state.canInvite, isFalse);
  });

  test(
    'sees a permission changed in the system settings on the next check',
    () async {
      messaging.current = NotificationPermission.denied;
      await cubit.check();
      expect(cubit.state.isDenied, isTrue);

      messaging.current = NotificationPermission.granted;
      await cubit.check();

      expect(cubit.state.isGranted, isTrue);
    },
  );

  test('opens the system settings', () async {
    await cubit.openSystemSettings();

    expect(settings.opened, 1);
  });

  test(
    'a system that cannot open its settings is reported, not thrown',
    () async {
      settings.failing = true;

      await cubit.openSystemSettings();

      expect(
        telemetry.errors.single.reason,
        NotificationsTelemetry.unexpectedError,
      );
      expect(
        telemetry.errors.single.error.toString(),
        isNot(contains('settings')),
      );
    },
  );

  test('reports each step of the invitation with the result only', () async {
    await cubit.check();
    cubit.primerShown();
    await cubit.accept();

    expect(telemetry.events.map((event) => event.name), [
      NotificationsTelemetry.primerShown,
      NotificationsTelemetry.primerAccepted,
      NotificationsTelemetry.permissionResult,
    ]);
    expect(telemetry.events.map((event) => event.parameters), [
      isEmpty,
      isEmpty,
      {NotificationsTelemetry.resultKey: 'granted'},
    ]);
  });

  test('reports "Ahora no"', () async {
    await cubit.decline();

    expect(telemetry.events.single.name, NotificationsTelemetry.primerDeclined);
    expect(telemetry.events.single.parameters, isEmpty);
  });
}
