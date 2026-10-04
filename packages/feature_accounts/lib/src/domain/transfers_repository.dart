import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/domain/transfer.dart';

/// Moving money between the customer's own accounts, and opening their
/// first accounts. The server does both; this only asks, and keeps an order
/// on the device when there is no connection to ask with.
abstract interface class TransfersRepository {
  /// Sends [order]. With a connection the server settles it now; without
  /// one it is queued on the device. Safe to call again with the same order.
  Future<TransferOutcome> send(TransferOrder order);

  /// Asks the server to settle the queued order [transferId]. Null means
  /// the server has not received the order yet and it stays queued.
  Future<TransferOutcome?> settle(String transferId);

  /// The orders left on this device that the server has not settled.
  Stream<List<QueuedTransfer>> watchQueued();

  /// The id of each queued order the bank turned away instead of queueing.
  Stream<String> watchRefused();

  /// The order whose request left this device without a final answer. Its
  /// outcome is unknown, so the only safe next step is to send that same
  /// order again. Null when there is none.
  TransferOrder? get unresolved;

  /// Opens the customer's first accounts. Asking again changes nothing.
  Future<Result<void>> provisionAccounts();
}
