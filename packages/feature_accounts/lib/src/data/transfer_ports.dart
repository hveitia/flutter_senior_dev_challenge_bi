import 'package:feature_accounts/src/domain/transfer.dart';

/// What the server answered about one transfer.
sealed class ApiTransferAnswer {
  const ApiTransferAnswer();
}

final class ApiTransferCompleted extends ApiTransferAnswer {
  const ApiTransferCompleted(this.reference);

  final String reference;
}

final class ApiTransferRejected extends ApiTransferAnswer {
  const ApiTransferRejected(this.reason);

  final TransferRejection reason;
}

/// The server does not have an order with that id (yet).
final class ApiTransferNotFound extends ApiTransferAnswer {
  const ApiTransferNotFound();
}

/// The customer API. Failures to reach it are thrown as `AppFailure`s; an
/// answer the client cannot act on is thrown as [ApiContractError].
abstract interface class TransfersApi {
  /// Creates and settles [order] in one call.
  Future<ApiTransferAnswer> submit(TransferOrder order);

  /// Settles the order the device left pending under [transferId].
  Future<ApiTransferAnswer> process(String transferId);

  Future<void> provisionAccounts();
}

/// The server refused the request for a reason the customer cannot fix:
/// a session it does not accept, a body it cannot read, an id used for a
/// different order. Carries the server's stable code and nothing else.
final class ApiContractError implements Exception {
  const ApiContractError(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'ApiContractError($status, $code)';
}

/// Orders kept on the device until the server can be asked.
abstract interface class TransferQueue {
  /// Leaves [order] pending. It returns at once: the device's own write
  /// queue carries it to the server when there is a connection.
  void enqueue(TransferOrder order);

  /// The orders the server has not settled, as far as the device knows.
  Stream<List<QueuedTransfer>> watchQueued();

  /// The id of each order the bank did not take into the queue: it left
  /// the device and was turned away, so it is no longer waiting anywhere.
  Stream<String> get refused;
}
