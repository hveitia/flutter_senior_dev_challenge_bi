import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_bloc.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/detail/movements_bloc.dart';
import 'package:feature_accounts/src/presentation/widgets/connection_notice.dart';
import 'package:feature_accounts/src/presentation/widgets/load_failure_view.dart';
import 'package:feature_accounts/src/presentation/widgets/movements_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Every movement of the customer, across accounts, newest first.
///
/// It is the list of the account detail without an account: the same
/// search, filters, pages and states, with each row naming its account.
/// The movements come from a `MovementsBloc` that follows no account in
/// particular, and the names of the accounts from `AccountsBloc`, both read
/// from the tree.
class MovementsScreen extends StatelessWidget {
  const MovementsScreen({this.now = DateTime.now, super.key});

  /// The current moment, for naming days and the age of saved data.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MovementsBloc>();
    final hasSavedData = context.select<MovementsBloc, bool>(
      (bloc) => bloc.state.movements.hasData,
    );
    final accounts = context.watch<AccountsBloc>().state;
    final margin = context.metrics.screenMargin;

    return Scaffold(
      appBar: AppBar(title: const Text(AccountsStrings.movementsTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConnectionNotice(hasSavedData: hasSavedData),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                bloc.add(const MovementsRefreshRequested());
                return untilLoaded(
                  bloc.stream,
                  (state) => state.movements.isLoading,
                );
              },
              child: CustomScrollView(
                // Always scrollable, so a short list can still be pulled
                // down.
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      margin,
                      context.metrics.moduleGap,
                      margin,
                      context.metrics.componentGap,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: MovementsControls(),
                    ),
                  ),
                  ...movementsSlivers(
                    context,
                    now: now,
                    accountOf: (movement) => accounts.byId(movement.accountId),
                    namesAccount: true,
                    incompleteMessage: AccountsStrings.allMovementsIncomplete,
                    emptyMessage: AccountsStrings.allNoMovementsMessage,
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.metrics.moduleGap),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
