import 'dart:async';

import 'package:app_platform/testing.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;
  late FakePushMessaging messaging;
  late FakeDeviceStore devices;
  late FakeRegistrationMemory memory;
  late InMemoryTelemetry telemetry;
  late DeviceRegistrar registrar;

  DeviceRegistrar build({String uid = 'uid-1', Duration? forgetTimeout}) {
    return DeviceRegistrar(
      uid: uid,
      messaging: messaging,
      devices: devices,
      identity: const FakeDeviceIdentity(),
      memory: memory,
      telemetry: telemetry,
      forgetTimeout: forgetTimeout ?? DeviceRegistrar.defaultForgetTimeout,
    );
  }

  List<String> failedSteps() => [
    for (final event in telemetry.events)
      if (event.name == NotificationsTelemetry.deviceFailed)
        event.parameters[NotificationsTelemetry.stepKey]! as String,
  ];

  setUp(() {
    calls = [];
    messaging = FakePushMessaging(
      current: NotificationPermission.granted,
      calls: calls,
    );
    devices = FakeDeviceStore(calls: calls);
    memory = FakeRegistrationMemory();
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

    test('remembers on the device who it is registered for and which topic '
        'it follows', () async {
      await registrar.register('family');

      expect(memory.uid, 'uid-1');
      expect(memory.topics, {'segment-family'});
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
        expect(failedSteps(), [DeviceRegistrar.registerStep]);
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

  group('a step that throws', () {
    test('does not escape, and what is asked next still runs', () async {
      messaging.failing.add('permission');

      await registrar.register('family');

      messaging.failing.clear();
      await registrar.register('family');

      expect(devices.saved, {'device-1': 'token-1'});
      expect(failedSteps(), [DeviceRegistrar.registerStep]);
    });

    test('does not keep the device from being forgotten afterwards', () async {
      await registrar.register('family');
      messaging.failing.add('permission');
      await registrar.register('wealth');
      calls.clear();

      await registrar.forget();

      expect(calls, [
        'unsubscribe:segment-family',
        'remove:device-1',
        'deleteToken',
      ]);
    });
  });

  group('a customer who changes segment', () {
    test('stops hearing the previous one, without registering again', () async {
      await registrar.register('family');
      calls.clear();

      await registrar.register('wealth');

      expect(calls, ['unsubscribe:segment-family', 'subscribe:segment-wealth']);
      expect(memory.topics, {'segment-wealth'});
    });

    test('whose previous topic cannot be left gets a new address instead, '
        'so the device never follows two segments', () async {
      await registrar.register('family');
      calls.clear();
      messaging.failing.add('unsubscribe:segment-family');

      await registrar.register('wealth');

      expect(calls, [
        'unsubscribe:segment-family',
        'deleteToken',
        'token',
        'save:device-1:token-1:android',
        'subscribe:segment-wealth',
      ]);
      expect(memory.topics, {'segment-wealth'});
    });

    test('stays on the previous topic alone when the address cannot be '
        'replaced either, and tries again the next time', () async {
      await registrar.register('family');
      calls.clear();
      messaging.failing.addAll(['unsubscribe:segment-family', 'deleteToken']);

      await registrar.register('wealth');

      expect(calls, isNot(contains('subscribe:segment-wealth')));
      expect(memory.topics, {'segment-family'});

      messaging.failing.clear();
      await registrar.register('wealth');

      expect(memory.topics, {'segment-wealth'});
    });
  });

  group('a phone that changes hands', () {
    setUp(() {
      memory = FakeRegistrationMemory(
        uid: 'uid-previous',
        topics: {'segment-wealth'},
      );
      registrar = build();
    });

    test("drops the previous customer's topic and address before it is "
        'registered for the next one', () async {
      await registrar.register('family');

      expect(calls, [
        'unsubscribe:segment-wealth',
        'deleteToken',
        'token',
        'save:device-1:token-1:android',
        'subscribe:segment-family',
      ]);
      expect(memory.uid, 'uid-1');
      expect(memory.topics, {'segment-family'});
    });

    test('drops them even when this customer has not allowed notifications, '
        'and registers nothing', () async {
      messaging.current = NotificationPermission.notAsked;

      await registrar.register('family');

      expect(calls, ['unsubscribe:segment-wealth', 'deleteToken']);
      expect(memory.uid, isNull);
      expect(memory.topics, isEmpty);
      expect(devices.saved, isEmpty);
    });

    test('is not registered for the next customer while the previous '
        'address cannot be dropped', () async {
      messaging.failing.add('deleteToken');

      await registrar.register('family');

      expect(devices.saved, isEmpty);
      expect(calls, isNot(contains('subscribe:segment-family')));
      expect(memory.uid, 'uid-previous');
    });
  });

  group('permission taken away in the system settings', () {
    test('removes the registration and the topic', () async {
      await registrar.register('family');
      calls.clear();
      messaging.current = NotificationPermission.denied;

      await registrar.register('family');

      expect(calls, [
        'unsubscribe:segment-family',
        'remove:device-1',
        'deleteToken',
      ]);
      expect(devices.saved, isEmpty);
      expect(memory.uid, isNull);
    });

    test('and given back registers the device again', () async {
      await registrar.register('family');
      messaging.current = NotificationPermission.denied;
      await registrar.register('family');
      messaging.current = NotificationPermission.granted;

      await registrar.register('family');

      expect(devices.saved, {'device-1': 'token-1'});
      expect(memory.topics, {'segment-family'});
    });
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
      expect(memory.uid, isNull);
      expect(memory.topics, isEmpty);
    });

    test('touches nothing when the device was never registered', () async {
      await registrar.forget();

      expect(calls, isEmpty);
    });

    test('does nothing the second time', () async {
      await registrar.register('family');
      await registrar.forget();
      calls.clear();

      await registrar.forget();
      await registrar.forgetLocally();

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
        expect(failedSteps(), [DeviceRegistrar.unsubscribeStep]);
      },
    );

    test('takes effect at once: a registration stuck in flight writes no '
        'device when it finally goes on', () async {
      registrar = build(forgetTimeout: const Duration(milliseconds: 20));
      final stuck = Completer<void>();
      messaging.held['token'] = stuck;

      final registering = registrar.register('family');
      // The registration is now waiting for its address.
      await pumpEventQueue();
      await registrar.forget();

      // The wait ended because of its bound: the stuck step has not moved
      // and nothing was cleaned up behind it.
      expect(stuck.isCompleted, isFalse);
      expect(calls, ['token']);

      stuck.complete();
      await registering;
      await pumpEventQueue();

      expect(calls.where((call) => call.startsWith('save:')), isEmpty);
      expect(calls.where((call) => call.startsWith('subscribe:')), isEmpty);
      expect(devices.saved, isEmpty);
      expect(memory.uid, isNull);
    });

    test('registers nothing afterwards, not even a rotated address', () async {
      await registrar.register('family');
      await registrar.forget();
      calls.clear();

      await registrar.register('family');
      messaging.tokens.add('token-2');
      await pumpEventQueue();

      expect(calls, isEmpty);
      expect(devices.saved, isEmpty);
      expect(registrar.isForgotten, isTrue);
    });
  });

  group('forgetLocally, for a session that already ended', () {
    test('drops the topic and the address without touching the device '
        'document, which can no longer be removed', () async {
      await registrar.register('family');
      calls.clear();

      await registrar.forgetLocally();

      expect(calls, ['unsubscribe:segment-family', 'deleteToken']);
      expect(memory.uid, isNull);
      expect(memory.topics, isEmpty);
    });

    test('works from what the device remembers, in a process that never '
        'registered anything', () async {
      memory = FakeRegistrationMemory(uid: 'uid-1', topics: {'segment-family'});
      registrar = build();

      await registrar.forgetLocally();

      expect(calls, ['unsubscribe:segment-family', 'deleteToken']);
      expect(memory.uid, isNull);
    });

    test('keeps what it could not drop on record, to drop it later', () async {
      await registrar.register('family');
      messaging.failing.add('deleteToken');

      await registrar.forgetLocally();

      expect(memory.uid, 'uid-1');
    });
  });
}
