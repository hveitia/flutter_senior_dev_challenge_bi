import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/accounts_telemetry.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/domain/movement.dart';
import 'package:feature_accounts/src/presentation/listener_failure.dart';

sealed class RecentMovementsEvent {
  const RecentMovementsEvent();
}

/// Start following the latest movements.
final class RecentMovementsStarted extends RecentMovementsEvent {
  const RecentMovementsStarted();
}

/// Ask the backend again. [isRetry] marks a request made from an error.
final class RecentMovementsRefreshRequested extends RecentMovementsEvent {
  const RecentMovementsRefreshRequested({this.isRetry = false});

  final bool isRetry;
}

final class _RecentMovementsDelivered extends RecentMovementsEvent {
  const _RecentMovementsDelivered(this.snapshot);

  final DataSnapshot<List<Movement>> snapshot;
}

final class _RecentMovementsListenerFailed extends RecentMovementsEvent {
  const _RecentMovementsListenerFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

final class RecentMovementsState extends Equatable {
  const RecentMovementsState({this.movements = const LoadState()});

  final LoadState<List<Movement>> movements;

  @override
  List<Object?> get props => [movements];
}

/// The latest movements across the customer's accounts, as the home shows
/// them. It has its own state, apart from the accounts: when the movements
/// service fails, only this part of the home says so.
final class RecentMovementsBloc
    extends Bloc<RecentMovementsEvent, RecentMovementsState> {
  RecentMovementsBloc({
    required AccountsRepository repository,
    required this.limit,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _repository = repository,
       _telemetry = telemetry,
       super(const RecentMovementsState()) {
    on<RecentMovementsStarted>(_onStarted);
    on<RecentMovementsRefreshRequested>(_onRefreshRequested);
    on<_RecentMovementsDelivered>(_onDelivered);
    on<_RecentMovementsListenerFailed>(_onListenerFailed);
  }

  /// How many movements are followed.
  final int limit;

  final AccountsRepository _repository;
  final Telemetry _telemetry;

  StreamSubscription<DataSnapshot<List<Movement>>>? _subscription;
  bool _listenerBroke = false;

  Future<void> _onStarted(
    RecentMovementsStarted event,
    Emitter<RecentMovementsState> emit,
  ) async {
    if (_subscription != null) return;

    _listen();
    await _refresh(emit);
  }

  void _listen() {
    _listenerBroke = false;
    _subscription = _repository
        .watchRecentMovements(limit: limit)
        .listen(
          (snapshot) => add(_RecentMovementsDelivered(snapshot)),
          onError: (Object error, StackTrace stackTrace) =>
              add(_RecentMovementsListenerFailed(error, stackTrace)),
        );
  }

  Future<void> _onRefreshRequested(
    RecentMovementsRefreshRequested event,
    Emitter<RecentMovementsState> emit,
  ) async {
    if (state.movements.isLoading) return;

    if (event.isRetry) {
      _telemetry.event(
        AccountsTelemetry.retryRequested,
        parameters: {
          AccountsTelemetry.serviceKey: AccountsTelemetry.movementsService,
        },
      );
    }
    // A listener that reported an error delivers nothing more, so the
    // movements are followed again before asking the backend.
    if (_listenerBroke) {
      unawaited(_subscription?.cancel());
      _listen();
    }
    await _refresh(emit);
  }

  Future<void> _refresh(Emitter<RecentMovementsState> emit) async {
    emit(RecentMovementsState(movements: state.movements.startLoading()));

    final result = await _repository.refreshRecentMovements(limit: limit);
    if (isClosed) return;

    emit(RecentMovementsState(movements: state.movements.withRefresh(result)));
  }

  void _onDelivered(
    _RecentMovementsDelivered event,
    Emitter<RecentMovementsState> emit,
  ) {
    emit(
      RecentMovementsState(
        movements: state.movements.withSnapshot(event.snapshot),
      ),
    );
  }

  /// No more live updates until the customer asks again. What was already
  /// on screen stays there.
  void _onListenerFailed(
    _RecentMovementsListenerFailed event,
    Emitter<RecentMovementsState> emit,
  ) {
    _listenerBroke = true;
    final failure = reportListenerFailure(
      _telemetry,
      service: AccountsTelemetry.movementsService,
      error: event.error,
      stackTrace: event.stackTrace,
    );
    emit(
      RecentMovementsState(
        movements: state.movements.withRefresh(Failed(failure)),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
