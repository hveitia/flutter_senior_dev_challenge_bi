import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/detail/movements_bloc.dart';
import 'package:feature_accounts/src/presentation/widgets/connection_notice.dart';
import 'package:feature_accounts/src/presentation/widgets/freshness_caption.dart';
import 'package:feature_accounts/src/presentation/widgets/load_failure_view.dart';
import 'package:feature_accounts/src/presentation/widgets/movements_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One account: its balances, its number and its movements.
///
/// The balances come from `AccountsBloc` and the movements from
/// `MovementsBloc`, both read from the tree. Each part shows its own
/// loading and failure, so a problem with movements never hides the
/// balance.
class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({
    required this.accountId,
    required this.onBack,
    this.onTransfer,
    this.now = DateTime.now,
    super.key,
  });

  final String accountId;

  /// Starts a transfer from this account. Null while transfers are not
  /// available: the action is then left out rather than shown disabled.
  final VoidCallback? onTransfer;

  /// Leaves the screen when the account cannot be shown.
  final VoidCallback onBack;

  /// The current moment, for naming days and the age of saved data.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final accountsState = context.watch<AccountsBloc>().state;
    final accounts = accountsState.accounts;
    final account = accountsState.byId(accountId);

    final onTransfer = this.onTransfer;
    // Money leaves only from an account that holds spendable money.
    final canTransfer = onTransfer != null && (account?.kind.isCash ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(account?.name ?? '')),
      bottomNavigationBar: canTransfer
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.all(context.metrics.screenMargin),
                child: AppButton(
                  label: AccountsStrings.transfer,
                  onPressed: onTransfer,
                ),
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConnectionNotice(hasSavedData: account != null),
          Expanded(
            child: switch (account) {
              final account? => _AccountContent(
                account: account,
                accounts: accounts,
                now: now,
              ),
              null when accounts.isWaiting => const _BalanceSkeleton(),
              null when accounts.hasFailed => _Centered(
                child: LoadFailureView(
                  failure: accounts.failure!,
                  isRetrying: accounts.isLoading,
                  onRetry: () => context.read<AccountsBloc>().add(
                    const AccountsRefreshRequested(isRetry: true),
                  ),
                ),
              ),
              null => _Centered(
                child: EmptyState(
                  icon: Icons.search_off,
                  title: AccountsStrings.accountMissingTitle,
                  message: AccountsStrings.accountMissingMessage,
                  primaryActionLabel: AccountsStrings.back,
                  onPrimaryAction: onBack,
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _AccountContent extends StatelessWidget {
  const _AccountContent({
    required this.account,
    required this.accounts,
    required this.now,
  });

  final Account account;

  /// Where the balances came from. They are loaded apart from the
  /// movements, so they have an age of their own.
  final LoadState<List<Account>> accounts;
  final DateTime Function() now;

  Future<void> _copyNumber(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: account.number));
    messenger.showSnackBar(
      const SnackBar(content: Text(AccountsStrings.accountNumberCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MovementsBloc>();
    final margin = context.metrics.screenMargin;

    return RefreshIndicator(
      onRefresh: () {
        final accounts = context.read<AccountsBloc>()
          ..add(const AccountsRefreshRequested());
        bloc.add(const MovementsRefreshRequested());
        return Future.wait([
          untilLoaded(accounts.stream, (state) => state.accounts.isLoading),
          untilLoaded(bloc.stream, (state) => state.movements.isLoading),
        ]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              margin,
              context.metrics.moduleGap,
              margin,
              0,
            ),
            sliver: SliverList.list(
              children: [
                const GroupHeader(label: AccountsStrings.available),
                const SizedBox(height: AppSpacing.x1),
                AmountText(
                  cents: account.availableCents,
                  size: AmountTextSize.display,
                ),
                // Data the backend just confirmed needs no age next to it.
                if (accounts.origin == DataOrigin.cache ||
                    accounts.isOutdated) ...[
                  const SizedBox(height: AppSpacing.x1),
                  FreshnessCaption(syncedAt: accounts.syncedAt, now: now),
                ],
                const SizedBox(height: AppSpacing.x2),
                DetailRow(
                  label: AccountsStrings.ledger,
                  value: formatAmount(account.ledgerCents).text,
                ),
                DetailRow(
                  label: AccountsStrings.accountNumber,
                  value: account.number,
                  trailing: IconButton(
                    tooltip: AccountsStrings.copyAccountNumber,
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => unawaited(_copyNumber(context)),
                  ),
                ),
                const Divider(height: AppSpacing.x8),
                const MovementsControls(),
                SizedBox(height: context.metrics.componentGap),
              ],
            ),
          ),
          ...movementsSlivers(
            context,
            now: now,
            accountOf: (_) => account,
            incompleteMessage: AccountsStrings.movementsIncomplete,
            emptyMessage: AccountsStrings.noMovementsMessage,
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: context.metrics.moduleGap),
          ),
        ],
      ),
    );
  }
}

/// Centers [child] and lets it scroll when it does not fit.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.metrics.screenMargin),
        child: child,
      ),
    );
  }
}

/// Placeholder for the balances while the accounts are loading.
class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  static const double _label = 16;
  static const double _labelWidth = 96;
  static const double _amount = 34;
  static const double _amountWidth = 180;

  @override
  Widget build(BuildContext context) {
    final small = BorderRadius.circular(context.metrics.inputRadius);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.metrics.screenMargin,
        vertical: context.metrics.moduleGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock(
            height: _label,
            width: _labelWidth,
            borderRadius: small,
          ),
          const SizedBox(height: AppSpacing.x2),
          SkeletonBlock(
            height: _amount,
            width: _amountWidth,
            borderRadius: small,
          ),
        ],
      ),
    );
  }
}
