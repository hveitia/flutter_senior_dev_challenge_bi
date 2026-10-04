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

/// What a module reports to the home about the data set it shows: ready
/// while it [hasContent] on screen, fresh or saved; otherwise waiting, or
/// failed once loading has failed.
HomeModuleStatus moduleStatus(
  LoadState<Object?> state, {
  required bool hasContent,
}) {
  if (hasContent) return HomeModuleStatus.ready;
  return state.failure == null
      ? HomeModuleStatus.waiting
      : HomeModuleStatus.failed;
}

/// What a module that shows the accounts reports to the home.
HomeModuleStatus accountsModuleStatus(LoadState<List<Account>> accounts) =>
    moduleStatus(accounts, hasContent: showableAccounts(accounts) != null);

/// The type of the module that says when the accounts cannot be loaded.
/// It lives here, and not with the registration, so the modules that defer
/// to it do not import the file that imports them.
const String totalBalanceType = 'totalBalance';

/// Whether the balance module is published in the same home as [module].
/// When it is, it is the one that says the accounts failed and offers the
/// retry, and the other modules on the same data draw nothing: two errors
/// about the same thing would only add noise. Published without it, each
/// says the failure itself.
bool balanceSaysAccountsFailure(HomeModuleContext module) =>
    module.composedTypes.contains(totalBalanceType);

/// Asks [bloc] for the accounts again and completes when it has answered.
Future<void> refreshAccounts(AccountsBloc bloc, {bool isRetry = false}) {
  bloc.add(AccountsRefreshRequested(isRetry: isRetry));
  return untilLoaded(bloc.stream, (state) => state.accounts.isLoading);
}
