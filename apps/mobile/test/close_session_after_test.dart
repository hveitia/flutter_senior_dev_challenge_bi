import 'dart:async';

import 'package:banca_digital/shell/section_screens.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closes the session once the clean-up is done', () async {
    final steps = <String>[];

    await closeSessionAfter(
      () async => steps.add('clean-up'),
      () => steps.add('close'),
    );

    expect(steps, ['clean-up', 'close']);
  });

  test('closes the session when the clean-up fails later', () async {
    var closed = false;

    await closeSessionAfter(
      () => Future<void>.error(StateError('no network')),
      () => closed = true,
    );

    expect(closed, isTrue);
  });

  test('closes the session when the clean-up never completes', () {
    fakeAsync((async) {
      var closed = false;

      unawaited(
        closeSessionAfter(
          () => Completer<void>().future,
          () => closed = true,
          timeout: const Duration(seconds: 4),
        ),
      );

      async.elapse(const Duration(seconds: 3));
      expect(closed, isFalse);

      async
        ..elapse(const Duration(seconds: 1))
        ..flushMicrotasks();
      expect(closed, isTrue);
    });
  });

  test(
    'closes the session when the clean-up fails before it even starts',
    () async {
      var closed = false;

      await closeSessionAfter(
        () => throw StateError('no registrar'),
        () => closed = true,
      );

      expect(closed, isTrue);
    },
  );
}
