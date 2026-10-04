import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/domain/transfers_repository.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_screen.dart';
import 'package:feature_accounts/src/presentation/detail/account_detail_screen.dart';
import 'package:feature_accounts/src/presentation/detail/movements_bloc.dart';
import 'package:feature_accounts/src/presentation/movements/movements_screen.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_cubit.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_notices.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_screen.dart';
import 'package:flutter/widgets.dart';
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

  /// Every movement of the customer, across accounts.
  static const String movements = '/movimientos';

  /// A transfer between the customer's accounts.
  static const String transfer = '/transferir';
  static const String _from = 'desde';

  /// A transfer that starts from the account with [accountId].
  static String transferFrom(String accountId) =>
      '$transfer?$_from=${Uri.encodeQueryComponent(accountId)}';
}

/// The list of accounts. The app mounts it inside its navigation shell.
///
/// It reads `AccountsBloc` and `ConnectivityCubit` from the widget tree.
/// [now] is the clock used to say how old saved data is. [notices] go above
/// the list; the app passes [QueuedTransfersNotice] and
/// [ProvisioningNotice] where their Cubits are provided.
GoRoute accountsTabRoute({
  DateTime Function() now = DateTime.now,
  List<Widget> notices = const [],
}) => GoRoute(
  path: AccountsPaths.accounts,
  builder: (context, state) => AccountsScreen(
    now: now,
    notices: notices,
    onOpenAccount: (accountId) =>
        context.push(AccountsPaths.account(accountId)),
    onOpenMovements: () => context.push(AccountsPaths.movements),
  ),
);

/// Every movement of the customer, across accounts. The app mounts it
/// outside its navigation shell: it covers the whole screen and is left
/// with the back arrow.
///
/// It takes [AccountsRepository], [Telemetry] and `AccountsBloc` from the
/// tree, and follows the movements for as long as the screen is open.
GoRoute movementsRoute({DateTime Function() now = DateTime.now}) => GoRoute(
  path: AccountsPaths.movements,
  builder: (context, state) => BlocProvider(
    create: (context) => MovementsBloc(
      repository: context.read<AccountsRepository>(),
      telemetry: context.read<Telemetry>(),
      now: now,
    )..add(const MovementsStarted()),
    child: MovementsScreen(now: now),
  ),
);

/// A transfer between the customer's own accounts. The app mounts it
/// outside its navigation shell, and only offers the way in while the
/// published configuration has transfers switched on.
///
/// It takes [TransfersRepository], [Telemetry] and `AccountsBloc` from the
/// tree. [onDone] leaves towards the home.
GoRoute transferRoute({required void Function(BuildContext) onDone}) => GoRoute(
  path: AccountsPaths.transfer,
  builder: (context, state) {
    final accounts = context.read<AccountsBloc>();

    return BlocProvider(
      create: (context) => TransferCubit(
        repository: context.read<TransfersRepository>(),
        telemetry: context.read<Telemetry>(),
        accounts: () => accounts.state.accounts.data ?? const [],
        fromAccountId: state.uri.queryParameters[AccountsPaths._from],
      ),
      child: TransferScreen(
        onClose: () => context.canPop() ? context.pop() : onDone(context),
        onSeeMovement: (accountId) =>
            context.go(AccountsPaths.account(accountId)),
        onDone: () => onDone(context),
      ),
    );
  },
);

/// The detail of one account. The app mounts it outside its navigation
/// shell: it covers the whole screen.
///
/// Besides what the list reads, it takes [AccountsRepository] and
/// [Telemetry] from the tree to follow the movements of the account for as
/// long as the screen is open.
///
/// [canTransfer] says whether transfers are offered right now; it is asked
/// while building, so it may watch the published feature flags and the
/// screen follows them live. Without it there is no way into a transfer.
GoRoute accountDetailRoute({
  DateTime Function() now = DateTime.now,
  bool Function(BuildContext context)? canTransfer,
}) => GoRoute(
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
      child: Builder(
        builder: (context) => AccountDetailScreen(
          accountId: accountId,
          now: now,
          onTransfer: canTransfer?.call(context) ?? false
              ? () => context.push(AccountsPaths.transferFrom(accountId))
              : null,
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(AccountsPaths.accounts),
        ),
      ),
    );
  },
);
