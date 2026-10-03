import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _timeout = Duration(seconds: 10);
const Duration _slowThreshold = Duration(seconds: 2);
const Duration _baseBackoff = Duration(milliseconds: 200);
const Duration _longEnough = Duration(minutes: 5);

/// Random source pinned to the top of its range: backoff takes its maximum.
double _maxJitter() => 1;

/// Random source pinned to the bottom of its range: backoff takes its minimum.
double _minJitter() => 0;

void main() {
  late List<Duration> requestedDelays;

  Future<void> recordingDelay(Duration duration) {
    requestedDelays.add(duration);
    return Future<void>.delayed(duration);
  }

  ResiliencePolicy policy({
    ResilienceSettings Function()? faults,
    bool Function()? isOffline,
    double Function() random = _maxJitter,
  }) {
    return ResiliencePolicy(
      faults: faults,
      isOffline: isOffline,
      delay: recordingDelay,
      random: random,
      timeout: _timeout,
      slowThreshold: _slowThreshold,
      baseBackoff: _baseBackoff,
    );
  }

  /// Runs [body] to completion on a fake clock and returns its result.
  T settle<T>(Future<T> Function() body) {
    late T value;
    fakeAsync((async) {
      unawaited(body().then((result) => value = result));
      async.elapse(_longEnough);
    });
    return value;
  }

  List<Duration> backoffDelays() => requestedDelays
      .where((delay) => delay != _timeout && delay != _slowThreshold)
      .toList();

  Future<int> never() => Completer<int>().future;

  setUp(() => requestedDelays = []);

  group('a healthy operation', () {
    test('returns its value after a single attempt', () {
      var calls = 0;

      final result = settle(
        () => policy().run(() async {
          calls++;
          return 42;
        }),
      );

      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 42);
      expect(calls, 1);
    });
  });

  group('an operation that times out', () {
    test('is attempted three times and then fails as a timeout', () {
      var calls = 0;

      final result = settle(
        () => policy().run(() {
          calls++;
          return never();
        }),
      );

      expect(calls, ResiliencePolicy.maxAttempts);
      expect(ResiliencePolicy.maxAttempts, 3);
      expect((result as Failed<int>).failure, isA<TimeoutFailure>());
    });

    test('succeeds when a later attempt answers', () {
      var calls = 0;

      final result = settle(
        () => policy().run(() {
          calls++;
          return calls < 2 ? never() : Future.value(7);
        }),
      );

      expect((result as Success<int>).value, 7);
      expect(calls, 2);
    });

    test('announces every retry with the number of the attempt', () {
      final attempts = <int>[];

      settle(() => policy().run(never, onRetry: attempts.add));

      expect(attempts, [2, 3]);
    });
  });

  group('backoff between attempts', () {
    test('doubles on every retry', () {
      settle(() => policy().run(never));

      expect(backoffDelays(), [_baseBackoff, _baseBackoff * 2]);
    });

    test('is never shorter than half of its nominal value', () {
      settle(() => policy(random: _minJitter).run(never));

      expect(backoffDelays(), [_baseBackoff ~/ 2, _baseBackoff]);
    });

    test('is not applied after the last attempt', () {
      settle(() => policy().run(never));

      expect(backoffDelays(), hasLength(ResiliencePolicy.maxAttempts - 1));
    });
  });

  group('failures', () {
    test('an unexpected error is not retried and keeps its cause', () {
      var calls = 0;
      final cause = StateError('bug');

      final result = settle(
        () => policy().run<int>(() {
          calls++;
          throw cause;
        }),
      );

      final failure = (result as Failed<int>).failure;
      expect(calls, 1);
      expect(failure, isA<UnexpectedFailure>());
      expect((failure as UnexpectedFailure).cause, same(cause));
    });

    test('a typed failure thrown by the operation is kept as it is', () {
      final result = settle(
        () => policy().run<int>(
          () => throw const ServiceUnavailableFailure(ServiceIds.movements),
        ),
      );

      final failure = (result as Failed<int>).failure;
      expect(failure, isA<ServiceUnavailableFailure>());
      expect(
        (failure as ServiceUnavailableFailure).serviceId,
        ServiceIds.movements,
      );
    });

    test('an unavailable service is retried like a timeout', () {
      var calls = 0;

      settle(
        () => policy().run<int>(() {
          calls++;
          throw const ServiceUnavailableFailure(ServiceIds.movements);
        }),
      );

      expect(calls, ResiliencePolicy.maxAttempts);
    });

    test('being offline fails at once without calling the operation', () {
      var calls = 0;

      final result = settle(
        () => policy(isOffline: () => true).run(() async {
          calls++;
          return 1;
        }),
      );

      expect((result as Failed<int>).failure, isA<OfflineFailure>());
      expect(calls, 0);
      expect(requestedDelays, isEmpty);
    });

    test('going offline between attempts stops the retries', () {
      var calls = 0;

      final result = settle(
        () => policy(isOffline: () => calls > 0).run(() {
          calls++;
          return never();
        }),
      );

      expect((result as Failed<int>).failure, isA<OfflineFailure>());
      expect(calls, 1);
    });
  });

  group('slow signal', () {
    Future<int> answerAfter(Duration duration) =>
        Future.delayed(duration, () => 1);

    test('fires once when an attempt outlasts the threshold', () {
      var slowCalls = 0;

      final result = settle(
        () => policy().run(
          () => answerAfter(_slowThreshold + const Duration(seconds: 1)),
          onSlow: () => slowCalls++,
        ),
      );

      expect(result, isA<Success<int>>());
      expect(slowCalls, 1);
    });

    test('does not fire for an operation that answers in time', () {
      var slowCalls = 0;

      settle(
        () => policy().run(
          () => answerAfter(_slowThreshold - const Duration(seconds: 1)),
          onSlow: () => slowCalls++,
        ),
      );

      expect(slowCalls, 0);
    });

    test('is published as slow, then as recovered once the run ends', () {
      final resilience = policy();
      final changes = <bool>[];
      final subscription = resilience.slowChanges.listen(changes.add);

      settle(
        () => resilience.run(
          () => answerAfter(_slowThreshold + const Duration(seconds: 1)),
        ),
      );

      expect(changes, [true, false]);
      unawaited(subscription.cancel());
    });

    test('stays slow while another slow run is still in flight', () {
      final resilience = policy();
      final changes = <bool>[];
      final subscription = resilience.slowChanges.listen(changes.add);

      fakeAsync((async) {
        unawaited(
          resilience.run(
            () => answerAfter(_slowThreshold + const Duration(seconds: 1)),
          ),
        );
        unawaited(
          resilience.run(
            () => answerAfter(_slowThreshold + const Duration(seconds: 2)),
          ),
        );
        async.elapse(_slowThreshold + const Duration(milliseconds: 1500));

        expect(changes, [true]);

        async.elapse(_longEnough);
      });

      expect(changes, [true, false]);
      unawaited(subscription.cancel());
    });
  });

  group('fault injection', () {
    ResilienceSettings faults({
      Duration latency = Duration.zero,
      Set<String> unavailable = const {},
    }) =>
        ResilienceSettings(latency: latency, unavailableServices: unavailable);

    test('delays every attempt by the injected latency', () {
      const latency = Duration(seconds: 2);
      Duration? startedAt;

      fakeAsync((async) {
        unawaited(
          policy(faults: () => faults(latency: latency)).run(() async {
            startedAt = async.elapsed;
            return 1;
          }),
        );
        async.elapse(_longEnough);
      });

      expect(startedAt, latency);
    });

    test('counts injected latency against the timeout', () {
      var calls = 0;

      final result = settle(
        () =>
            policy(
              faults: () =>
                  faults(latency: _timeout + const Duration(seconds: 1)),
            ).run(() async {
              calls++;
              return 1;
            }),
      );

      expect((result as Failed<int>).failure, isA<TimeoutFailure>());
      expect(calls, 0);
    });

    test('answers as unavailable for a service that was taken down', () {
      var calls = 0;

      final result = settle(
        () =>
            policy(
              faults: () => faults(unavailable: {ServiceIds.movements}),
            ).run(() async {
              calls++;
              return 1;
            }, serviceId: ServiceIds.movements),
      );

      final failure = (result as Failed<int>).failure;
      expect(failure, isA<ServiceUnavailableFailure>());
      expect(
        (failure as ServiceUnavailableFailure).serviceId,
        ServiceIds.movements,
      );
      expect(calls, 0);
    });

    test('leaves other services and unnamed operations untouched', () {
      ResiliencePolicy lab() => policy(
        faults: () => faults(unavailable: {ServiceIds.movements}),
      );

      final other = settle(
        () => lab().run(() async => 1, serviceId: ServiceIds.partnerInsurance),
      );
      final unnamed = settle(() => lab().run(() async => 2));

      expect(other, isA<Success<int>>());
      expect(unnamed, isA<Success<int>>());
    });

    test('reads the settings again on every attempt', () {
      var attempts = 0;

      final result = settle(
        () => policy(
          faults: () {
            attempts++;
            return attempts == 1
                ? faults(unavailable: {ServiceIds.movements})
                : ResilienceSettings.none;
          },
        ).run(() async => 9, serviceId: ServiceIds.movements),
      );

      expect((result as Success<int>).value, 9);
    });
  });
}
