import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryTelemetry telemetry;
  late List<String> ran;

  ClearStep step(String name, {Error? failsWith}) => (
    name: name,
    run: () async {
      ran.add(name);
      if (failsWith != null) throw failsWith;
    },
  );

  setUp(() {
    telemetry = InMemoryTelemetry();
    ran = [];
  });

  test('removes each kind of saved data in the order given', () async {
    final saved = StepwiseSavedCustomerData(
      steps: [step('database'), step('sync_times')],
      telemetry: telemetry,
    );

    await saved.clear();

    expect(ran, ['database', 'sync_times']);
    expect(telemetry.events, isEmpty);
    expect(telemetry.errors, isEmpty);
  });

  test('a step that fails does not stop the ones after it', () async {
    final saved = StepwiseSavedCustomerData(
      steps: [
        step('database', failsWith: StateError('still in use')),
        step('sync_times'),
      ],
      telemetry: telemetry,
    );

    await expectLater(saved.clear(), completes);

    expect(ran, ['database', 'sync_times']);
  });

  test('reports the step that failed, without the error message', () async {
    final saved = StepwiseSavedCustomerData(
      steps: [
        step('database', failsWith: StateError('uid-1 still in use')),
        step('sync_times'),
      ],
      telemetry: telemetry,
    );

    await saved.clear();

    expect(telemetry.events, hasLength(1));
    expect(
      telemetry.events.single.name,
      StepwiseSavedCustomerData.clearFailed,
    );
    expect(telemetry.events.single.parameters, {
      StepwiseSavedCustomerData.stepKey: 'database',
    });

    final report = telemetry.errors.single;
    expect(report.error, isA<RedactedError>());
    expect(report.error.toString(), isNot(contains('uid-1')));
    expect(report.reason, StepwiseSavedCustomerData.clearFailed);
  });

  test('a step that never ends is given up on, reported, and the rest and '
      'a later request still run', () {
    fakeAsync((async) {
      final saved = StepwiseSavedCustomerData(
        steps: [
          (
            name: 'database',
            run: () {
              ran.add('database');
              return Completer<void>().future;
            },
          ),
          step('sync_times'),
        ],
        telemetry: telemetry,
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

      expect(telemetry.events.map((event) => event.parameters), [
        {StepwiseSavedCustomerData.stepKey: 'database'},
        {StepwiseSavedCustomerData.stepKey: 'database'},
      ]);
    });
  });

  test('a second request waits for the first instead of overlapping', () async {
    final order = <String>[];
    var running = 0;
    var overlapped = false;
    final saved = StepwiseSavedCustomerData(
      steps: [
        (
          name: 'database',
          run: () async {
            running++;
            overlapped = overlapped || running > 1;
            order.add('start');
            await Future<void>.delayed(Duration.zero);
            order.add('end');
            running--;
          },
        ),
      ],
      telemetry: telemetry,
    );

    await Future.wait([saved.clear(), saved.clear()]);

    expect(overlapped, isFalse);
    expect(order, ['start', 'end', 'start', 'end']);
  });
}
