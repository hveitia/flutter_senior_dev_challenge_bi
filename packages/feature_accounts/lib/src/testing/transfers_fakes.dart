import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/data/transfer_ports.dart';
import 'package:feature_accounts/src/domain/transfer.dart';
import 'package:feature_accounts/src/domain/transfers_repository.dart';

/// A [TransfersRepository] driven by the test.
final class FakeTransfersRepository implements TransfersRepository {
  /// Every order sent, newest last. Repeating an order appears twice, with
  /// the same id.
  final List<TransferOrder> sent = [];

  /// The ids asked to be settled, newest last.
  final List<String> settled = [];

  final StreamController<List<QueuedTransfer>> queued =
      StreamController.broadcast();

  /// How `send` ends. Replace it to script an outcome or to hold the call.
  Future<TransferOutcome> Function(TransferOrder order) onSend =
      (order) async =>
          const TransferCompleted(reference: 'TRF-202610-0000000000');

  /// How `settle` ends for each id.
  Future<TransferOutcome?> Function(String transferId) onSettle =
      (transferId) async =>
          const TransferCompleted(reference: 'TRF-202610-0000000000');

  Future<Result<void>> Function() onProvision = () async => const Success(null);
  int provisionCalls = 0;

  @override
  Future<TransferOutcome> send(TransferOrder order) {
    sent.add(order);
    return onSend(order);
  }

  @override
  Future<TransferOutcome?> settle(String transferId) {
    settled.add(transferId);
    return onSettle(transferId);
  }

  @override
  Stream<List<QueuedTransfer>> watchQueued() => queued.stream;

  @override
  Future<Result<void>> provisionAccounts() {
    provisionCalls++;
    return onProvision();
  }
}

/// A [TransfersApi] that answers what the test scripted.
final class FakeTransfersApi implements TransfersApi {
  final List<TransferOrder> submitted = [];
  final List<String> processed = [];
  int provisionCalls = 0;

  /// What each call does: return an answer or throw a failure.
  Future<ApiTransferAnswer> Function() onCall = () async =>
      const ApiTransferCompleted('TRF-202610-0000000000');
  Future<void> Function() onProvision = () async {};

  @override
  Future<ApiTransferAnswer> submit(TransferOrder order) {
    submitted.add(order);
    return onCall();
  }

  @override
  Future<ApiTransferAnswer> process(String transferId) {
    processed.add(transferId);
    return onCall();
  }

  @override
  Future<void> provisionAccounts() {
    provisionCalls++;
    return onProvision();
  }
}

/// A [TransferQueue] kept in memory.
final class InMemoryTransferQueue implements TransferQueue {
  final List<TransferOrder> orders = [];
  final StreamController<List<QueuedTransfer>> _changes =
      StreamController.broadcast();

  @override
  void enqueue(TransferOrder order) {
    orders.add(order);
    _changes.add([
      for (final queued in orders)
        QueuedTransfer(id: queued.id, amountCents: queued.amountCents),
    ]);
  }

  @override
  Stream<List<QueuedTransfer>> watchQueued() => _changes.stream;
}
