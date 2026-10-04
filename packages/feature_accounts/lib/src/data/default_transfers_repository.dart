import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/data/transfer_ports.dart';
import 'package:feature_accounts/src/domain/transfer.dart';
import 'package:feature_accounts/src/domain/transfers_repository.dart';
import 'package:feature_accounts/src/transfers_telemetry.dart';

/// Sends transfers through the customer API, with the resilience policy in
/// front of it, and keeps an order on the device when there is no
/// connection.
///
/// Every call is declared idempotent to the policy: the order id is the
/// server's idempotency key, so an attempt repeated after a timeout settles
/// the same order, never a second one.
final class DefaultTransfersRepository implements TransfersRepository {
  DefaultTransfersRepository({
    required TransfersApi api,
    required TransferQueue queue,
    required ResiliencePolicy policy,
    required Telemetry telemetry,
    required Future<bool> Function() isOnline,
  }) : _api = api,
       _queue = queue,
       _policy = policy,
       _telemetry = telemetry,
       _isOnline = isOnline;

  final TransfersApi _api;
  final TransferQueue _queue;
  final ResiliencePolicy _policy;
  final Telemetry _telemetry;
  final Future<bool> Function() _isOnline;

  static const int _notFoundStatus = 404;
  static const String _notFoundCode = 'transfer-not-found';

  @override
  Future<TransferOutcome> send(TransferOrder order) async {
    // Known to be offline: nothing was sent, so the order can wait on the
    // device without any doubt about what the server did with it.
    if (!await _isOnline()) return _enqueue(order);

    final answer = await _settling(() => _api.submit(order));
    switch (answer) {
      case Success(value: final ApiTransferCompleted completed):
        return _completed(completed);
      case Success(value: ApiTransferRejected(:final reason)):
        return _rejected(reason);
      case Success(value: ApiTransferNotFound()):
        // The online route creates the order; it cannot be missing.
        return _notSent(
          UnexpectedFailure(
            const ApiContractError(_notFoundStatus, _notFoundCode),
            StackTrace.current,
          ),
        );
      case Failed(failure: OfflineFailure()):
        // The policy found no connection before trying: nothing was sent.
        return _enqueue(order);
      case Failed(:final failure):
        // A timeout or an error after the request left: the server may or
        // may not have settled it. The customer repeats the same order,
        // which is safe; queueing a copy would hide that doubt.
        return _notSent(failure);
    }
  }

  @override
  Future<TransferOutcome?> settle(String transferId) async {
    final answer = await _settling(() => _api.process(transferId));
    final TransferOutcome outcome;
    switch (answer) {
      case Success(value: ApiTransferNotFound()):
        // The device has not delivered the order yet; it stays queued.
        return null;
      case Success(value: ApiTransferCompleted(:final reference)):
        outcome = TransferCompleted(reference: reference);
      case Success(value: ApiTransferRejected(:final reason)):
        outcome = TransferRejected(reason);
      case Failed(:final failure):
        return TransferNotSent(failure);
    }
    _telemetry.event(
      TransfersTelemetry.queuedSettled,
      parameters: {
        TransfersTelemetry.outcomeKey: outcome is TransferCompleted
            ? TransfersTelemetry.completedOutcome
            : TransfersTelemetry.rejectedOutcome,
        if (outcome case TransferRejected(:final reason))
          TransfersTelemetry.reasonKey: reason.code,
      },
    );
    return outcome;
  }

  @override
  Stream<List<QueuedTransfer>> watchQueued() => _queue.watchQueued();

  @override
  Future<Result<void>> provisionAccounts() async {
    final result = await _policy.run(
      _translating(_api.provisionAccounts),
      // The server opens the accounts once however often it is asked.
      idempotent: true,
      serviceId: TransfersTelemetry.service,
    );
    switch (result) {
      case Success():
        _telemetry.event(TransfersTelemetry.provisioned);
      case Failed(:final failure):
        _telemetry.event(
          TransfersTelemetry.provisionFailed,
          parameters: {
            TransfersTelemetry.reasonKey: TransfersTelemetry.failureKind(
              failure,
            ),
          },
        );
    }
    return result;
  }

  Future<Result<ApiTransferAnswer>> _settling(
    Future<ApiTransferAnswer> Function() call,
  ) async {
    final trace = _telemetry.startTrace(TransfersTelemetry.settleTrace);
    try {
      return await _policy.run(
        _translating(call),
        idempotent: true,
        serviceId: TransfersTelemetry.service,
      );
    } finally {
      trace.stop();
    }
  }

  /// An answer the app cannot act on is not retried: it would be the same
  /// answer. It is reported by its code and reaches the caller as an
  /// unexpected failure.
  Future<T> Function() _translating<T>(Future<T> Function() call) => () async {
    try {
      return await call();
    } on ApiContractError catch (error, stackTrace) {
      _telemetry.recordError(
        RedactedError(error.runtimeType),
        stackTrace,
        reason: '${TransfersTelemetry.contractError}:${error.code}',
      );
      throw UnexpectedFailure(error, stackTrace);
    }
  };

  TransferOutcome _enqueue(TransferOrder order) {
    _queue.enqueue(order);
    _telemetry.event(TransfersTelemetry.queued);
    return const TransferQueued();
  }

  TransferOutcome _completed(ApiTransferCompleted completed) {
    _telemetry.event(TransfersTelemetry.completed);
    return TransferCompleted(reference: completed.reference);
  }

  TransferOutcome _rejected(TransferRejection reason) {
    _telemetry.event(
      TransfersTelemetry.rejected,
      parameters: {TransfersTelemetry.reasonKey: reason.code},
    );
    return TransferRejected(reason);
  }

  TransferOutcome _notSent(AppFailure failure) {
    _telemetry.event(
      TransfersTelemetry.notSent,
      parameters: {
        TransfersTelemetry.reasonKey: TransfersTelemetry.failureKind(failure),
      },
    );
    return TransferNotSent(failure);
  }
}
