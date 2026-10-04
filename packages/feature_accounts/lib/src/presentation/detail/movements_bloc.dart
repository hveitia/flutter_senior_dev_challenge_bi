import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/accounts_telemetry.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/domain/movement.dart';
import 'package:feature_accounts/src/domain/movement_filter.dart';

sealed class MovementsEvent {
  const MovementsEvent();
}

/// Start following the movements of the account.
final class MovementsStarted extends MovementsEvent {
  const MovementsStarted();
}

/// Ask the backend again. [isRetry] marks a request made from an error.
final class MovementsRefreshRequested extends MovementsEvent {
  const MovementsRefreshRequested({this.isRetry = false});

  final bool isRetry;
}

final class MovementsFilterChanged extends MovementsEvent {
  const MovementsFilterChanged(this.filter);

  final MovementFilter filter;
}

final class MovementsSearchChanged extends MovementsEvent {
  const MovementsSearchChanged(this.query);

  final String query;
}

/// Bring one more page of older movements.
final class MovementsMoreRequested extends MovementsEvent {
  const MovementsMoreRequested();
}

final class _MovementsDelivered extends MovementsEvent {
  const _MovementsDelivered(this.snapshot, {required this.limit});

  final DataSnapshot<List<Movement>> snapshot;

  /// The page size of the listener that delivered it.
  final int limit;
}

final class _MovementsListenerFailed extends MovementsEvent {
  const _MovementsListenerFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

final class MovementsState extends Equatable {
  const MovementsState({
    required this.limit,
    this.movements = const LoadState(),
    this.filter = MovementFilter.all,
    this.query = '',
    this.visible = const [],
    this.isLoadingMore = false,
  });

  /// Everything loaded so far, newest first.
  final LoadState<List<Movement>> movements;
  final MovementFilter filter;
  final String query;

  /// How many movements are being followed.
  final int limit;

  /// The loaded movements that pass [filter] and [query].
  final List<Movement> visible;
  final bool isLoadingMore;

  /// Whether there may be older movements than the ones loaded.
  bool get hasMore => (movements.data?.length ?? 0) >= limit;

  /// Whether the customer narrowed the list.
  bool get isNarrowed =>
      filter != MovementFilter.all || query.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    movements,
    filter,
    query,
    limit,
    visible,
    isLoadingMore,
  ];
}

/// The movements of one account: a page that grows on demand, with the
/// filter and the search the customer chose.
///
/// It is separate from the accounts on purpose: movements can fail or be
/// slow while the balance stays on screen.
///
/// The filter and the search work on the movements already loaded. Bringing
/// more pages widens what they look through.
final class MovementsBloc extends Bloc<MovementsEvent, MovementsState> {
  MovementsBloc({
    required AccountsRepository repository,
    required this.accountId,
    Telemetry telemetry = const NoopTelemetry(),
    DateTime Function() now = DateTime.now,
    this.pageSize = defaultPageSize,
  }) : _repository = repository,
       _telemetry = telemetry,
       _now = now,
       super(MovementsState(limit: pageSize)) {
    on<MovementsStarted>(_onStarted);
    on<MovementsRefreshRequested>(_onRefreshRequested);
    on<MovementsFilterChanged>(
      (event, emit) => emit(_with(filter: event.filter)),
    );
    on<MovementsSearchChanged>(
      (event, emit) => emit(_with(query: event.query)),
    );
    on<MovementsMoreRequested>(_onMoreRequested);
    on<_MovementsDelivered>(_onDelivered);
    on<_MovementsListenerFailed>(_onListenerFailed);
  }

  /// Movements brought at a time.
  static const int defaultPageSize = 20;

  final String accountId;
  final int pageSize;

  final AccountsRepository _repository;
  final Telemetry _telemetry;
  final DateTime Function() _now;

  StreamSubscription<DataSnapshot<List<Movement>>>? _subscription;
  bool _listenerBroke = false;
  FirstLoadTrace? _firstLoad;

  Future<void> _onStarted(
    MovementsStarted event,
    Emitter<MovementsState> emit,
  ) async {
    if (_subscription != null) return;

    _firstLoad = FirstLoadTrace(
      _telemetry,
      AccountsTelemetry.movementsFirstLoad,
    );
    _listen(state.limit);
    await _refresh(emit);
  }

  Future<void> _onRefreshRequested(
    MovementsRefreshRequested event,
    Emitter<MovementsState> emit,
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
    // A listener that reported an error delivers nothing more: the account
    // is followed again, or the list would be brought up to date once and
    // then stay frozen.
    if (_listenerBroke) {
      unawaited(_subscription?.cancel());
      _listen(state.limit);
    }
    await _refresh(emit);
  }

  Future<void> _refresh(Emitter<MovementsState> emit) async {
    emit(_with(movements: state.movements.startLoading()));

    final limit = state.limit;
    final result = await _repository.refreshMovements(accountId, limit: limit);
    if (isClosed) return;

    // The customer may have asked for more while the backend was answering.
    // The answer is then for a shorter page and would cut the list.
    final movements = limit == state.limit
        ? state.movements.withRefresh(result)
        : state.movements.withOutdatedRefresh(result);
    _traceOutcome(movements);
    emit(_with(movements: movements));
  }

  void _onMoreRequested(
    MovementsMoreRequested event,
    Emitter<MovementsState> emit,
  ) {
    if (!state.hasMore || state.isLoadingMore) return;

    final limit = state.limit + pageSize;
    emit(_with(limit: limit, isLoadingMore: true));
    // The listener of the shorter page is dropped without waiting for it:
    // whatever it still delivers is ignored by its page size.
    unawaited(_subscription?.cancel());
    _listen(limit);
  }

  void _onDelivered(_MovementsDelivered event, Emitter<MovementsState> emit) {
    // A delivery queued by the listener of a shorter page would shrink the
    // list the customer just asked to extend.
    if (event.limit != state.limit) return;

    final movements = state.movements.withSnapshot(event.snapshot);
    _traceOutcome(movements);
    emit(_with(movements: movements, isLoadingMore: false));
  }

  void _onListenerFailed(
    _MovementsListenerFailed event,
    Emitter<MovementsState> emit,
  ) {
    _listenerBroke = true;
    _telemetry
      ..event(
        AccountsTelemetry.loadFailed,
        parameters: {
          AccountsTelemetry.serviceKey: AccountsTelemetry.movementsService,
          AccountsTelemetry.reasonKey: LoadFailure.unexpected.name,
        },
      )
      ..recordError(
        RedactedError(event.error.runtimeType),
        event.stackTrace,
        reason: AccountsTelemetry.unexpectedError,
      );
    final movements = state.movements.withRefresh(
      Failed(UnexpectedFailure(event.error, event.stackTrace)),
    );
    _traceOutcome(movements);
    emit(_with(movements: movements, isLoadingMore: false));
  }

  void _listen(int limit) {
    _listenerBroke = false;
    _subscription = _repository
        .watchMovements(accountId, limit: limit)
        .listen(
          (snapshot) => add(_MovementsDelivered(snapshot, limit: limit)),
          onError: (Object error, StackTrace stackTrace) =>
              add(_MovementsListenerFailed(error, stackTrace)),
        );
  }

  /// The state with the given changes and the visible list recomputed, so
  /// the two can never disagree.
  MovementsState _with({
    LoadState<List<Movement>>? movements,
    MovementFilter? filter,
    String? query,
    int? limit,
    bool? isLoadingMore,
  }) {
    final loaded = movements ?? state.movements;
    final chosenFilter = filter ?? state.filter;
    final chosenQuery = query ?? state.query;

    return MovementsState(
      movements: loaded,
      filter: chosenFilter,
      query: chosenQuery,
      limit: limit ?? state.limit,
      isLoadingMore: isLoadingMore ?? state.isLoadingMore,
      visible: filterMovements(
        loaded.data ?? const [],
        filter: chosenFilter,
        query: chosenQuery,
        now: _now(),
      ),
    );
  }

  void _traceOutcome(LoadState<List<Movement>> movements) {
    if (movements.data case final data?) {
      _firstLoad?.dataShown(
        origin: movements.origin?.name ?? '',
        count: data.length,
      );
    } else if (movements.hasFailed) {
      _firstLoad?.failed();
    }
  }

  @override
  Future<void> close() async {
    _firstLoad?.end();
    await _subscription?.cancel();
    return super.close();
  }
}
