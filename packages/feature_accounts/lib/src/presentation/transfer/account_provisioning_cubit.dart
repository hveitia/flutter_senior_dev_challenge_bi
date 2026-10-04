import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/transfers_repository.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ProvisioningStatus { idle, running, failed }

/// Asks the server to open a new customer's first accounts.
///
/// It follows the accounts: the first time the backend confirms the
/// customer has none, it asks once. The accounts then arrive through the
/// same listener every screen already follows. If asking fails, the
/// customer can ask again.
final class AccountProvisioningCubit extends Cubit<ProvisioningStatus> {
  AccountProvisioningCubit({
    required TransfersRepository repository,
    required Stream<AccountsState> accounts,
    AccountsState? initial,
  }) : _repository = repository,
       super(ProvisioningStatus.idle) {
    _subscription = accounts.listen(_onAccounts);
    if (initial != null) _onAccounts(initial);
  }

  final TransfersRepository _repository;
  late final StreamSubscription<AccountsState> _subscription;
  bool _asked = false;

  void _onAccounts(AccountsState state) {
    final accounts = state.accounts;
    // Only what the backend confirmed: an empty copy saved on the device
    // says nothing about whether the customer has accounts.
    final confirmedEmpty =
        accounts.origin == DataOrigin.server &&
        !accounts.isLoading &&
        (accounts.data?.isEmpty ?? false);
    if (confirmedEmpty && !_asked) unawaited(_provision());
  }

  Future<void> retryRequested() async {
    if (state != ProvisioningStatus.failed) return;
    await _provision();
  }

  Future<void> _provision() async {
    _asked = true;
    emit(ProvisioningStatus.running);
    final result = await _repository.provisionAccounts();
    if (isClosed) return;
    emit(
      result is Success<void>
          ? ProvisioningStatus.idle
          : ProvisioningStatus.failed,
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
