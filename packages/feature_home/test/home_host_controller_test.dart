import 'dart:async';

import 'package:app_platform/testing.dart';
import 'package:fake_async/fake_async.dart';
import 'package:feature_home/src/home_host_controller.dart';
import 'package:feature_home/src/home_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/module_kit.dart';

void main() {
  late InMemoryTelemetry telemetry;
  late HomeHostController host;
  late int notifications;

  List<TelemetryEvent> eventsNamed(String name) =>
      telemetry.events.where((event) => event.name == name).toList();

  setUp(() {
    telemetry = InMemoryTelemetry();
    host = HomeHostController(telemetry: telemetry);
    notifications = 0;
    host.addListener(() => notifications++);
  });

  tearDown(() => host.dispose());

  group('what the home can show', () {
    test('is everything while no module has reported', () {
      host.show(['balance', 'promo']);

      expect(host.nothingToShow, isFalse);
      expect(host.isBlank, isFalse);
      expect(host.hasData, isFalse);
    });

    test('is nothing when every module is a data module that failed', () {
      host
        ..show(['balance', 'movements'])
        ..report('balance', HomeModuleStatus.failed)
        ..report('movements', HomeModuleStatus.failed);

      expect(host.nothingToShow, isTrue);
    });

    test('still includes a module that never reports, which draws published '
        'content and cannot fail', () {
      host
        ..show(['balance', 'promo'])
        ..report('balance', HomeModuleStatus.failed);

      expect(host.nothingToShow, isFalse);
    });

    test('still includes a module that is waiting or ready', () {
      host
        ..show(['balance', 'movements'])
        ..report('balance', HomeModuleStatus.failed)
        ..report('movements', HomeModuleStatus.waiting);
      expect(host.nothingToShow, isFalse);

      host.report('movements', HomeModuleStatus.ready);
      expect(host.nothingToShow, isFalse);
      expect(host.hasData, isTrue);
    });

    test('does not count a hidden module, for or against', () {
      host
        ..show(['balance', 'accounts', 'actions'])
        ..report('balance', HomeModuleStatus.failed)
        ..report('accounts', HomeModuleStatus.hidden)
        ..report('actions', HomeModuleStatus.hidden);

      expect(host.nothingToShow, isTrue);
      expect(host.isHidden('accounts'), isTrue);
      expect(host.isHidden('balance'), isFalse);
    });

    test('is blank, not failed, when every module is hidden', () {
      host
        ..show(['actions', 'promo'])
        ..report('actions', HomeModuleStatus.hidden)
        ..report('promo', HomeModuleStatus.hidden);

      expect(host.nothingToShow, isFalse);
      expect(host.isBlank, isTrue);
    });

    test('ignores what a module that left the composition had reported', () {
      host
        ..show(['balance', 'movements'])
        ..report('balance', HomeModuleStatus.ready)
        ..report('movements', HomeModuleStatus.failed)
        ..show(['movements']);

      expect(host.nothingToShow, isTrue);
      expect(host.hasData, isFalse);
    });

    test('forgets a report that was withdrawn', () {
      host
        ..show(['balance', 'promo'])
        ..report('balance', HomeModuleStatus.failed)
        ..report('promo', HomeModuleStatus.hidden)
        ..withdraw('promo');

      expect(host.isHidden('promo'), isFalse);
      expect(host.nothingToShow, isFalse);
    });
  });

  group('listeners', () {
    test('hear about a new status and not about a repeated one', () {
      host
        ..show(['balance'])
        ..report('balance', HomeModuleStatus.waiting);
      final before = notifications;

      host.report('balance', HomeModuleStatus.waiting);
      expect(notifications, before);

      host.report('balance', HomeModuleStatus.ready);
      expect(notifications, before + 1);
    });
  });

  group('telemetry', () {
    test('reports once when the home is left with nothing to show, and again '
        'only after it recovered', () {
      host
        ..show(['balance'])
        ..report('balance', HomeModuleStatus.failed)
        ..report('balance', HomeModuleStatus.failed);
      expect(eventsNamed(HomeTelemetry.nothingToShow), hasLength(1));

      host
        ..report('balance', HomeModuleStatus.ready)
        ..report('balance', HomeModuleStatus.failed);
      expect(eventsNamed(HomeTelemetry.nothingToShow), hasLength(2));
    });
  });

  group('refreshing', () {
    test('runs every refresher and says so while it lasts', () async {
      final calls = <String>[];
      final gate = Completer<void>();
      host
        ..addRefresher(() async {
          calls.add('balance');
          await gate.future;
        })
        ..addRefresher(() async => calls.add('movements'));

      final refresh = host.refreshAll();
      expect(host.isRefreshing, isTrue);

      gate.complete();
      await refresh;

      expect(calls, unorderedEquals(['balance', 'movements']));
      expect(host.isRefreshing, isFalse);
      expect(eventsNamed(HomeTelemetry.refreshRequested).single.parameters, {
        HomeTelemetry.modulesKey: 2,
      });
    });

    test('does not run a refresher that was removed', () async {
      var calls = 0;
      host.addRefresher(() async => calls++)();

      await host.refreshAll();

      expect(calls, 0);
    });

    test('ignores a second request while one is running', () async {
      var calls = 0;
      final gate = Completer<void>();
      host.addRefresher(() {
        calls++;
        return gate.future;
      });

      final first = host.refreshAll();
      await host.refreshAll();
      gate.complete();
      await first;

      expect(calls, 1);
    });

    test(
      'finishes when a refresher throws before returning a future',
      () async {
        var others = 0;
        host
          ..addRefresher(() => throw StateError('closed'))
          ..addRefresher(() async => others++);

        await host.refreshAll();

        expect(others, 1);
        expect(host.isRefreshing, isFalse);
      },
    );

    test('finishes when a refresher fails later', () async {
      host.addRefresher(() async => throw StateError('failed'));

      await host.refreshAll();

      expect(host.isRefreshing, isFalse);
    });

    test('stops waiting for a refresher that never answers, and the next '
        'refresh runs', () {
      fakeAsync((async) {
        var calls = 0;
        host.addRefresher(() {
          calls++;
          return Completer<void>().future;
        });

        var finished = false;
        unawaited(host.refreshAll().then((_) => finished = true));
        async.elapse(
          HomeHostController.refresherTimeout - const Duration(seconds: 1),
        );
        expect(finished, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(finished, isTrue);
        expect(host.isRefreshing, isFalse);

        unawaited(host.refreshAll());
        async.flushMicrotasks();
        expect(calls, 2);
      });
    });
  });
}
