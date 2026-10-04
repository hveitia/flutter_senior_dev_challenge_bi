import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/widgets/freshness_caption.dart';
import 'package:feature_accounts/src/presentation/widgets/load_failure_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:module_kit/module_kit.dart';

/// The customer's accounts and what they add up to.
///
/// It reads `AccountsBloc` and `ConnectivityCubit` from the tree.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({
    required this.onOpenAccount,
    this.now = DateTime.now,
    super.key,
  });

  /// Called with the id of the account the customer tapped.
  final ValueChanged<String> onOpenAccount;

  /// The current moment, for saying how old saved data is.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountsBloc>().state.accounts;

    return Scaffold(
      appBar: const TabRootAppBar(title: AccountsStrings.accountsTitle),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConnectionBanner(hasSavedData: _showable(accounts) != null),
          Expanded(child: _content(context, accounts)),
        ],
      ),
    );
  }

  /// What can be put on screen. An empty list that only the saved copy
  /// vouches for is not: the copy may simply have been emptied, and it
  /// would read as a customer without accounts.
  static List<Account>? _showable(LoadState<List<Account>> accounts) {
    final data = accounts.data;
    if (data == null) return null;
    if (data.isEmpty && accounts.origin != DataOrigin.server) return null;
    return data;
  }

  Widget _content(BuildContext context, LoadState<List<Account>> accounts) {
    void refresh({bool isRetry = false}) => context.read<AccountsBloc>().add(
      AccountsRefreshRequested(isRetry: isRetry),
    );

    final data = _showable(accounts);
    if (data == null) {
      return switch (accounts.failure) {
        null => const _AccountsSkeleton(),
        final failure => _Centered(
          child: LoadFailureView(
            failure: failure,
            isRetrying: accounts.isLoading,
            onRetry: () => refresh(isRetry: true),
          ),
        ),
      };
    }

    if (data.isEmpty) {
      return _Centered(
        child: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: AccountsStrings.preparingTitle,
          message: AccountsStrings.preparingMessage,
          primaryActionLabel: AccountsStrings.refresh,
          onPrimaryAction: accounts.isLoading ? null : refresh,
        ),
      );
    }

    final margin = context.metrics.screenMargin;
    // Data the backend just confirmed needs no age next to it.
    final showsAge = accounts.origin == DataOrigin.cache || accounts.isOutdated;

    return RefreshIndicator(
      onRefresh: () {
        final bloc = context.read<AccountsBloc>();
        refresh();
        return untilLoaded(bloc.stream, (state) => state.accounts.isLoading);
      },
      child: ListView(
        // Always scrollable, so a short list can still be pulled down.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: margin,
          vertical: context.metrics.moduleGap,
        ),
        children: [
          if (accounts.needsOutdatedNotice) ...[
            OutdatedNotice(
              message: AccountsStrings.accountsOutdated,
              isRetrying: accounts.isLoading,
              onRetry: () => refresh(isRetry: true),
            ),
            SizedBox(height: context.metrics.componentGap),
          ],
          // A total that leaves an account out would be a wrong number, so
          // it gives way to saying what happened.
          if (accounts.isIncomplete)
            const InlineAlert(
              message: AccountsStrings.accountsIncomplete,
              tone: AppTone.warning,
            )
          // Accounts in different currencies have no total either; each
          // card still states its own balance.
          else if (totalAvailableCents(data) case final total?) ...[
            const GroupHeader(label: AccountsStrings.totalBalance),
            const SizedBox(height: AppSpacing.x1),
            AmountText(cents: total, size: AmountTextSize.display),
          ],
          if (showsAge) ...[
            const SizedBox(height: AppSpacing.x1),
            FreshnessCaption(syncedAt: accounts.syncedAt, now: now),
          ],
          SizedBox(height: context.metrics.moduleGap),
          for (final (index, account) in data.indexed) ...[
            if (index > 0) SizedBox(height: context.metrics.componentGap),
            AccountCard(
              name: account.name,
              maskedNumber: account.maskedNumber,
              balanceCents: account.availableCents,
              onTap: () => onOpenAccount(account.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// Centers [child] and lets it scroll when it does not fit, as happens with
/// large text on a small phone.
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

/// Placeholders with the geometry of the loaded screen: the total, then one
/// block per account card.
class _AccountsSkeleton extends StatelessWidget {
  const _AccountsSkeleton();

  static const double _label = 16;
  static const double _labelWidth = 96;
  static const double _total = 34;
  static const double _totalWidth = 180;
  static const double _card = 146;
  static const int _cards = 2;

  @override
  Widget build(BuildContext context) {
    final small = BorderRadius.circular(context.metrics.inputRadius);

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.metrics.screenMargin,
        vertical: context.metrics.moduleGap,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SkeletonBlock(
            height: _label,
            width: _labelWidth,
            borderRadius: small,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Align(
          alignment: Alignment.centerLeft,
          child: SkeletonBlock(
            height: _total,
            width: _totalWidth,
            borderRadius: small,
          ),
        ),
        SizedBox(height: context.metrics.moduleGap),
        for (var card = 0; card < _cards; card++) ...[
          if (card > 0) SizedBox(height: context.metrics.componentGap),
          const SkeletonBlock(height: _card),
        ],
      ],
    );
  }
}
