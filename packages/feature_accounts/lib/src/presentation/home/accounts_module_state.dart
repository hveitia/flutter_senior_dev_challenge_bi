import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/widgets/load_failure_view.dart';
import 'package:module_kit/module_kit.dart';

/// The accounts a home module can put on screen. An empty list that only
/// the saved copy vouches for is not shown: the copy may simply have been
/// emptied, and it would read as a customer without accounts.
List<Account>? showableAccounts(LoadState<List<Account>> accounts) {
  final data = accounts.data;
  if (data == null) return null;
  if (data.isEmpty && accounts.origin != DataOrigin.server) return null;
  return data;
}

/// What a module that shows the accounts reports to the home.
HomeModuleStatus accountsModuleStatus(LoadState<List<Account>> accounts) {
  if (showableAccounts(accounts) != null) return HomeModuleStatus.ready;
  return accounts.failure == null
      ? HomeModuleStatus.waiting
      : HomeModuleStatus.failed;
}

/// Asks [bloc] for the accounts again and completes when it has answered.
Future<void> refreshAccounts(AccountsBloc bloc, {bool isRetry = false}) {
  bloc.add(AccountsRefreshRequested(isRetry: isRetry));
  return untilLoaded(bloc.stream, (state) => state.accounts.isLoading);
}
