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
      api.onCall = () => throw const OfflineFailure();

      final outcome = await repository.send(order);

      expect(outcome, const TransferQueued());
      expect(queue.orders, [order]);
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

    test('an answer the app cannot act on is not retried and reaches the '
        'customer as not sent', () async {
      api.onCall = () => throw const ApiContractError(409, 'key-reused');

      final outcome = await repository.send(order);

      expect(outcome, isA<TransferNotSent>());
      expect(api.submitted, hasLength(1));
    });
  });

  group('settle', () {
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
