import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _restoredFor = Duration(seconds: 6);
const Duration _justBefore = Duration(seconds: 5);
const Duration _justAfter = Duration(seconds: 7);

void main() {
  late FakeConnectivityMonitor monitor;
  late StreamController<bool> slowChanges;

  ConnectivityCubit cubit() {
    return ConnectivityCubit(
      monitor: monitor,
      slowChanges: slowChanges.stream,
      restoredFor: _restoredFor,
    )..start();
  }

  /// Runs [body] on a fake clock, flushing microtasks before it returns.
  void onFakeClock(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      body(async);
      async.flushMicrotasks();
    });
  }

  setUp(() {
    monitor = FakeConnectivityMonitor();
    slowChanges = StreamController<bool>.broadcast();
  });

  test('assumes it is online until told otherwise', () {
    onFakeClock((async) {
      final connectivity = cubit();
      async.flushMicrotasks();

      expect(connectivity.state, ConnectivityStatus.online);
      unawaited(connectivity.close());
    });
  });

  test('starts offline when the device has no connection', () {
    onFakeClock((async) {
      monitor.online = false;
      final connectivity = cubit();
      async.flushMicrotasks();

      expect(connectivity.state, ConnectivityStatus.offline);
      unawaited(connectivity.close());
    });
  });

  test('goes offline when the connection drops', () {
    onFakeClock((async) {
      final connectivity = cubit();
      async.flushMicrotasks();

      monitor.emit(online: false);
      async.flushMicrotasks();

      expect(connectivity.state, ConnectivityStatus.offline);
      unawaited(connectivity.close());
    });
  });

  group('when the connection comes back', () {
    test('reports it as restored for a while, then as online', () {
      onFakeClock((async) {
        final connectivity = cubit();
        async.flushMicrotasks();
        monitor.emit(online: false);
        async.flushMicrotasks();

        monitor.emit(online: true);
        async.flushMicrotasks();
        expect(connectivity.state, ConnectivityStatus.restored);

        async.elapse(_justBefore);
        expect(connectivity.state, ConnectivityStatus.restored);

        async.elapse(_justAfter - _justBefore);
        expect(connectivity.state, ConnectivityStatus.online);
        unawaited(connectivity.close());
      });
    });

    test('stays offline if it drops again before the notice ends', () {
      onFakeClock((async) {
        final connectivity = cubit();
        async.flushMicrotasks();
        monitor
          ..emit(online: false)
          ..emit(online: true)
          ..emit(online: false);
        async
          ..flushMicrotasks()
          ..elapse(_justAfter);

        expect(connectivity.state, ConnectivityStatus.offline);
        unawaited(connectivity.close());
      });
    });

    test('does not announce a restore when it was never offline', () {
      onFakeClock((async) {
        final connectivity = cubit();
        async.flushMicrotasks();
        final states = <ConnectivityStatus>[];
        final subscription = connectivity.stream.listen(states.add);

        monitor.emit(online: true);
        async.flushMicrotasks();

        expect(states, isEmpty);
        unawaited(subscription.cancel());
        unawaited(connectivity.close());
      });
    });
  });

  group('slow responses', () {
    test('are reported while online and cleared when they recover', () {
      onFakeClock((async) {
        final connectivity = cubit();
        async.flushMicrotasks();

        slowChanges.add(true);
        async.flushMicrotasks();
        expect(connectivity.state, ConnectivityStatus.slow);

        slowChanges.add(false);
        async.flushMicrotasks();
        expect(connectivity.state, ConnectivityStatus.online);
        unawaited(connectivity.close());
      });
    });

    test('never hide that the device is offline', () {
      onFakeClock((async) {
        final connectivity = cubit();
        async.flushMicrotasks();
        monitor.emit(online: false);
        async.flushMicrotasks();

        slowChanges.add(true);
        async.flushMicrotasks();

        expect(connectivity.state, ConnectivityStatus.offline);
        unawaited(connectivity.close());
      });
    });

    test('take over from the restored notice when still slow', () {
      onFakeClock((async) {
        final connectivity = cubit();
        async.flushMicrotasks();
        monitor.emit(online: false);
        slowChanges.add(true);
        async.flushMicrotasks();

        monitor.emit(online: true);
        async
          ..flushMicrotasks()
          ..elapse(_justAfter);

        expect(connectivity.state, ConnectivityStatus.slow);
        unawaited(connectivity.close());
      });
    });
  });

  test('stops listening and cancels its timer when closed', () {
    onFakeClock((async) {
      final connectivity = cubit();
      async.flushMicrotasks();
      monitor
        ..emit(online: false)
        ..emit(online: true);
      async.flushMicrotasks();

      unawaited(connectivity.close());
      async.flushMicrotasks();

      expect(monitor.hasListener, isFalse);
      expect(slowChanges.hasListener, isFalse);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
