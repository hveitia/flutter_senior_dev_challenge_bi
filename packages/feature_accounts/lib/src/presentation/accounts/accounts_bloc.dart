import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/accounts_telemetry.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';

sealed class AccountsEvent {
  const AccountsEvent();
}

/// Start following the customer's accounts.
final class AccountsStarted extends AccountsEvent {
  const AccountsStarted();
}

/// Ask the backend again. [isRetry] marks a request made from an error, so
/// it is counted as a retry.
final class AccountsRefreshRequested extends AccountsEvent {
  const AccountsRefreshRequested({this.isRetry = false});

  final bool isRetry;
}

final class _AccountsDelivered extends AccountsEvent {
  const _AccountsDelivered(this.snapshot);

  final DataSnapshot<List<Account>> snapshot;
}

final class _AccountsListenerFailed extends AccountsEvent {
  const _AccountsListenerFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

final class AccountsState extends Equatable {
  const AccountsState({this.accounts = const LoadState()});

  final LoadState<List<Account>> accounts;

  /// What is available across every account, in cents.
  int get totalCents => totalAvailableCents(accounts.data ?? const []);

  /// The account with [id], or null when it is not among the customer's.
  Account? byId(String id) {
    for (final account in accounts.data ?? const <Account>[]) {
      if (account.id == id) return account;
    }
    return null;
  }

  @override
  List<Object?> get props => [accounts];
}

/// The customer's accounts, shared by every screen that shows them.
///
/// It listens for as long as it lives, so a balance changed by the server
/// shows up without the customer asking, and it refreshes through the
/// resilience policy when opened or asked to.
///
/// Deliveries from the listener are handled while a refresh is still in
/// flight: that is what puts saved data on screen before a slow backend
/// answers.
final class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  AccountsBloc({
    required AccountsRepository repository,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _repository = repository,
       _telemetry = telemetry,
       super(const AccountsState()) {
    on<AccountsStarted>(_onStarted);
    on<AccountsRefreshRequested>(_onRefreshRequested);
    on<_AccountsDelivered>(_onDelivered);
    on<_AccountsListenerFailed>(_onListenerFailed);
  }

  final AccountsRepository _repository;
  final Telemetry _telemetry;

  StreamSubscription<DataSnapshot<List<Account>>>? _subscription;
  bool _listenerBroke = false;
  FirstLoadTrace? _firstLoad;

  Future<void> _onStarted(
    AccountsStarted event,
    Emitter<AccountsState> emit,
  ) async {
    if (_subscription != null) return;

    _firstLoad = FirstLoadTrace(
      _telemetry,
      AccountsTelemetry.accountsFirstLoad,
    );
    _listen();
    await _refresh(emit);
  }

  void _listen() {
    _listenerBroke = false;
    _subscription = _repository.watchAccounts().listen(
      (snapshot) => add(_AccountsDelivered(snapshot)),
      onError: (Object error, StackTrace stackTrace) =>
          add(_AccountsListenerFailed(error, stackTrace)),
    );
  }

  /// A listener that reported an error delivers nothing more. Asking the
  /// backend once would bring the data up to date and then leave it frozen,
  /// so the accounts are followed again before asking.
  void _listenAgainIfBroken() {
    if (!_listenerBroke) return;
    unawaited(_subscription?.cancel());
    _listen();
  }

  Future<void> _onRefreshRequested(
    AccountsRefreshRequested event,
    Emitter<AccountsState> emit,
  ) async {
    if (state.accounts.isLoading) return;

    if (event.isRetry) {
      _telemetry.event(
        AccountsTelemetry.retryRequested,
        parameters: {
          AccountsTelemetry.serviceKey: AccountsTelemetry.accountsService,
        },
      );
    }
    _listenAgainIfBroken();
    await _refresh(emit);
  }

  Future<void> _refresh(Emitter<AccountsState> emit) async {
    emit(AccountsState(accounts: state.accounts.startLoading()));

    final result = await _repository.refreshAccounts();
    if (isClosed) return;

    final accounts = state.accounts.withRefresh(result);
    _traceOutcome(accounts);
    emit(AccountsState(accounts: accounts));
  }

  void _onDelivered(_AccountsDelivered event, Emitter<AccountsState> emit) {
    final accounts = state.accounts.withSnapshot(event.snapshot);
    _traceOutcome(accounts);
    emit(AccountsState(accounts: accounts));
  }

  /// A broken listener means no more live updates until the customer asks
  /// again. It is shown like any other failure; what was already on screen
  /// stays there.
  void _onListenerFailed(
    _AccountsListenerFailed event,
    Emitter<AccountsState> emit,
  ) {
    _listenerBroke = true;
    _telemetry
      ..event(
        AccountsTelemetry.loadFailed,
        parameters: {
          AccountsTelemetry.serviceKey: AccountsTelemetry.accountsService,
          AccountsTelemetry.reasonKey: LoadFailure.unexpected.name,
        },
      )
      ..recordError(
        RedactedError(event.error.runtimeType),
        event.stackTrace,
        reason: AccountsTelemetry.unexpectedError,
      );
    final accounts = state.accounts.withRefresh(
      Failed(UnexpectedFailure(event.error, event.stackTrace)),
    );
    _traceOutcome(accounts);
    emit(AccountsState(accounts: accounts));
  }

  void _traceOutcome(LoadState<List<Account>> accounts) {
    if (accounts.data case final data?) {
      _firstLoad?.dataShown(
        origin: accounts.origin?.name ?? '',
        count: data.length,
      );
    } else if (accounts.hasFailed) {
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
