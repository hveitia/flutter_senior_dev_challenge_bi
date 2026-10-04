import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:feature_accounts/adapters.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeTransfersApi api;
  late InMemoryTransferQueue queue;
  late InMemoryTelemetry telemetry;
  late bool online;
  late DefaultTransfersRepository repository;

  const order = TransferOrder(
    id: 'order-0000000000000001',
    fromAccountId: 'savings',
    toAccountId: 'checking',
    amountCents: 15010,
    concept: 'Arriendo',
  );

  setUp(() {
    api = FakeTransfersApi();
    queue = InMemoryTransferQueue();
    telemetry = InMemoryTelemetry();
    online = true;
    repository = DefaultTransfersRepository(
      api: api,
      queue: queue,
      telemetry: telemetry,
      isOnline: () async => online,
      policy: ResiliencePolicy(
        isOffline: () => !online,
        // Backoff ends at once: the tests are about what happens, not when.
        delay: (_) async {},
        timeout: const Duration(milliseconds: 20),
      ),
    );
  });

  group('send', () {
    test('settles the order on the server and returns its reference', () async {
      api.onCall = () async => const ApiTransferCompleted('TRF-1');

      final outcome = await repository.send(order);

      expect(outcome, const TransferCompleted(reference: 'TRF-1'));
      expect(api.submitted, [order]);
      expect(queue.orders, isEmpty);
    });

    test('returns the reason when the server refuses it', () async {
      api.onCall = () async =>
          const ApiTransferRejected(TransferRejection.insufficientFunds);

      final outcome = await repository.send(order);

      expect(
        outcome,
        const TransferRejected(TransferRejection.insufficientFunds),
      );
      expect(queue.orders, isEmpty);
    });

    test('without a connection, keeps the order on the device and asks the '
        'server nothing', () async {
      online = false;

      final outcome = await repository.send(order);

      expect(outcome, const TransferQueued());
      expect(queue.orders, [order]);
      expect(api.submitted, isEmpty);
    });

    test('queues the order when the connection drops just before the '
        'request leaves', () async {
      // The repository saw a connection; the policy, a moment later, does
      // not, and so never starts the request.
      final justDropped = DefaultTransfersRepository(
        api: api,
        queue: queue,
        telemetry: telemetry,
        isOnline: () async => true,
        policy: ResiliencePolicy(isOffline: () => true, delay: (_) async {}),
      );

      final outcome = await justDropped.send(order);

      expect(outcome, const TransferQueued());
      expect(queue.orders, [order]);
      expect(api.submitted, isEmpty);
      expect(justDropped.unresolved, isNull);
    });

    test('after a timeout, tries the same order again and, if it still does '
        'not answer, queues nothing', () async {
      api.onCall = () => Future.delayed(const Duration(seconds: 1), () {
        return const ApiTransferCompleted('late');
      });

      final outcome = await repository.send(order);

      expect(outcome, isA<TransferNotSent>());
      expect(api.submitted.length, greaterThan(1));
      expect(api.submitted.toSet(), {order});
      // The server may have settled it: a queued copy would hide that.
      expect(queue.orders, isEmpty);
    });

    test('an order whose request already left is never queued, even if the '
        'connection is gone by the next attempt', () async {
      api.onCall = () {
        // The request leaves and gets no answer in time; by the time the
        // policy tries again the device is offline.
        online = false;
        return Future.delayed(
          const Duration(seconds: 1),
          () => const ApiTransferCompleted('late'),
        );
      };

      final outcome = await repository.send(order);

      // The server may have settled it: only the same order, sent again,
      // can tell. A queued copy would promise something else.
      expect(outcome, isA<TransferNotSent>());
      expect(queue.orders, isEmpty);
      expect(api.submitted, [order]);
    });

    test('an order that left is not queued when the customer repeats it '
        'without a connection', () async {
      api.onCall = () => Future.delayed(
        const Duration(seconds: 1),
        () => const ApiTransferCompleted('late'),
      );
      await repository.send(order);
      final askedBefore = api.submitted.length;

      // The customer taps "Reintentar" with the connection gone.
      online = false;
      final outcome = await repository.send(order);

      // The first request may have been settled: a queued copy would say
      // "it will be sent" about an order that may already be done.
      expect(outcome, isA<TransferNotSent>());
      expect(queue.orders, isEmpty);
      expect(api.submitted, hasLength(askedBefore));
      expect(repository.unresolved, order);
    });

    test('an order that left is not queued when the policy finds no '
        'connection before the first attempt of its repeat', () async {
      var policyOffline = false;
      final flaky = DefaultTransfersRepository(
        api: api,
        queue: queue,
        telemetry: telemetry,
        // The repository always sees a connection; only the policy, a
        // moment later, does not.
        isOnline: () async => true,
        policy: ResiliencePolicy(
          isOffline: () => policyOffline,
          delay: (_) async {},
          timeout: const Duration(milliseconds: 20),
        ),
      );
      api.onCall = () => Future.delayed(
        const Duration(seconds: 1),
        () => const ApiTransferCompleted('late'),
      );
      await flaky.send(order);
      final askedBefore = api.submitted.length;

      policyOffline = true;
      final outcome = await flaky.send(order);

      expect(outcome, isA<TransferNotSent>());
      expect(queue.orders, isEmpty);
      expect(api.submitted, hasLength(askedBefore));
      expect(flaky.unresolved, order);
    });

    test('a different order placed without a connection is still queued '
        'while an earlier one awaits its answer', () async {
      api.onCall = () => Future.delayed(
        const Duration(seconds: 1),
        () => const ApiTransferCompleted('late'),
      );
      await repository.send(order);
      const other = TransferOrder(
        id: 'order-0000000000000002',
        fromAccountId: 'checking',
        toAccountId: 'savings',
        amountCents: 500,
      );

      online = false;
      final outcome = await repository.send(other);

      expect(outcome, const TransferQueued());
      expect(queue.orders, [other]);
    });

    test('a bank that says it has no such order ends it: no money moved, and '
        'the customer is free to place another', () async {
      api.onCall = () => Future.delayed(
        const Duration(seconds: 1),
        () => const ApiTransferCompleted('late'),
      );
      await repository.send(order);
      expect(repository.unresolved, order);

      api.onCall = () async => const ApiTransferNotFound();
      final outcome = await repository.send(order);

      expect(outcome, const TransferStopped(TransferStop.notAccepted));
      expect(repository.unresolved, isNull);
      expect(queue.orders, isEmpty);
    });

    for (final (status, stop) in [
      (401, TransferStop.sessionExpired),
      (409, TransferStop.orderChanged),
      (400, TransferStop.notAccepted),
      (413, TransferStop.notAccepted),
      (415, TransferStop.notAccepted),
    ]) {
      test('a $status is an answer about the request: it stops the order as '
          '${stop.name}, is asked once and queues nothing', () async {
        api.onCall = () => throw ApiContractError(status, 'code');

        final outcome = await repository.send(order);

        expect(outcome, TransferStopped(stop));
        expect(api.submitted, hasLength(1));
        expect(queue.orders, isEmpty);
      });
    }
  });

  group('unresolved', () {
    test('is the order that left without a final answer', () async {
      api.onCall = () => Future.delayed(
        const Duration(seconds: 1),
        () => const ApiTransferCompleted('late'),
      );

      await repository.send(order);

      expect(repository.unresolved, order);
    });

    test('is cleared once the same order gets a final answer', () async {
      api.onCall = () => Future.delayed(
        const Duration(seconds: 1),
        () => const ApiTransferCompleted('late'),
      );
      await repository.send(order);

      api.onCall = () async => const ApiTransferCompleted('TRF-1');
      await repository.send(order);

      expect(repository.unresolved, isNull);
    });

    test(
      'is nothing after an order the server settled, refused or stopped',
      () async {
        await repository.send(order);
        expect(repository.unresolved, isNull);

        api.onCall = () async =>
            const ApiTransferRejected(TransferRejection.insufficientFunds);
        await repository.send(order);
        expect(repository.unresolved, isNull);

        api.onCall = () => throw const ApiContractError(409, 'key-reused');
        await repository.send(order);
        expect(repository.unresolved, isNull);
      },
    );

    test('is nothing for an order that never left the device', () async {
      online = false;

      await repository.send(order);

      expect(repository.unresolved, isNull);
    });
  });

  group('watchRefused', () {
    test('passes on the id of a queued order the bank turned away', () async {
      final refused = <String>[];
      final subscription = repository.watchRefused().listen(refused.add);
      addTearDown(subscription.cancel);

      queue.refusals.add(order.id);
      await Future<void>.delayed(Duration.zero);

      expect(refused, [order.id]);
    });
  });

  group('settle', () {
    test('an answer about the request itself stops the queued order instead '
        'of asking again for ever', () async {
      api.onCall = () => throw const ApiContractError(400, 'invalid-request');

      expect(
        await repository.settle(order.id),
        const TransferStopped(TransferStop.notAccepted),
      );
      expect(api.processed, [order.id]);
    });

    test('returns the outcome of a queued order the server settled', () async {
      api.onCall = () async => const ApiTransferCompleted('TRF-2');

      expect(
        await repository.settle(order.id),
        const TransferCompleted(reference: 'TRF-2'),
      );
      expect(api.processed, [order.id]);
    });

    test('is null while the server has not received the order', () async {
      api.onCall = () async => const ApiTransferNotFound();

      expect(await repository.settle(order.id), isNull);
    });

    test('says so when the server cannot be reached', () async {
      online = false;

      expect(await repository.settle(order.id), isA<TransferNotSent>());
    });
  });

  group('provisionAccounts', () {
    test('asks the server and reports that it worked', () async {
      final result = await repository.provisionAccounts();

      expect(result, isA<Success<void>>());
      expect(api.provisionCalls, 1);
      expect(telemetry.events.single.name, TransfersTelemetry.provisioned);
    });

    test('reports the kind of failure and returns it', () async {
      online = false;

      final result = await repository.provisionAccounts();

      expect(result, isA<Failed<void>>());
      expect(telemetry.events.single.parameters, {
        TransfersTelemetry.reasonKey: 'offline',
      });
    });
  });

  group('telemetry', () {
    test('a completed transfer is reported with no detail of it', () async {
      await repository.send(order);

      expect(telemetry.events.single.name, TransfersTelemetry.completed);
      expect(telemetry.events.single.parameters, isEmpty);
    });

    test('a rejection carries its reason code and nothing else', () async {
      api.onCall = () async =>
          const ApiTransferRejected(TransferRejection.insufficientFunds);

      await repository.send(order);

      expect(telemetry.events.single.name, TransfersTelemetry.rejected);
      expect(telemetry.events.single.parameters, {
        TransfersTelemetry.reasonKey: 'insufficient-funds',
      });
    });

    test('nothing reported names an account, an amount, the concept or the '
        'order', () async {
      api.onCall = () => throw const ApiContractError(409, 'key-reused');
      await repository.send(order);
      online = false;
      await repository.send(order);

      final reported = [
        for (final event in telemetry.events)
          '${event.name} ${event.parameters}',
        for (final error in telemetry.errors) '${error.error} ${error.reason}',
      ].join(' ');

      for (final secret in [
        order.id,
        order.fromAccountId,
        order.toAccountId,
        '${order.amountCents}',
        order.concept,
      ]) {
        expect(reported, isNot(contains(secret)));
      }
    });
  });
}
