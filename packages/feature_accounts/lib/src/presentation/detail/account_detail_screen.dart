import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/domain/movement_filter.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/detail/movement_detail_sheet.dart';
import 'package:feature_accounts/src/presentation/detail/movements_bloc.dart';
import 'package:feature_accounts/src/presentation/formatting/time_labels.dart';
import 'package:feature_accounts/src/presentation/widgets/connection_notice.dart';
import 'package:feature_accounts/src/presentation/widgets/freshness_caption.dart';
import 'package:feature_accounts/src/presentation/widgets/load_failure_view.dart';
import 'package:feature_accounts/src/presentation/widgets/movement_icons.dart';
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
    this.now = DateTime.now,
    super.key,
  });

  final String accountId;

  /// Leaves the screen when the account cannot be shown.
  final VoidCallback onBack;

  /// The current moment, for naming days and the age of saved data.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final accountsState = context.watch<AccountsBloc>().state;
    final accounts = accountsState.accounts;
    final account = accountsState.byId(accountId);

    return Scaffold(
      appBar: AppBar(title: Text(account?.name ?? '')),
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
    final state = context.watch<MovementsBloc>().state;
    final bloc = context.read<MovementsBloc>();
    final margin = context.metrics.screenMargin;
    final horizontal = EdgeInsets.symmetric(horizontal: margin);

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
                AppTextField(
                  label: AccountsStrings.searchLabel,
                  hintText: AccountsStrings.searchHint,
                  textInputAction: TextInputAction.search,
                  onChanged: (query) => bloc.add(MovementsSearchChanged(query)),
                ),
                SizedBox(height: context.metrics.componentGap),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (final filter in MovementFilter.values)
                      AppChip(
                        label: AccountsStrings.filter(filter),
                        selected: state.filter == filter,
                        // Tapping the chosen filter keeps it: one of them is
                        // always in effect.
                        onSelected: (_) =>
                            bloc.add(MovementsFilterChanged(filter)),
                      ),
                  ],
                ),
                SizedBox(height: context.metrics.componentGap),
              ],
            ),
          ),
          ..._movements(context, state, bloc, horizontal),
          SliverToBoxAdapter(
            child: SizedBox(height: context.metrics.moduleGap),
          ),
        ],
      ),
    );
  }

  List<Widget> _movements(
    BuildContext context,
    MovementsState state,
    MovementsBloc bloc,
    EdgeInsets horizontal,
  ) {
    Widget box(Widget child) => SliverPadding(
      padding: horizontal,
      sliver: SliverToBoxAdapter(child: child),
    );
    void retry() => bloc.add(const MovementsRefreshRequested(isRetry: true));

    final movements = state.movements;
    if (!movements.hasData) {
      return [
        box(
          switch (movements.failure) {
            null => const _MovementsSkeleton(),
            _ => InlineError(
              message: AccountsStrings.movementsFailed,
              isRetrying: movements.isLoading,
              onRetry: retry,
            ),
          },
        ),
      ];
    }

    final days = groupByDay(state.visible);
    final showsAge =
        movements.origin == DataOrigin.cache || movements.isOutdated;

    return [
      if (movements.needsOutdatedNotice)
        box(
          OutdatedNotice(
            message: AccountsStrings.movementsOutdated,
            isRetrying: movements.isLoading,
            onRetry: retry,
          ),
        ),
      if (movements.isIncomplete)
        box(
          const InlineAlert(
            message: AccountsStrings.movementsIncomplete,
            tone: AppTone.warning,
          ),
        ),
      if (showsAge)
        box(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: FreshnessCaption(syncedAt: movements.syncedAt, now: now),
          ),
        ),
      if (days.isEmpty)
        box(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
            child: state.isNarrowed
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: AccountsStrings.noMatchesTitle,
                    message: AccountsStrings.noMatchesMessage,
                  )
                : const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: AccountsStrings.noMovementsTitle,
                    message: AccountsStrings.noMovementsMessage,
                  ),
          ),
        ),
      for (final day in days)
        SliverPadding(
          padding: horizontal,
          sliver: SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.x4,
                  bottom: AppSpacing.x1,
                ),
                child: GroupHeader(
                  label: TimeLabels.day(day.day, now: now()),
                ),
              ),
              for (final (index, movement) in day.movements.indexed) ...[
                if (index > 0) const Divider(),
                MovementRow(
                  icon: movementIcon(movement),
                  description: movement.description,
                  detail: TimeLabels.moment(movement.postedAt, now: now()),
                  amountCents: movement.amountCents,
                  onTap: () => unawaited(
                    showMovementDetail(
                      context,
                      movement: movement,
                      account: account,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      // The search and the filters work on the loaded pages. With older
      // movements still on the server, "nothing found" would be a guess.
      if (state.isNarrowed && state.hasMore)
        box(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x4),
            child: Text(
              AccountsStrings.narrowedScope,
              style: AppTypography.caption.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ),
      // While the next page is on its way there is nothing "more" yet, but
      // the button stays to show the progress.
      if (state.hasMore || state.isLoadingMore)
        box(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x4),
            child: AppButton(
              label: AccountsStrings.more,
              variant: AppButtonVariant.secondary,
              isLoading: state.isLoadingMore,
              onPressed: () => bloc.add(const MovementsMoreRequested()),
            ),
          ),
        ),
    ];
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

/// Placeholders with the geometry of a few movement rows.
class _MovementsSkeleton extends StatelessWidget {
  const _MovementsSkeleton();

  static const double _row = 56;
  static const int _rows = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < _rows; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.x3),
          SkeletonBlock(
            height: _row,
            borderRadius: BorderRadius.circular(context.metrics.inputRadius),
          ),
        ],
      ],
    );
  }
}
