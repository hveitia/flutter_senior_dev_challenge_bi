import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;
  late FakePushMessaging messaging;
  late FakeDeviceStore devices;
  late FakeRegistrationMemory memory;

  DeviceRegistrations registrations() => DeviceRegistrations(
    messaging: messaging,
    devicesFor: (_) => devices,
    identity: const FakeDeviceIdentity(),
    memory: memory,
  );

  setUp(() {
    calls = [];
    messaging = FakePushMessaging(
      current: NotificationPermission.granted,
      calls: calls,
    );
    devices = FakeDeviceStore(calls: calls);
    memory = FakeRegistrationMemory();
  });

  group('DeviceRegistrations', () {
    test('hands out one registrar for as long as the session lasts', () {
      final all = registrations();

      expect(all.of('uid-1'), same(all.of('uid-1')));
    });

    test('the same customer signing in again gets a registrar that '
        'registers, not the one their last session forgot', () async {
      final all = registrations();
      final first = all.of('uid-1');
      await first.register('family');
      await first.forget();
      calls.clear();

      final second = all.of('uid-1');
      await second.register('family');

      expect(second, isNot(same(first)));
      expect(devices.saved, {'device-1': 'token-1'});
      expect(calls, contains('subscribe:segment-family'));
    });

    test('a session that ended without its clean-up still loses the topic '
        'and the address, and leaves the device document alone', () async {
      final all = registrations();
      await all.of('uid-1').register('family');
      calls.clear();

      await all.sessionEnded();

      expect(calls, ['unsubscribe:segment-family', 'deleteToken']);
      expect(memory.uid, isNull);
    });

    test('cleans what an earlier run of the app left registered', () async {
      memory = FakeRegistrationMemory(uid: 'uid-1', topics: {'segment-family'});

      await registrations().sessionEnded();

      expect(calls, ['unsubscribe:segment-family', 'deleteToken']);
      expect(memory.uid, isNull);
      expect(memory.topics, isEmpty);
    });

    test(
      'does nothing more after a session that cleaned up by itself',
      () async {
        final all = registrations();
        final registrar = all.of('uid-1');
        await registrar.register('family');
        await registrar.forget();
        calls.clear();

        await all.sessionEnded();

        expect(calls, isEmpty);
      },
    );

    test('does nothing on a device that was never registered', () async {
      await registrations().sessionEnded();

      expect(calls, isEmpty);
    });

    test(
      'a registrar handed out after the session ended is a new one',
      () async {
        final all = registrations();
        final first = all.of('uid-1');
        await all.sessionEnded();

        expect(all.of('uid-1'), isNot(same(first)));
      },
    );
  });

  group('OpenedNotifications', () {
    const payment = PushMessage(
      title: 'Recibiste un pago',
      destination: 'accounts',
    );
    const notice = PushMessage(title: 'Aviso', destination: 'profile');

    test('keeps a tapped notification until someone can open it, and hands '
        'it over once', () async {
      final opened = OpenedNotifications(messaging)..start();

      messaging.openedMessages.add(payment);
      await pumpEventQueue();

      expect(opened.take(), payment);
      expect(opened.take(), isNull);
    });

    test('keeps the notification that started the app', () async {
      messaging.initial = notice;

      final opened = OpenedNotifications(messaging)..start();
      await pumpEventQueue();

      expect(opened.take(), notice);
    });

    test('keeps only the last one tapped', () async {
      final opened = OpenedNotifications(messaging)..start();

      messaging.openedMessages
        ..add(payment)
        ..add(notice);
      await pumpEventQueue();

      expect(opened.take(), notice);
      expect(opened.take(), isNull);
    });

    test('says when one arrives, for whoever is ready to open it', () async {
      final opened = OpenedNotifications(messaging)..start();
      var arrivals = 0;
      final subscription = opened.arrivals.listen((_) => arrivals++);

      messaging.openedMessages.add(payment);
      await pumpEventQueue();

      expect(arrivals, 1);
      await subscription.cancel();
    });

    test('starting twice listens once', () async {
      final opened = OpenedNotifications(messaging)
        ..start()
        ..start();
      var arrivals = 0;
      final subscription = opened.arrivals.listen((_) => arrivals++);

      messaging.openedMessages.add(payment);
      await pumpEventQueue();

      expect(arrivals, 1);
      await subscription.cancel();
    });
  });
}
