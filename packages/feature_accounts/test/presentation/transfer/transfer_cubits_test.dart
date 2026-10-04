import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_cubit.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  late FakeTransfersRepository repository;

  setUp(() => repository = FakeTransfersRepository());

  group('TransferCubit', () {
    var nextId = 0;

    TransferCubit cubit({
      List<Account> accounts = const [savings, checking, fund],
      String? from,
    }) {
      final created = TransferCubit(
        repository: repository,
        telemetry: InMemoryTelemetry(),
        accounts: () => accounts,
        fromAccountId: from,
        newId: () => 'order-${nextId++}',
      );
      addTearDown(created.close);
      return created;
    }

    setUp(() => nextId = 0);

    Future<TransferCubit> readyToConfirm() async {
      final created = cubit()
        ..amountChanged('15010')
        ..continueRequested();
      expect(created.state.step, TransferStep.confirming);
      return created;
    }

    test('starts from the account the customer came from, towards the other '
        'spendable one', () {
      final created = cubit(from: 'checking');

      expect(created.state.fromAccountId, 'checking');
      expect(created.state.toAccountId, 'savings');
      expect(created.candidates, const [savings, checking]);
    });

    test('an investment is never offered as a source', () {
      final created = cubit(from: 'fund');

      expect(created.state.fromAccountId, 'savings');
    });

    test('choosing as source the account that was the destination clears '
        'the destination', () {
      final created = cubit()..fromSelected('checking');

      expect(created.state.fromAccountId, 'checking');
      expect(created.state.toAccountId, isNull);
    });

    test('does not continue with an error, and shows it from then on', () {
      final created = cubit()
        ..amountChanged('99999999')
        ..continueRequested();

      expect(created.state.step, TransferStep.editing);
      expect(created.state.showsErrors, isTrue);
      expect(created.error, TransferFormError.overLimit);
    });

    test('says insufficient funds for one cent over the available balance', () {
      final created = cubit()..amountChanged('357036');

      expect(created.error, TransferFormError.insufficientFunds);
    });

    test('sends the order as typed, with the concept trimmed', () async {
      final created = cubit()
        ..amountChanged('15010')
        ..conceptChanged('  Arriendo ')
        ..continueRequested();

      await created.confirmed();

      expect(repository.sent, const [
        TransferOrder(
          id: 'order-0',
          fromAccountId: 'savings',
          toAccountId: 'checking',
          amountCents: 15010,
          concept: 'Arriendo',
        ),
      ]);
      expect(created.state.step, TransferStep.done);
      expect(created.state.outcome, isA<TransferCompleted>());
    });

    test('a second confirmation while the first is in flight sends nothing '
        'more', () async {
      final answer = Completer<TransferOutcome>();
      repository.onSend = (_) => answer.future;
      final created = await readyToConfirm();

      final first = created.confirmed();
      final second = created.confirmed();
      expect(created.state.step, TransferStep.sending);
      answer.complete(const TransferQueued());
      await Future.wait([first, second]);

      expect(repository.sent, hasLength(1));
      expect(created.state.outcome, const TransferQueued());
    });

    test(
      'retrying an order that could not be sent sends the same id',
      () async {
        repository.onSend = (_) async =>
            const TransferNotSent(TimeoutFailure());
        final created = await readyToConfirm();
        await created.confirmed();

        repository.onSend = (_) async =>
            const TransferCompleted(reference: 'TRF-1');
        await created.retryRequested();

        expect(repository.sent.map((order) => order.id), [
          'order-0',
          'order-0',
        ]);
        expect(
          created.state.outcome,
          const TransferCompleted(reference: 'TRF-1'),
        );
      },
    );

    test('an order that was settled cannot be sent again', () async {
      final created = await readyToConfirm();
      await created.confirmed();

      await created.retryRequested();
      await created.confirmed();

      expect(repository.sent, hasLength(1));
    });

    test('opens on the order whose outcome is unknown, so the only thing to '
        'send is that same order', () async {
      repository
        ..unresolved = const TransferOrder(
          id: 'order-left',
          fromAccountId: 'checking',
          toAccountId: 'savings',
          amountCents: 2500,
          concept: 'Arriendo',
        )
        ..onSend = (_) async => const TransferCompleted(reference: 'TRF-9');

      final created = cubit();

      expect(created.state.step, TransferStep.done);
      expect(created.state.outcome, isA<TransferNotSent>());
      expect(created.state.fromAccountId, 'checking');
      expect(created.state.toAccountId, 'savings');
      expect(created.state.amountCents, 2500);

      await created.retryRequested();

      expect(repository.sent.single.id, 'order-left');
      expect(repository.sent.single.concept, 'Arriendo');
      expect(
        created.state.outcome,
        const TransferCompleted(reference: 'TRF-9'),
      );
    });

    test('repeats the order whose outcome is unknown even when its accounts '
        'are no longer listed, so the bank can answer for it', () async {
      repository
        ..unresolved = const TransferOrder(
          id: 'order-left',
          fromAccountId: 'closed-account',
          toAccountId: 'savings',
          amountCents: 2500,
          concept: 'Arriendo',
        )
        ..onSend = (_) async =>
            const TransferRejected(TransferRejection.unknownAccount);
      final created = cubit();

      await created.retryRequested();

      // Doing nothing would leave the customer on a button that never
      // answers; the same order, sent again, gets the bank's final word.
      expect(repository.sent.single.id, 'order-left');
      expect(repository.sent.single.fromAccountId, 'closed-account');
      expect(
        created.state.outcome,
        const TransferRejected(TransferRejection.unknownAccount),
      );
    });

    test('after an order the server says changed, starting over goes back to '
        'the form and the next order has a new id', () async {
      repository.onSend = (_) async =>
          const TransferStopped(TransferStop.orderChanged);
      final created = await readyToConfirm();
      await created.confirmed();

      created.startOverRequested();

      expect(created.state.step, TransferStep.editing);
      expect(created.state.outcome, isNull);
      expect(created.state.amountCents, 15010);

      repository.onSend = (_) async =>
          const TransferCompleted(reference: 'TRF-2');
      created.continueRequested();
      await created.confirmed();

      expect(repository.sent.map((order) => order.id), ['order-0', 'order-1']);
    });

    test('starting over is only for an order that cannot go on: one that '
        'was carried out or may still be stays as it is', () async {
      final created = await readyToConfirm();
      await created.confirmed();

      created.startOverRequested();

      expect(created.state.step, TransferStep.done);

      repository.onSend = (_) async => const TransferNotSent(TimeoutFailure());
      final other = await readyToConfirm();
      await other.confirmed();

      other.startOverRequested();

      expect(other.state.step, TransferStep.done);
    });

    test('an order that was stopped is not offered to be sent again', () async {
      repository.onSend = (_) async =>
          const TransferStopped(TransferStop.sessionExpired);
      final created = await readyToConfirm();
      await created.confirmed();

      await created.retryRequested();

      expect(repository.sent, hasLength(1));
    });

    test('the form cannot be edited once the order is confirmed', () async {
      final created = await readyToConfirm();

      created
        ..amountChanged('1')
        ..toSelected('fund');

      expect(created.state.amountCents, 15010);
    });
  });

  group('TransferOutboxCubit', () {
    late StreamController<bool> onlineChanges;
    late bool online;
    late List<Completer<void>> waits;

    TransferOutboxCubit outbox() {
      final created = TransferOutboxCubit(
        repository: repository,
        onlineChanges: onlineChanges.stream,
        isOnline: () async => online,
        delay: (_) {
          final wait = Completer<void>();
          waits.add(wait);
          return wait.future;
        },
      );
      addTearDown(created.close);
      return created;
    }

    const first = QueuedTransfer(id: 'order-a', amountCents: 100);
    const second = QueuedTransfer(id: 'order-b', amountCents: 200);

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() {
      onlineChanges = StreamController<bool>.broadcast();
      online = true;
      waits = [];
    });

    test('settles the queued orders one after another, in order', () async {
      final running = <String>[];
      var concurrent = 0;
      var maxConcurrent = 0;
      repository.onSettle = (id) async {
        concurrent++;
        maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
        running.add(id);
        await Future<void>.delayed(Duration.zero);
        concurrent--;
        return const TransferCompleted(reference: 'TRF');
      };
      final created = outbox();

      repository.queued.add(const [first, second]);
      await settle();
      await settle();
      await settle();

      expect(running, ['order-a', 'order-b']);
      expect(maxConcurrent, 1);
      expect(created.state.hasUnsent, isTrue);
    });

    test('asks nothing while there is no connection, and settles when it '
        'returns', () async {
      online = false;
      outbox();
      repository.queued.add(const [first]);
      await settle();
      expect(repository.settled, isEmpty);

      online = true;
      onlineChanges.add(true);
      await settle();
      await settle();

      expect(repository.settled, ['order-a']);
    });

    test('keeps the reason of a queued order the server refused until it is '
        'dismissed', () async {
      repository.onSettle = (_) async =>
          const TransferRejected(TransferRejection.insufficientFunds);
      final created = outbox();

      repository.queued.add(const [first]);
      await settle();
      await settle();
      repository.queued.add(const []);
      await settle();

      expect(created.state.hasUnsent, isFalse);
      expect(created.state.lastRejection, TransferRejection.insufficientFunds);

      created.rejectionDismissed();
      expect(created.state.lastRejection, isNull);
    });

    test('asks again later for an order the server did not have yet', () async {
      repository.onSettle = (_) async => null;
      outbox();
      repository.queued.add(const [first]);
      await settle();
      await settle();
      expect(repository.settled, ['order-a']);
      expect(waits, hasLength(1));

      repository.onSettle = (_) async =>
          const TransferCompleted(reference: 'TRF');
      waits.single.complete();
      await settle();
      await settle();

      expect(repository.settled, ['order-a', 'order-a']);
    });

    test('an order queued while another is being settled is settled too, '
        'without waiting for anything else to happen', () async {
      final firstSettles = Completer<TransferOutcome?>();
      repository.onSettle = (id) => id == first.id
          ? firstSettles.future
          : Future.value(const TransferCompleted(reference: 'TRF-b'));
      outbox();
      repository.queued.add(const [first]);
      await settle();
      expect(repository.settled, [first.id]);

      // The second order arrives while the first is still with the server.
      repository.queued.add(const [first, second]);
      await settle();
      firstSettles.complete(const TransferCompleted(reference: 'TRF-a'));
      await settle();
      await settle();

      expect(repository.settled, containsAllInOrder([first.id, second.id]));
      expect(waits, isEmpty);
    });

    test('never settles two orders at once, however often the queue and the '
        'connection change', () async {
      var concurrent = 0;
      var maxConcurrent = 0;
      final gates = <Completer<void>>[];
      repository.onSettle = (id) async {
        concurrent++;
        maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        concurrent--;
        return const TransferCompleted(reference: 'TRF');
      };
      outbox();
      repository.queued.add(const [first, second]);
      await settle();
      onlineChanges.add(true);
      repository.queued.add(const [first, second]);
      onlineChanges.add(true);
      await settle();

      while (gates.any((gate) => !gate.isCompleted)) {
        gates.firstWhere((gate) => !gate.isCompleted).complete();
        await settle();
        await settle();
      }

      expect(maxConcurrent, 1);
    });

    test('settles nothing once it is closed', () async {
      final created = outbox();
      await created.close();

      repository.queued.add(const [first]);
      onlineChanges.add(true);
      await settle();

      expect(repository.settled, isEmpty);
    });

    test('tells the customer when the bank turned a queued order away and '
        'knows nothing of it', () async {
      repository.onSettle = (_) async => null;
      final created = outbox();

      repository.refused.add(first.id);
      await settle();
      await settle();

      expect(repository.settled, [first.id]);
      expect(created.state.hasRefused, isTrue);

      created.rejectionDismissed();
      expect(created.state.hasRefused, isFalse);
    });

    test('an order turned away because the bank had already carried it out '
        'needs no notice: its movement shows', () async {
      repository.onSettle = (_) async =>
          const TransferCompleted(reference: 'TRF-a');
      final created = outbox();

      repository.refused.add(first.id);
      await settle();
      await settle();

      expect(created.state.hasRefused, isFalse);
      expect(created.state.lastRejection, isNull);
    });

    test('an order turned away that the bank had refused says why', () async {
      repository.onSettle = (_) async =>
          const TransferRejected(TransferRejection.insufficientFunds);
      final created = outbox();

      repository.refused.add(first.id);
      await settle();
      await settle();

      expect(
        created.state.lastRejection,
        TransferRejection.insufficientFunds,
      );
    });

    for (final (name, unanswered) in <(String, TransferOutcome)>[
      ('the bank does not answer', const TransferNotSent(TimeoutFailure())),
      ('there is no connection', const TransferNotSent(OfflineFailure())),
      (
        'the session has to be renewed',
        const TransferStopped(TransferStop.sessionExpired),
      ),
    ]) {
      test('an order turned away is not reported as lost while $name: it is '
          'asked about again later', () async {
        repository.onSettle = (_) async => unanswered;
        final created = outbox();

        repository.refused.add(first.id);
        await settle();
        await settle();

        // Nothing is known yet: saying "no se pudo enviar" could be false.
        expect(created.state.hasRefused, isFalse);
        expect(created.state.lastRejection, isNull);
        expect(waits, hasLength(1));

        // Later the bank answers that it had carried it out.
        repository.onSettle = (_) async =>
            const TransferCompleted(reference: 'TRF-a');
        waits.single.complete();
        await settle();
        await settle();

        expect(repository.settled, [first.id, first.id]);
        expect(created.state.hasRefused, isFalse);
      });
    }

    test('an order turned away that had no answer is asked about again when '
        'the connection returns, and then reported if the bank knows nothing '
        'of it', () async {
      online = false;
      repository.onSettle = (_) async =>
          const TransferNotSent(OfflineFailure());
      final created = outbox();

      repository.refused.add(first.id);
      await settle();
      await settle();
      expect(created.state.hasRefused, isFalse);

      online = true;
      repository.onSettle = (_) async => null;
      onlineChanges.add(true);
      await settle();
      await settle();

      expect(created.state.hasRefused, isTrue);
      expect(repository.settled, [first.id, first.id]);
    });

    test('a queued order the server cannot read is reported once and not '
        'asked for again', () async {
      repository.onSettle = (_) async =>
          const TransferStopped(TransferStop.notAccepted);
      final created = outbox();

      repository.queued.add(const [first]);
      await settle();
      await settle();
      repository.queued.add(const [first]);
      await settle();
      await settle();

      expect(created.state.hasRefused, isTrue);
      expect(repository.settled, [first.id]);
      expect(waits, isEmpty);
    });

    test('tells apart the orders the bank already has from the ones that '
        'exist only on this device', () async {
      repository.onSettle = (_) async => null;
      final created = outbox();

      repository.queued.add(const [
        QueuedTransfer(id: 'order-a', amountCents: 100, isDelivered: true),
        second,
      ]);
      await settle();

      expect(created.state.deliveredCount, 1);
      expect(created.state.onDeviceOnlyCount, 1);
    });

    test('says there are orders unsent, for whoever is about to end the '
        'session', () async {
      online = false;
      final created = outbox();
      expect(created.state.hasUnsent, isFalse);

      repository.queued.add(const [first]);
      await settle();

      expect(created.state.hasUnsent, isTrue);
      expect(created.state.queued, const [first]);
    });
  });

  group('AccountProvisioningCubit', () {
    late StreamController<AccountsState> accounts;

    AccountProvisioningCubit provisioning() {
      final created = AccountProvisioningCubit(
        repository: repository,
        accounts: accounts.stream,
      );
      addTearDown(created.close);
      return created;
    }

    AccountsState state(List<Account>? data, {required DataOrigin origin}) =>
        AccountsState(
          accounts: LoadState(data: data, origin: origin, syncedAt: now),
        );

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() => accounts = StreamController<AccountsState>.broadcast());

    test('asks the server once when it confirms the customer has no '
        'accounts', () async {
      final created = provisioning();

      accounts
        ..add(state(const [], origin: DataOrigin.server))
        ..add(state(const [], origin: DataOrigin.server));
      await settle();

      expect(repository.provisionCalls, 1);
      expect(created.state, ProvisioningStatus.idle);
    });

    test(
      'does not ask because the copy saved on the device is empty',
      () async {
        provisioning();

        accounts.add(state(const [], origin: DataOrigin.cache));
        await settle();

        expect(repository.provisionCalls, 0);
      },
    );

    test('does not ask for a customer who has accounts', () async {
      provisioning();

      accounts.add(state(const [savings], origin: DataOrigin.server));
      await settle();

      expect(repository.provisionCalls, 0);
    });

    test(
      'after a failure, asks again only when the customer says so',
      () async {
        repository.onProvision = () async => const Failed(TimeoutFailure());
        final created = provisioning();
        accounts.add(state(const [], origin: DataOrigin.server));
        await settle();
        expect(created.state, ProvisioningStatus.failed);

        accounts.add(state(const [], origin: DataOrigin.server));
        await settle();
        expect(repository.provisionCalls, 1);

        repository.onProvision = () async => const Success(null);
        await created.retryRequested();

        expect(repository.provisionCalls, 2);
        expect(created.state, ProvisioningStatus.idle);
      },
    );
  });
}
