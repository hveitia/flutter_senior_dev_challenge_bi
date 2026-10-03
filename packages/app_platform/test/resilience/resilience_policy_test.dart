import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
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

/// Most of these tests are about the retry path, which only operations
/// declared as safe to repeat go through.
extension on ResiliencePolicy {
  Future<Result<T>> runIdempotent<T>(
    Future<T> Function() operation, {
    String? serviceId,
    void Function(int attempt)? onRetry,
    void Function()? onSlow,
  }) {
    return run(
      operation,
      idempotent: true,
      serviceId: serviceId,
      onRetry: onRetry,
      onSlow: onSlow,
    );
  }
}

void main() {
  late List<Duration> requestedDelays;
  late InMemoryTelemetry telemetry;

  Future<void> recordingDelay(Duration duration) {
    requestedDelays.add(duration);
    return Future<void>.delayed(duration);
  }

  ResiliencePolicy policy({
    ResilienceSettings Function()? faults,
    bool allowFaultInjection = false,
    bool Function()? isOffline,
    double Function() random = _maxJitter,
  }) {
    return ResiliencePolicy(
      faults: faults,
      allowFaultInjection: allowFaultInjection,
      isOffline: isOffline,
      telemetry: telemetry,
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

  Future<int> never() => Completer<int>().future;

  List<Map<String, Object>> eventsNamed(String name) => telemetry.events
      .where((event) => event.name == name)
      .map((event) => event.parameters)
      .toList();

  setUp(() {
    requestedDelays = [];
    telemetry = InMemoryTelemetry();
  });

  group('a healthy operation', () {
    test('returns its value after a single attempt', () {
      var calls = 0;

      final result = settle(
        () => policy().runIdempotent(() async {
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
        () => policy().runIdempotent(() {
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
        () => policy().runIdempotent(() {
          calls++;
          return calls < 2 ? never() : Future.value(7);
        }),
      );

      expect((result as Success<int>).value, 7);
      expect(calls, 2);
    });

    test('announces every retry with the number of the attempt', () {
      final attempts = <int>[];

      settle(() => policy().runIdempotent(never, onRetry: attempts.add));

      expect(attempts, [2, 3]);
    });
  });

  group('backoff between attempts', () {
    test('doubles on every retry', () {
      settle(() => policy().runIdempotent(never));

      expect(requestedDelays, [_baseBackoff, _baseBackoff * 2]);
    });

    test('is never shorter than half of its nominal value', () {
      settle(() => policy(random: _minJitter).runIdempotent(never));

      expect(requestedDelays, [_baseBackoff ~/ 2, _baseBackoff]);
    });

    test('is not applied after the last attempt', () {
      settle(() => policy().runIdempotent(never));

      expect(requestedDelays, hasLength(ResiliencePolicy.maxAttempts - 1));
    });
  });

  group('failures', () {
    test('an unexpected error is not retried and keeps its cause', () {
      var calls = 0;
      final cause = StateError('bug');

      final result = settle(
        () => policy().runIdempotent<int>(() {
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
        () => policy().runIdempotent<int>(
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
        () => policy().runIdempotent<int>(() {
          calls++;
          throw const ServiceUnavailableFailure(ServiceIds.movements);
        }),
      );

      expect(calls, ResiliencePolicy.maxAttempts);
    });

    test('being offline fails at once without calling the operation', () {
      var calls = 0;

      final result = settle(
        () => policy(isOffline: () => true).runIdempotent(() async {
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
        () => policy(isOffline: () => calls > 0).runIdempotent(() {
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
        () => policy().runIdempotent(
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
        () => policy().runIdempotent(
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
        () => resilience.runIdempotent(
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
          resilience.runIdempotent(
            () => answerAfter(_slowThreshold + const Duration(seconds: 1)),
          ),
        );
        unawaited(
          resilience.runIdempotent(
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
          policy(
            allowFaultInjection: true,
            faults: () => faults(latency: latency),
          ).runIdempotent(() async {
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
              allowFaultInjection: true,
              faults: () =>
                  faults(latency: _timeout + const Duration(seconds: 1)),
            ).runIdempotent(() async {
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
              allowFaultInjection: true,
              faults: () => faults(unavailable: {ServiceIds.movements}),
            ).runIdempotent(() async {
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
        allowFaultInjection: true,
        faults: () => faults(unavailable: {ServiceIds.movements}),
      );

      final other = settle(
        () => lab().runIdempotent(
          () async => 1,
          serviceId: ServiceIds.partnerInsurance,
        ),
      );
      final unnamed = settle(() => lab().runIdempotent(() async => 2));

      expect(other, isA<Success<int>>());
      expect(unnamed, isA<Success<int>>());
    });

    test('reads the settings again on every attempt', () {
      var attempts = 0;

      final result = settle(
        () => policy(
          allowFaultInjection: true,
          faults: () {
            attempts++;
            return attempts == 1
                ? faults(unavailable: {ServiceIds.movements})
                : ResilienceSettings.none;
          },
        ).runIdempotent(() async => 9, serviceId: ServiceIds.movements),
      );

      expect((result as Success<int>).value, 9);
    });
  });

  group('an operation not declared idempotent', () {
    test('is attempted exactly once when it times out', () {
      var calls = 0;

      final result = settle(
        () => policy().run(() {
          calls++;
          return never();
        }, idempotent: false),
      );

      expect(calls, 1);
      expect((result as Failed<int>).failure, isA<TimeoutFailure>());
    });

    test('is attempted exactly once when the service is unavailable', () {
      var calls = 0;

      final result = settle(
        () => policy().run<int>(() {
          calls++;
          throw const ServiceUnavailableFailure(ServiceIds.movements);
        }, idempotent: false),
      );

      expect(calls, 1);
      expect((result as Failed<int>).failure, isA<ServiceUnavailableFailure>());
    });

    test('never waits for a backoff nor announces a retry', () {
      final attempts = <int>[];

      settle(
        () => policy().run(never, idempotent: false, onRetry: attempts.add),
      );

      expect(requestedDelays, isEmpty);
      expect(attempts, isEmpty);
      expect(eventsNamed(ResilienceTelemetry.retry), isEmpty);
      expect(eventsNamed(ResilienceTelemetry.attemptsExhausted), isEmpty);
    });
  });

  group('telemetry', () {
    test('reports every timeout with the service and the attempt', () {
      settle(
        () => policy().runIdempotent(never, serviceId: ServiceIds.movements),
      );

      expect(eventsNamed(ResilienceTelemetry.timeout), [
        for (
          var attempt = 1;
          attempt <= ResiliencePolicy.maxAttempts;
          attempt++
        )
          {
            ResilienceTelemetry.serviceKey: ServiceIds.movements,
            ResilienceTelemetry.attemptKey: attempt,
          },
      ]);
    });

    test('reports every retry with the attempt about to start', () {
      settle(
        () => policy().runIdempotent(never, serviceId: ServiceIds.movements),
      );

      expect(eventsNamed(ResilienceTelemetry.retry), [
        {
          ResilienceTelemetry.serviceKey: ServiceIds.movements,
          ResilienceTelemetry.attemptKey: 2,
        },
        {
          ResilienceTelemetry.serviceKey: ServiceIds.movements,
          ResilienceTelemetry.attemptKey: 3,
        },
      ]);
    });

    test('reports when the attempts ran out', () {
      settle(
        () => policy().runIdempotent(never, serviceId: ServiceIds.movements),
      );

      expect(eventsNamed(ResilienceTelemetry.attemptsExhausted), [
        {
          ResilienceTelemetry.serviceKey: ServiceIds.movements,
          ResilienceTelemetry.attemptKey: ResiliencePolicy.maxAttempts,
        },
      ]);
    });

    test('names the service as unnamed when the caller gave none', () {
      settle(() => policy().run(never, idempotent: false));

      expect(eventsNamed(ResilienceTelemetry.timeout).single, {
        ResilienceTelemetry.serviceKey: ResilienceTelemetry.unnamedService,
        ResilienceTelemetry.attemptKey: 1,
      });
    });

    test('reports nothing for an operation that answers at once', () {
      settle(() => policy().runIdempotent(() async => 1));

      expect(telemetry.events, isEmpty);
      expect(telemetry.errors, isEmpty);
      expect(telemetry.logs, isEmpty);
    });
  });

  group('fault injection gate', () {
    ResilienceSettings everythingDown() => const ResilienceSettings(
      latency: Duration(seconds: 2),
      unavailableServices: {ServiceIds.movements},
    );

    test('ignores the published faults unless the build allows them', () {
      Duration? startedAt;

      fakeAsync((async) {
        Result<int>? result;
        unawaited(
          policy(faults: everythingDown)
              .run(
                () async {
                  startedAt = async.elapsed;
                  return 1;
                },
                idempotent: false,
                serviceId: ServiceIds.movements,
              )
              .then((value) => result = value),
        );
        async.elapse(_longEnough);

        expect(result, isA<Success<int>>());
      });

      expect(startedAt, Duration.zero);
    });

    test('is reported once when the build allows it', () {
      final lab = policy(allowFaultInjection: true, faults: everythingDown);

      settle(() => lab.run(() async => 1, idempotent: false));
      settle(() => lab.run(() async => 2, idempotent: false));

      expect(
        eventsNamed(ResilienceTelemetry.faultInjectionEnabled),
        hasLength(1),
      );
    });

    test('is not reported when the build does not allow it', () {
      settle(
        () => policy(faults: everythingDown).run(
          () async => 1,
          idempotent: false,
        ),
      );

      expect(eventsNamed(ResilienceTelemetry.faultInjectionEnabled), isEmpty);
    });
  });

  group('timers', () {
    test('none is left pending once an attempt has answered', () {
      fakeAsync((async) {
        unawaited(policy().run(() async => 1, idempotent: false));
        async.flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
