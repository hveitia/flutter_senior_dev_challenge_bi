import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/home/accounts_home_modules.dart';
import 'package:feature_accounts/src/presentation/home/accounts_module_state.dart';
import 'package:feature_accounts/src/presentation/home/amount_visibility_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:module_kit/module_kit.dart';

/// Home module: the customer's accounts as cards that scroll sideways.
///
/// It shares the accounts with the total balance module. When they cannot
/// be loaded and the balance is published in the same home, it draws
/// nothing: the balance already says so, and two errors about the same
/// thing would only add noise. Published without the balance, it says the
/// failure itself and offers the retry.
class AccountCarouselModule extends StatelessWidget {
  const AccountCarouselModule({
    required this.module,
    required this.onOpenAccount,
    super.key,
  });

  final HomeModuleContext module;
  final AccountOpener onOpenAccount;

  /// Part of the available width a card takes, so the next one peeks in
  /// and shows there is more to the side.
  static const double _cardWidthFactor = 0.8;
  static const double _skeletonHeight = 146;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccountsBloc>();
    final accounts = context.watch<AccountsBloc>().state.accounts;
    // The cards are the accounts the customer spends from. What is invested
    // has a module of its own.
    final data = switch (showableAccounts(accounts)) {
      null => null,
      final all => cashAccounts(all),
    };

    final hasFailed = data == null && accounts.failure != null;
    final drawsNothing =
        (hasFailed && balanceSaysAccountsFailure(module)) ||
        (data?.isEmpty ?? false);

    return HomeModuleBinding(
      module: module,
      status: drawsNothing
          ? HomeModuleStatus.hidden
          : accountsModuleStatus(accounts),
      onRefresh: () => refreshAccounts(bloc),
      child: switch (data) {
        _ when drawsNothing => const SizedBox.shrink(),
        null when hasFailed => InlineError(
          message: AccountsStrings.carouselFailed,
          isRetrying: accounts.isLoading,
          onRetry: () => unawaited(refreshAccounts(bloc, isRetry: true)),
        ),
        null => const _CarouselSkeleton(),
        _ => LayoutBuilder(
          builder: (context, constraints) {
            final hidden = context.watch<AmountVisibilityCubit>().state;
            final cardWidth = data.length == 1
                ? constraints.maxWidth
                : constraints.maxWidth * _cardWidthFactor;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // The cards slide under the screen margin up to the edge.
              clipBehavior: Clip.none,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, account) in data.indexed) ...[
                      if (index > 0)
                        SizedBox(width: context.metrics.componentGap),
                      SizedBox(
                        width: cardWidth,
                        child: AccountCard(
                          name: account.name,
                          maskedNumber: account.maskedNumber,
                          balanceCents: account.availableCents,
                          balanceObscured: hidden,
                          onTap: () => onOpenAccount(context, account.id),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      },
    );
  }
}

/// A placeholder the size of one card and the start of the next.
class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return const FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: AccountCarouselModule._cardWidthFactor,
      child: SkeletonBlock(height: AccountCarouselModule._skeletonHeight),
    );
  }
}
