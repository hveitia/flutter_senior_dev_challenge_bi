import 'dart:async';

import 'package:app_platform/testing.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;
  late FakePushMessaging messaging;
  late FakeDeviceStore devices;
  late InMemoryTelemetry telemetry;
  late DeviceRegistrar registrar;

  DeviceRegistrar build({Duration? forgetTimeout}) => DeviceRegistrar(
    messaging: messaging,
    devices: devices,
    identity: const FakeDeviceIdentity(),
    telemetry: telemetry,
    forgetTimeout: forgetTimeout ?? DeviceRegistrar.defaultForgetTimeout,
  );

  setUp(() {
    calls = [];
    messaging = FakePushMessaging(
      current: NotificationPermission.granted,
      calls: calls,
    );
    devices = FakeDeviceStore(calls: calls);
    telemetry = InMemoryTelemetry();
    registrar = build();
  });

  group('register', () {
    test('saves the device and follows the segment topic', () async {
      await registrar.register('family');

      expect(calls, [
        'token',
        'save:device-1:token-1:android',
        'subscribe:segment-family',
      ]);
      expect(telemetry.events.map((event) => event.name), [
        NotificationsTelemetry.deviceRegistered,
      ]);
    });

    test(
      'does nothing while the system does not allow notifications',
      () async {
        messaging.current = NotificationPermission.denied;

        await registrar.register('family');

        expect(calls, isEmpty);
        expect(devices.saved, isEmpty);
      },
    );

    test('registers once however many times it is asked', () async {
      await registrar.register('family');
      await registrar.register('family');

      expect(calls.where((call) => call.startsWith('save:')), hasLength(1));
      expect(
        calls.where((call) => call.startsWith('subscribe:')),
        hasLength(1),
      );
    });

    test('a customer who changes segment stops hearing the previous one, '
        'without registering again', () async {
      await registrar.register('family');
      calls.clear();

      await registrar.register('wealth');

      expect(calls, ['unsubscribe:segment-family', 'subscribe:segment-wealth']);
    });

    test('a new address from the service replaces the saved one', () async {
      await registrar.register('family');

      messaging.tokens.add('token-2');
      await pumpEventQueue();

      expect(devices.saved, {'device-1': 'token-2'});
    });

    test(
      'a failed save is reported by step only and can be tried again',
      () async {
        devices.failing = true;

        await registrar.register('family');

        expect(devices.saved, isEmpty);
        expect(calls, isNot(contains('subscribe:segment-family')));
        final failure = telemetry.events.single;
        expect(failure.name, NotificationsTelemetry.deviceFailed);
        expect(failure.parameters, {
          NotificationsTelemetry.stepKey: DeviceRegistrar.registerStep,
        });
        expect(
          telemetry.errors.single.error.toString(),
          isNot(contains('save')),
        );

        devices.failing = false;
        await registrar.register('family');

        expect(devices.saved, {'device-1': 'token-1'});
      },
    );
  });

  group('forget', () {
    test('stops the topic, removes the device and deletes the address, '
        'in that order', () async {
      await registrar.register('family');
      calls.clear();

      await registrar.forget();

      expect(calls, [
        'unsubscribe:segment-family',
        'remove:device-1',
        'deleteToken',
      ]);
      expect(devices.saved, isEmpty);
    });

    test('touches nothing when the device was never registered', () async {
      await registrar.forget();

      expect(calls, isEmpty);
    });

    test(
      'a step that fails does not stop the others and is reported',
      () async {
        await registrar.register('family');
        calls.clear();
        telemetry.events.clear();
        messaging.failing.add('unsubscribe:segment-family');

        await registrar.forget();

        expect(calls, [
          'unsubscribe:segment-family',
          'remove:device-1',
          'deleteToken',
        ]);
        expect(telemetry.events.single.parameters, {
          NotificationsTelemetry.stepKey: DeviceRegistrar.unsubscribeStep,
        });
      },
    );

    test('waits for a registration in flight and then undoes it', () async {
      final gate = Completer<void>();
      messaging.held['token'] = gate;

      final registering = registrar.register('family');
      final forgetting = registrar.forget();
      gate.complete();
      await Future.wait([registering, forgetting]);

      expect(devices.saved, isEmpty);
      expect(calls.last, 'deleteToken');
    });

    test(
      'gives up waiting after the timeout, so signing out never hangs',
      () async {
        registrar = build(forgetTimeout: const Duration(milliseconds: 20));
        await registrar.register('family');
        messaging.held['unsubscribe:segment-family'] = Completer<void>();

        await expectLater(registrar.forget(), completes);
      },
    );

    test('registers nothing afterwards, not even a rotated address', () async {
      await registrar.register('family');
      await registrar.forget();
      calls.clear();

      await registrar.register('family');
      messaging.tokens.add('token-2');
      await pumpEventQueue();

      expect(calls, isEmpty);
      expect(devices.saved, isEmpty);
    });
  });
}
