import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/home/accounts_module_state.dart';
import 'package:feature_accounts/src/presentation/home/amount_visibility_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:module_kit/module_kit.dart';

/// Home module: what the customer has invested, product by product.
///
/// The investments arrive with the accounts, as accounts of the investment
/// kind, so this module shares their data set and fails or recovers with
/// it. A customer without investments sees nothing here.
class InvestmentSummaryModule extends StatelessWidget {
  const InvestmentSummaryModule({required this.module, super.key});

  final HomeModuleContext module;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccountsBloc>();
    final accounts = context.watch<AccountsBloc>().state.accounts;
    final data = showableAccounts(accounts);
    final investments = data == null ? null : investmentAccounts(data);

    final hasFailed = data == null && accounts.failure != null;
    final drawsNothing =
        (hasFailed && balanceSaysAccountsFailure(module)) ||
        (investments?.isEmpty ?? false);

    return HomeModuleBinding(
      module: module,
      status: drawsNothing
          ? HomeModuleStatus.hidden
          : accountsModuleStatus(accounts),
      onRefresh: () => refreshAccounts(bloc),
      child: switch (investments) {
        _ when drawsNothing => const SizedBox.shrink(),
        null when hasFailed => InlineError(
          message: AccountsStrings.investmentsFailed,
          isRetrying: accounts.isLoading,
          onRetry: () => unawaited(refreshAccounts(bloc, isRetry: true)),
        ),
        null => const SkeletonBlock(height: _skeletonHeight),
        _ => _Investments(module: module, investments: investments),
      },
    );
  }

  static const double _skeletonHeight = 96;
}

class _Investments extends StatelessWidget {
  const _Investments({required this.module, required this.investments});

  final HomeModuleContext module;
  final List<Account> investments;

  @override
  Widget build(BuildContext context) {
    final hidden = context.watch<AmountVisibilityCubit>().state;
    final seeAll = module.destinations.resolve(Destinations.accounts);
    final total = totalAvailableCents(investments);
    final scheme = Theme.of(context).colorScheme;

    return ModuleContainer(
      title: AccountsStrings.investmentsTitle,
      actionLabel: seeAll == null ? null : AccountsStrings.seeInvestments,
      onAction: seeAll == null ? null : () => seeAll(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Products in different currencies have no total; each still
          // states its own balance below.
          if (total != null) ...[
            Text(
              AccountsStrings.investedTotal,
              style: AppTypography.caption.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            AmountText(cents: total, obscured: hidden),
            const SizedBox(height: AppSpacing.x2),
          ],
          for (final (index, investment) in investments.indexed) ...[
            if (index > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      investment.name,
                      style: AppTypography.body.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  AmountText(
                    cents: investment.availableCents,
                    size: AmountTextSize.body,
                    obscured: hidden,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
