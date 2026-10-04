import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/domain/transfer.dart';
import 'package:feature_accounts/src/domain/transfers_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class TransferOutboxState extends Equatable {
  const TransferOutboxState({
    this.queued = const [],
    this.lastRejection,
    this.hasRefused = false,
  });

  /// The orders on this device the server has not settled.
  final List<QueuedTransfer> queued;

  /// The reason the server refused a queued order, until the customer
  /// dismisses it. A completed one needs no notice: its movement shows.
  final TransferRejection? lastRejection;

  /// A queued order left the queue without being carried out and without a
  /// reason the customer can read: the bank turned it away. Kept until the
  /// customer dismisses it.
  final bool hasRefused;

  bool get hasUnsent => queued.isNotEmpty;

  /// Orders the bank already has: they will be carried out even if the
  /// session ends on this device.
  int get deliveredCount => queued.where((order) => order.isDelivered).length;

  /// Orders that exist only on this device: ending the session loses them.
  int get onDeviceOnlyCount => queued.length - deliveredCount;

  TransferOutboxState _with({
    List<QueuedTransfer>? queued,
    TransferRejection? lastRejection,
    bool? hasRefused,
  }) => TransferOutboxState(
    queued: queued ?? this.queued,
    lastRejection: lastRejection ?? this.lastRejection,
    hasRefused: hasRefused ?? this.hasRefused,
  );

  @override
  List<Object?> get props => [queued, lastRejection, hasRefused];
}

/// Sends the orders that were queued without a connection.
///
/// It runs for as long as the customer is signed in. Orders are settled one
/// at a time, in the order the device reports them, when the queue changes,
/// when the connection returns and when the app starts. Settling is
/// idempotent on the server, so asking twice for the same order is harmless.
final class TransferOutboxCubit extends Cubit<TransferOutboxState> {
  TransferOutboxCubit({
    required TransfersRepository repository,
    required Stream<bool> onlineChanges,
    required Future<bool> Function() isOnline,
    Delay delay = Future<void>.delayed,
    this.retryAfter = defaultRetryAfter,
  }) : _repository = repository,
       _isOnline = isOnline,
       _delay = delay,
       super(const TransferOutboxState()) {
    _queueSubscription = repository.watchQueued().listen(
      _onQueue,
      // The queue is read from the device; an error leaves it as it was.
      onError: (Object _) {},
    );
    _refusedSubscription = repository.watchRefused().listen(
      (id) => unawaited(_onRefused(id)),
      onError: (Object _) {},
    );
    _onlineSubscription = onlineChanges.listen((online) {
      if (online) unawaited(_drain());
    });
  }

  /// How long to wait before asking again for orders the server did not
  /// have yet or could not settle.
  static const Duration defaultRetryAfter = Duration(seconds: 5);

  final TransfersRepository _repository;
  final Future<bool> Function() _isOnline;
  final Delay _delay;
  final Duration retryAfter;

  late final StreamSubscription<List<QueuedTransfer>> _queueSubscription;
  late final StreamSubscription<String> _refusedSubscription;
  late final StreamSubscription<bool> _onlineSubscription;
  bool _draining = false;

  /// Something changed while a drain was running: run once more after it.
  bool _dirty = false;
  bool _retryScheduled = false;

  /// Orders with a final answer in this session. The device may still list
  /// one for a moment; it is not asked about again.
  final Set<String> _finished = {};

  void _onQueue(List<QueuedTransfer> queued) {
    if (isClosed) return;
    emit(state._with(queued: queued));
    if (queued.isNotEmpty) unawaited(_drain());
  }

  /// The bank turned a queued order away. Firestore drops it from the
  /// device, so it would leave the queue unexplained. Asking the server
  /// tells which case it is: already carried out, refused with a reason,
  /// or never accepted at all.
  Future<void> _onRefused(String transferId) async {
    if (isClosed) return;
    final outcome = await _repository.settle(transferId);
    if (isClosed) return;
    _finished.add(transferId);
    switch (outcome) {
      case TransferCompleted():
        break;
      case TransferRejected(:final reason):
        emit(state._with(lastRejection: reason));
      case null || TransferNotSent() || TransferQueued() || TransferStopped():
        emit(state._with(hasRefused: true));
    }
  }

  /// The customer read the notices about queued orders.
  void rejectionDismissed() {
    emit(TransferOutboxState(queued: state.queued));
  }

  /// Settles every queued order, one after another. A call while one is
  /// running does not start a second: it asks the running one to go round
  /// again, so an order queued meanwhile is not left behind.
  Future<void> _drain() async {
    if (isClosed) return;
    if (_draining) {
      _dirty = true;
      return;
    }
    _draining = true;
    var pendingRemain = false;
    try {
      do {
        _dirty = false;
        pendingRemain = false;
        if (!await _isOnline()) break;
        for (final order in List.of(state.queued)) {
          if (isClosed) return;
          if (_finished.contains(order.id)) continue;
          final outcome = await _repository.settle(order.id);
          if (isClosed) return;
          switch (outcome) {
            case TransferRejected(:final reason):
              _finished.add(order.id);
              emit(state._with(lastRejection: reason));
            case TransferCompleted():
              _finished.add(order.id);
            case TransferStopped(reason: TransferStop.sessionExpired):
              // The session may be renewed; the order is still good.
              pendingRemain = true;
            case TransferStopped():
              // The server will never accept this request: asking again
              // would only repeat the answer.
              _finished.add(order.id);
              emit(state._with(hasRefused: true));
            case null || TransferNotSent() || TransferQueued():
              pendingRemain = true;
          }
        }
      } while (_dirty && !isClosed);
    } finally {
      _draining = false;
    }
    if (pendingRemain) unawaited(_retryLater());
  }

  Future<void> _retryLater() async {
    if (_retryScheduled || isClosed) return;
    _retryScheduled = true;
    await _delay(retryAfter);
    _retryScheduled = false;
    if (!isClosed && state.hasUnsent) unawaited(_drain());
  }

  @override
  Future<void> close() async {
    await Future.wait([
      _queueSubscription.cancel(),
      _refusedSubscription.cancel(),
      _onlineSubscription.cancel(),
    ]);
    return super.close();
  }
}
