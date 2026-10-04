import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_screen.dart';
import 'package:feature_accounts/src/presentation/detail/account_detail_screen.dart';
import 'package:feature_accounts/src/presentation/detail/movements_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Locations owned by the accounts feature.
abstract final class AccountsPaths {
  /// The list of accounts, a section of the bottom navigation.
  static const String accounts = '/cuentas';

  static const String _accountId = 'accountId';
  static const String _account = '$accounts/:$_accountId';

  /// The detail of one account.
  static String account(String accountId) =>
      '$accounts/${Uri.encodeComponent(accountId)}';
}

/// The list of accounts. The app mounts it inside its navigation shell.
///
/// It reads `AccountsBloc` and `ConnectivityCubit` from the widget tree.
/// [now] is the clock used to say how old saved data is.
GoRoute accountsTabRoute({DateTime Function() now = DateTime.now}) => GoRoute(
  path: AccountsPaths.accounts,
  builder: (context, state) => AccountsScreen(
    now: now,
    onOpenAccount: (accountId) =>
        context.push(AccountsPaths.account(accountId)),
  ),
);

/// The detail of one account. The app mounts it outside its navigation
/// shell: it covers the whole screen.
///
/// Besides what the list reads, it takes [AccountsRepository] and
/// [Telemetry] from the tree to follow the movements of the account for as
/// long as the screen is open.
GoRoute accountDetailRoute({DateTime Function() now = DateTime.now}) => GoRoute(
  path: AccountsPaths._account,
  builder: (context, state) {
    final accountId = state.pathParameters[AccountsPaths._accountId]!;

    return BlocProvider(
      create: (context) => MovementsBloc(
        repository: context.read<AccountsRepository>(),
        accountId: accountId,
        telemetry: context.read<Telemetry>(),
        now: now,
      )..add(const MovementsStarted()),
      child: AccountDetailScreen(
        accountId: accountId,
        now: now,
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AccountsPaths.accounts),
      ),
    );
  },
);
