import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/domain/movement.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/detail/movement_detail_sheet.dart';
import 'package:feature_accounts/src/presentation/formatting/time_labels.dart';
import 'package:feature_accounts/src/presentation/home/accounts_module_state.dart';
import 'package:feature_accounts/src/presentation/home/recent_movements_bloc.dart';
import 'package:feature_accounts/src/presentation/widgets/freshness_caption.dart';
import 'package:feature_accounts/src/presentation/widgets/load_failure_view.dart';
import 'package:feature_accounts/src/presentation/widgets/movement_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:module_kit/module_kit.dart';

/// Home module: the latest movements across the customer's accounts.
///
/// It follows them with a Bloc of its own, so the movements service can
/// fail, or be taken down from the backoffice, while the balance and the
/// accounts above stay on screen.
class RecentMovementsModule extends StatelessWidget {
  const RecentMovementsModule({
    required this.module,
    required this.now,
    super.key,
  });

  /// Name of the setting that says how many movements to show.
  static const String limitProp = 'limit';

  /// Movements shown when the configuration does not say how many.
  static const int defaultLimit = 4;

  /// The most the module shows, whatever the configuration says: it is a
  /// summary, and the full list is one tap away.
  static const int maxLimit = 10;

  final HomeModuleContext module;

  /// The current moment, for writing days and the age of saved data.
  final DateTime Function() now;

  int get _limit {
    final published = module.integer(limitProp);
    if (published == null || published < 1) return defaultLimit;
    return published > maxLimit ? maxLimit : published;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // A change in the published limit starts a new listener.
      key: ValueKey(_limit),
      create: (context) => RecentMovementsBloc(
        repository: context.read<AccountsRepository>(),
        limit: _limit,
        telemetry: context.read<Telemetry>(),
      )..add(const RecentMovementsStarted()),
      child: _RecentMovements(module: module, now: now),
    );
  }
}

class _RecentMovements extends StatelessWidget {
  const _RecentMovements({required this.module, required this.now});

  final HomeModuleContext module;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RecentMovementsBloc>();
    final movements = context.watch<RecentMovementsBloc>().state.movements;
    final seeAll = module.destinations.resolve(Destinations.movements);

    Future<void> refresh({bool isRetry = false}) {
      bloc.add(RecentMovementsRefreshRequested(isRetry: isRetry));
      return untilLoaded(bloc.stream, (state) => state.movements.isLoading);
    }

    return HomeModuleBinding(
      module: module,
      status: moduleStatus(movements, hasContent: movements.hasData),
      onRefresh: refresh,
      child: ModuleContainer(
        title: AccountsStrings.recentMovementsTitle,
        actionLabel: seeAll == null ? null : AccountsStrings.seeAll,
        onAction: seeAll == null ? null : () => seeAll(context),
        child: _content(
          context,
          movements,
          onRetry: () => unawaited(refresh(isRetry: true)),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    LoadState<List<Movement>> movements, {
    required VoidCallback onRetry,
  }) {
    final data = movements.data;
    if (data == null) {
      return switch (movements.failure) {
        null => const _MovementsSkeleton(),
        _ => InlineError(
          message: AccountsStrings.movementsFailed,
          isRetrying: movements.isLoading,
          onRetry: onRetry,
        ),
      };
    }

    final accounts = context.watch<AccountsBloc>().state;
    final showsAge =
        movements.origin == DataOrigin.cache || movements.isOutdated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (movements.needsOutdatedNotice)
          OutdatedNotice(
            message: AccountsStrings.movementsOutdated,
            isRetrying: movements.isLoading,
            onRetry: onRetry,
          ),
        if (data.isEmpty)
          Text(
            AccountsStrings.noMovementsTitle,
            style: AppTypography.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        for (final (index, movement) in data.indexed) ...[
          if (index > 0) const Divider(),
          MovementRow(
            icon: movementIcon(movement),
            description: movement.description,
            detail: TimeLabels.moment(movement.postedAt, now: now()),
            amountCents: movement.amountCents,
            // The detail names the account, so it opens only once the
            // account of the movement is known.
            onTap: switch (accounts.byId(movement.accountId)) {
              null => null,
              final account => () => unawaited(
                showMovementDetail(
                  context,
                  movement: movement,
                  account: account,
                ),
              ),
            },
          ),
        ],
        if (showsAge) ...[
          const SizedBox(height: AppSpacing.x2),
          FreshnessCaption(syncedAt: movements.syncedAt, now: now),
        ],
      ],
    );
  }
}

/// Placeholders with the geometry of the rows they stand for.
class _MovementsSkeleton extends StatelessWidget {
  const _MovementsSkeleton();

  static const double _row = 56;
  static const int _rows = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < _rows; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.x2),
          const SkeletonBlock(height: _row),
        ],
      ],
    );
  }
}
