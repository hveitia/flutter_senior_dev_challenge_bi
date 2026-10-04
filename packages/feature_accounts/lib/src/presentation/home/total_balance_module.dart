import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/home/accounts_module_state.dart';
import 'package:feature_accounts/src/presentation/home/amount_visibility_cubit.dart';
import 'package:feature_accounts/src/presentation/widgets/freshness_caption.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:module_kit/module_kit.dart';

/// Home module: what the customer's accounts add up to, with the control
/// that hides the amounts.
///
/// When the accounts cannot be loaded this is the module that says so and
/// offers the retry; the carousel below draws nothing in that case.
class TotalBalanceModule extends StatelessWidget {
  const TotalBalanceModule({
    required this.module,
    required this.now,
    super.key,
  });

  final HomeModuleContext module;

  /// The current moment, for saying how old saved data is.
  final DateTime Function() now;

  /// Name of the setting that adds the investments to the total.
  static const String includesInvestmentsProp = 'includesInvestments';

  bool get _includesInvestments =>
      module.props[includesInvestmentsProp] == true;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccountsBloc>();
    final accounts = context.watch<AccountsBloc>().state.accounts;

    return HomeModuleBinding(
      module: module,
      status: accountsModuleStatus(accounts),
      onRefresh: () => refreshAccounts(bloc),
      child: _content(context, bloc, accounts),
    );
  }

  Widget _content(
    BuildContext context,
    AccountsBloc bloc,
    LoadState<List<Account>> accounts,
  ) {
    final data = showableAccounts(accounts);
    if (data == null) {
      return switch (accounts.failure) {
        null => const _BalanceSkeleton(),
        _ => InlineError(
          message: AccountsStrings.balanceFailed,
          isRetrying: accounts.isLoading,
          onRetry: () => unawaited(refreshAccounts(bloc, isRetry: true)),
        ),
      };
    }

    if (data.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: AccountsStrings.preparingTitle,
        message: AccountsStrings.preparingMessage,
      );
    }

    // A total that leaves an account out would be a wrong number.
    if (accounts.isIncomplete) {
      return const InlineAlert(
        message: AccountsStrings.accountsIncomplete,
        tone: AppTone.warning,
      );
    }

    final hidden = context.watch<AmountVisibilityCubit>().state;
    final showsAge = accounts.origin == DataOrigin.cache || accounts.isOutdated;
    // Without the setting the total is the money that can be spent; what is
    // invested is added only when the configuration asks for it.
    final total = totalAvailableCents(
      _includesInvestments ? data : cashAccounts(data),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const GroupHeader(label: AccountsStrings.totalBalance),
              const SizedBox(height: AppSpacing.x1),
              // Accounts in different currencies have no total; each card
              // still states its own balance.
              if (total != null)
                AmountText(
                  cents: total,
                  size: AmountTextSize.display,
                  obscured: hidden,
                ),
              const SizedBox(height: AppSpacing.x1),
              if (showsAge)
                FreshnessCaption(syncedAt: accounts.syncedAt, now: now)
              else
                Text(
                  _includesInvestments
                      ? AccountsStrings.balanceWithInvestmentsCaption
                      : AccountsStrings.balanceCaption,
                  style: AppTypography.caption.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: hidden
              ? AccountsStrings.showAmounts
              : AccountsStrings.hideAmounts,
          onPressed: context.read<AmountVisibilityCubit>().toggle,
          icon: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ],
    );
  }
}

/// Placeholders with the geometry of the loaded module: label, then total.
class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  static const double _label = 16;
  static const double _labelWidth = 96;
  static const double _total = 34;
  static const double _totalWidth = 180;

  @override
  Widget build(BuildContext context) {
    final small = BorderRadius.circular(context.metrics.inputRadius);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonBlock(height: _label, width: _labelWidth, borderRadius: small),
        const SizedBox(height: AppSpacing.x2),
        SkeletonBlock(height: _total, width: _totalWidth, borderRadius: small),
      ],
    );
  }
}
