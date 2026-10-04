import 'dart:async';

import 'package:feature_accounts/src/presentation/accounts_routes.dart';
import 'package:feature_accounts/src/presentation/home/account_carousel_module.dart';
import 'package:feature_accounts/src/presentation/home/accounts_module_state.dart';
import 'package:feature_accounts/src/presentation/home/investment_summary_module.dart';
import 'package:feature_accounts/src/presentation/home/recent_movements_module.dart';
import 'package:feature_accounts/src/presentation/home/total_balance_module.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:module_kit/module_kit.dart';

/// The home modules the accounts domain owns, by the type the published
/// configuration names them with.
abstract final class AccountsModuleTypes {
  static const String totalBalance = totalBalanceType;
  static const String accountCarousel = 'accountCarousel';
  static const String investmentSummary = 'investmentSummary';
  static const String recentMovements = 'recentMovements';
}

/// Opens the detail of an account.
typedef AccountOpener = void Function(BuildContext context, String accountId);

/// Registers the modules of the accounts domain.
///
/// They read `AccountsBloc`, `AmountVisibilityCubit`, `AccountsRepository`
/// and `Telemetry` from the tree, which the app provides to every screen of
/// a signed-in customer. [now] is the clock used to say how old saved data
/// is; [onOpenAccount] defaults to the feature's own route.
void registerAccountsHomeModules(
  HomeModuleRegistry registry, {
  DateTime Function() now = DateTime.now,
  AccountOpener? onOpenAccount,
}) {
  final openAccount = onOpenAccount ?? _pushAccount;

  registry
    ..register(
      AccountsModuleTypes.totalBalance,
      (context, module) => TotalBalanceModule(module: module, now: now),
    )
    ..register(
      AccountsModuleTypes.accountCarousel,
      (context, module) =>
          AccountCarouselModule(module: module, onOpenAccount: openAccount),
    )
    ..register(
      AccountsModuleTypes.investmentSummary,
      (context, module) => InvestmentSummaryModule(module: module),
    )
    ..register(
      AccountsModuleTypes.recentMovements,
      (context, module) => RecentMovementsModule(module: module, now: now),
    );
}

void _pushAccount(BuildContext context, String accountId) {
  unawaited(context.push(AccountsPaths.account(accountId)));
}
