import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/domain/transfer.dart';
import 'package:feature_accounts/src/domain/transfers_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class TransferOutboxState extends Equatable {
  const TransferOutboxState({this.queued = const [], this.lastRejection});

  /// The orders on this device the server has not settled.
  final List<QueuedTransfer> queued;

  /// The reason the server refused a queued order, until the customer
  /// dismisses it. A completed one needs no notice: its movement shows.
  final TransferRejection? lastRejection;

  bool get hasUnsent => queued.isNotEmpty;

  @override
  List<Object?> get props => [queued, lastRejection];
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
  late final StreamSubscription<bool> _onlineSubscription;
  bool _draining = false;
  bool _retryScheduled = false;

  void _onQueue(List<QueuedTransfer> queued) {
    emit(
      TransferOutboxState(queued: queued, lastRejection: state.lastRejection),
    );
    if (queued.isNotEmpty) unawaited(_drain());
  }

  void rejectionDismissed() {
    emit(TransferOutboxState(queued: state.queued));
  }

  /// Settles every queued order, one after another. A second call while
  /// one is running does nothing.
  Future<void> _drain() async {
    if (_draining || isClosed) return;
    _draining = true;
    var pendingRemain = false;
    try {
      if (!await _isOnline()) return;
      for (final order in List.of(state.queued)) {
        if (isClosed) return;
        final outcome = await _repository.settle(order.id);
        if (isClosed) return;
        switch (outcome) {
          case TransferRejected(:final reason):
            emit(
              TransferOutboxState(queued: state.queued, lastRejection: reason),
            );
          case TransferCompleted():
            break;
          case null || TransferNotSent() || TransferQueued():
            pendingRemain = true;
        }
      }
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
      _onlineSubscription.cancel(),
    ]);
    return super.close();
  }
}
