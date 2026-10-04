import 'package:feature_services/src/data/stepwise_mini_app_data.dart';
import 'package:feature_services/src/testing/services_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> ran;
  late InMemoryPendingCleanUp pending;

  MiniAppDataStep step(String name, {bool fails = false}) => (
    name: name,
    run: () async {
      // What the note says when this step starts.
      ran.add('$name:${await pending.isPending()}');
      if (fails) throw StateError('cannot remove $name');
    },
  );

  StepwiseMiniAppData data(List<MiniAppDataStep> steps) =>
      StepwiseMiniAppData(steps: steps, pending: pending);

  setUp(() {
    ran = [];
    pending = InMemoryPendingCleanUp();
  });

  group('clear', () {
    test('runs every step in order, with the note already written', () async {
      await data([step('cookies'), step('cache'), step('storage')]).clear();

      expect(ran, ['cookies:true', 'cache:true', 'storage:true']);
    });

    test('erases the note once every step succeeded', () async {
      await data([step('cookies'), step('storage')]).clear();

      expect(await pending.isPending(), isFalse);
      expect(pending.writes, [true, false]);
    });

    test('still runs the other steps when one fails', () async {
      final clearing = data([
        step('cookies', fails: true),
        step('cache'),
        step('storage', fails: true),
      ]).clear();

      await expectLater(clearing, throwsA(isA<MiniAppDataNotCleared>()));
      expect(ran.map((entry) => entry.split(':').first), [
        'cookies',
        'cache',
        'storage',
      ]);
    });

    test('fails naming the steps that failed and nothing they held', () async {
      Object? error;
      try {
        await data([
          step('cookies', fails: true),
          step('cache'),
          step('storage', fails: true),
        ]).clear();
      } on MiniAppDataNotCleared catch (caught) {
        error = caught;
      }

      expect((error! as MiniAppDataNotCleared).failedSteps, [
        'cookies',
        'storage',
      ]);
      expect('$error', 'MiniAppDataNotCleared(cookies, storage)');
    });

    test('leaves the note in place when a step failed', () async {
      await expectLater(
        data([step('cookies', fails: true)]).clear(),
        throwsA(isA<MiniAppDataNotCleared>()),
      );

      expect(await pending.isPending(), isTrue);
    });
  });

  group('clearIfPending', () {
    test('does nothing when the last clean-up finished', () async {
      await data([step('cookies')]).clearIfPending();

      expect(ran, isEmpty);
      expect(pending.writes, isEmpty);
    });

    test('cleans again when the last clean-up did not finish', () async {
      pending = InMemoryPendingCleanUp(pending: true);

      await data([step('cookies'), step('storage')]).clearIfPending();

      expect(ran, hasLength(2));
      expect(await pending.isPending(), isFalse);
    });

    test('fails, and keeps the note, when it still cannot clean', () async {
      pending = InMemoryPendingCleanUp(pending: true);

      await expectLater(
        data([step('cookies', fails: true)]).clearIfPending(),
        throwsA(isA<MiniAppDataNotCleared>()),
      );
      expect(await pending.isPending(), isTrue);
    });
  });
}
