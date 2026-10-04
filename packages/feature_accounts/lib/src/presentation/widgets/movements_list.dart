import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/movement.dart';
import 'package:feature_accounts/src/domain/movement_filter.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/detail/movement_detail_sheet.dart';
import 'package:feature_accounts/src/presentation/detail/movements_bloc.dart';
import 'package:feature_accounts/src/presentation/formatting/time_labels.dart';
import 'package:feature_accounts/src/presentation/widgets/freshness_caption.dart';
import 'package:feature_accounts/src/presentation/widgets/load_failure_view.dart';
import 'package:feature_accounts/src/presentation/widgets/movement_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The search field and the filter chips of a list of movements. They act
/// on the `MovementsBloc` of the tree.
class MovementsControls extends StatelessWidget {
  const MovementsControls({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MovementsBloc>();
    final chosen = context.select<MovementsBloc, MovementFilter>(
      (bloc) => bloc.state.filter,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
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
                selected: chosen == filter,
                // Tapping the chosen filter keeps it: one of them is always
                // in effect.
                onSelected: (_) => bloc.add(MovementsFilterChanged(filter)),
              ),
          ],
        ),
      ],
    );
  }
}

/// The movements of the `MovementsBloc` of the tree as slivers: loading,
/// failure, the notices about saved or incomplete data, the days with their
/// rows and the way to bring older ones.
///
/// The account detail and the list of every movement draw the same thing;
/// they differ in whether a row names its account ([namesAccount]) and in
/// the two messages that mention whose movements these are.
List<Widget> movementsSlivers(
  BuildContext context, {
  required DateTime Function() now,
  required Account? Function(Movement movement) accountOf,
  required String incompleteMessage,
  required String emptyMessage,
  bool namesAccount = false,
}) {
  final bloc = context.read<MovementsBloc>();
  final state = context.watch<MovementsBloc>().state;
  final horizontal = EdgeInsets.symmetric(
    horizontal: context.metrics.screenMargin,
  );

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
  final showsAge = movements.origin == DataOrigin.cache || movements.isOutdated;

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
      box(InlineAlert(message: incompleteMessage, tone: AppTone.warning)),
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
              : EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: AccountsStrings.noMovementsTitle,
                  message: emptyMessage,
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
              child: GroupHeader(label: TimeLabels.day(day.day, now: now())),
            ),
            for (final (index, movement) in day.movements.indexed) ...[
              if (index > 0) const Divider(),
              _row(
                context,
                movement,
                account: accountOf(movement),
                namesAccount: namesAccount,
                now: now,
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
    // While the next page is on its way there is nothing "more" yet, but the
    // button stays to show the progress.
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

Widget _row(
  BuildContext context,
  Movement movement, {
  required Account? account,
  required bool namesAccount,
  required DateTime Function() now,
}) {
  return MovementRow(
    icon: movementIcon(movement),
    description: movement.description,
    // Under the header of its day, a row that names its account says the
    // time only: the day would be said twice.
    detail: namesAccount
        ? TimeLabels.timeWith(
            movement.postedAt,
            account == null ? null : '${account.name} ${account.maskedNumber}',
          )
        : TimeLabels.moment(movement.postedAt, now: now()),
    amountCents: movement.amountCents,
    // The detail names the account, so it opens only once the account of
    // the movement is known.
    onTap: account == null
        ? null
        : () => unawaited(
            showMovementDetail(context, movement: movement, account: account),
          ),
  );
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
