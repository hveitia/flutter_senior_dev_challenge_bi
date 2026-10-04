import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_saved_customer_data.dart';

void main() {
  late InMemoryTelemetry telemetry;
  late InMemoryPendingWipe pending;
  late List<String> ran;

  ClearStep step(String name, {Error? failsWith}) => (
    name: name,
    run: (_) async {
      ran.add(name);
      if (failsWith != null) throw failsWith;
    },
  );

  StepwiseSavedCustomerData savedWith(
    List<ClearStep> steps, {
    Duration stepTimeout = StepwiseSavedCustomerData.defaultStepTimeout,
  }) => StepwiseSavedCustomerData(
    steps: steps,
    telemetry: telemetry,
    pending: pending,
    stepTimeout: stepTimeout,
  );

  setUp(() {
    telemetry = InMemoryTelemetry();
    pending = InMemoryPendingWipe();
    ran = [];
  });

  test('removes each kind of saved data in the order given', () async {
    final saved = savedWith([step('database'), step('sync_times')]);

    await saved.clear();

    expect(ran, ['database', 'sync_times']);
    expect(telemetry.events, isEmpty);
    expect(telemetry.errors, isEmpty);
  });

  test('a step that fails does not stop the ones after it', () async {
    final saved = savedWith([
      step('database', failsWith: StateError('still in use')),
      step('sync_times'),
    ]);

    await expectLater(saved.clear(), completes);

    expect(ran, ['database', 'sync_times']);
  });

  test('reports the step that failed, without the error message', () async {
    final saved = savedWith([
      step('database', failsWith: StateError('uid-1 still in use')),
      step('sync_times'),
    ]);

    await saved.clear();

    expect(telemetry.events, hasLength(1));
    expect(
      telemetry.events.single.name,
      StepwiseSavedCustomerData.clearFailed,
    );
    expect(telemetry.events.single.parameters, {
      StepwiseSavedCustomerData.stepKey: 'database',
      StepwiseSavedCustomerData.causeKey: StepwiseSavedCustomerData.causeError,
    });

    final report = telemetry.errors.single;
    expect(report.error, isA<RedactedError>());
    expect(report.error.toString(), isNot(contains('uid-1')));
    expect(report.reason, StepwiseSavedCustomerData.clearFailed);
  });

  test('a step that never ends is given up on, reported as a timeout, and '
      'the rest and a later request still run', () {
    fakeAsync((async) {
      final saved = savedWith(
        [
          (
            name: 'database',
            run: (_) {
              ran.add('database');
              return Completer<void>().future;
            },
          ),
          step('sync_times'),
        ],
        stepTimeout: const Duration(seconds: 3),
      );

      var first = false;
      var second = false;
      unawaited(saved.clear().then((_) => first = true));
      unawaited(saved.clear().then((_) => second = true));

      async.elapse(const Duration(seconds: 2));
      expect(ran, ['database']);
      expect(first, isFalse);

      async
        ..elapse(const Duration(seconds: 1))
        ..flushMicrotasks();
      expect(first, isTrue);
      expect(ran, ['database', 'sync_times', 'database']);

      async
        ..elapse(const Duration(seconds: 3))
        ..flushMicrotasks();
      expect(second, isTrue);
      expect(ran, ['database', 'sync_times', 'database', 'sync_times']);

      const timedOut = {
        StepwiseSavedCustomerData.stepKey: 'database',
        StepwiseSavedCustomerData.causeKey:
            StepwiseSavedCustomerData.causeTimeout,
      };
      expect(
        telemetry.events.map((event) => event.parameters),
        [timedOut, timedOut],
      );
    });
  });

  test('a second request waits for the first instead of overlapping', () async {
    final order = <String>[];
    var running = 0;
    var overlapped = false;
    final saved = savedWith([
      (
        name: 'database',
        run: (_) async {
          running++;
          overlapped = overlapped || running > 1;
          order.add('start');
          await Future<void>.delayed(Duration.zero);
          order.add('end');
          running--;
        },
      ),
    ]);

    await Future.wait([saved.clear(), saved.clear()]);

    expect(overlapped, isFalse);
    expect(order, ['start', 'end', 'start', 'end']);
  });

  group('what a removal that did not finish leaves behind', () {
    test('a removal that finished leaves nothing pending', () async {
      final saved = savedWith([step('database'), step('sync_times')]);

      await saved.clear();

      expect(pending.writes, [true, false]);
      expect(pending.pending, isFalse);
    });

    test('a failed step leaves the removal pending', () async {
      final saved = savedWith([
        step('database', failsWith: StateError('in use')),
        step('sync_times'),
      ]);

      await saved.clear();

      expect(pending.pending, isTrue);
    });

    test('a timed-out step leaves the removal pending: the data may still '
        'be on the device', () {
      fakeAsync((async) {
        final saved = savedWith(
          [(name: 'database', run: (_) => Completer<void>().future)],
          stepTimeout: const Duration(seconds: 3),
        );

        unawaited(saved.clear());
        async
          ..elapse(const Duration(seconds: 3))
          ..flushMicrotasks();

        expect(pending.pending, isTrue);
      });
    });

    test('finishing does nothing when nothing is pending', () async {
      final saved = savedWith([step('database')]);

      await saved.finishPending();

      expect(ran, isEmpty);
    });

    test('finishing runs the removal again when one is pending', () async {
      pending.pending = true;
      final saved = savedWith([step('database'), step('sync_times')]);

      await saved.finishPending();

      expect(ran, ['database', 'sync_times']);
      expect(pending.pending, isFalse);
    });

    test('finishing waits for a removal in progress and does not repeat one '
        'that succeeded', () async {
      final saved = savedWith([step('database')]);

      await Future.wait([saved.clear(), saved.finishPending()]);

      expect(ran, ['database']);
    });

    test('a pending mark that cannot be read counts as pending', () async {
      final saved = StepwiseSavedCustomerData(
        steps: [step('database')],
        telemetry: telemetry,
        pending: _UnreadablePendingWipe(),
      );

      await saved.finishPending();

      expect(ran, ['database']);
    });
  });

  group('the database step', () {
    late List<String> calls;
    late Completer<void> terminated;

    Future<void> Function(StepRun) databaseStep() => clearDatabaseStep(
      terminate: () {
        calls.add('terminate');
        return terminated.future;
      },
      clearPersistence: () async => calls.add('clearPersistence'),
      afterCleared: () => calls.add('afterCleared'),
    );

    setUp(() {
      calls = [];
      terminated = Completer<void>();
    });

    test('shuts the database down, erases its copy and restores its '
        'settings, in that order', () async {
      final saved = savedWith([(name: 'database', run: databaseStep())]);

      final cleared = saved.clear();
      terminated.complete();
      await cleared;

      expect(calls, ['terminate', 'clearPersistence', 'afterCleared']);
    });

    test('a shutdown that completes after the timeout touches nothing '
        'more', () {
      fakeAsync((async) {
        final saved = savedWith(
          [(name: 'database', run: databaseStep())],
          stepTimeout: const Duration(seconds: 3),
        );

        unawaited(saved.clear());
        async
          ..elapse(const Duration(seconds: 3))
          ..flushMicrotasks();
        expect(calls, ['terminate']);

        // The next customer is signed in by now. The late shutdown must
        // not go on to erase the database they are using.
        terminated.complete();
        async.flushMicrotasks();

        expect(calls, ['terminate']);
        expect(pending.pending, isTrue);
      });
    });
  });
}

final class _UnreadablePendingWipe implements PendingWipe {
  @override
  Future<bool> isPending() => throw StateError('storage unavailable');

  @override
  Future<void> setPending({required bool pending}) async {}
}
