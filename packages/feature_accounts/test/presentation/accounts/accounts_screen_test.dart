import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/presentation/accounts/accounts_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/pump_accounts.dart';

void main() {
  late AccountsHarness harness;
  late List<String> opened;

  Widget screen() => AccountsScreen(onOpenAccount: opened.add, now: () => now);

  void backendAnswers(Result<AccountsSnapshot> result) {
    harness.repository.onRefreshAccounts = () async => result;
  }

  setUp(() {
    harness = AccountsHarness();
    opened = [];
  });

  testWidgets('draws placeholders shaped like the accounts while loading', (
    tester,
  ) async {
    harness.repository.onRefreshAccounts = () =>
        Completer<Result<AccountsSnapshot>>().future;

    await harness.pump(tester, screen());

    expect(find.text('Cuentas'), findsOneWidget);
    expect(find.byType(SkeletonBlock), findsWidgets);
    expect(find.byType(AccountCard), findsNothing);
    expect(find.text('No pudimos conectarnos'), findsNothing);
  });

  testWidgets('shows the total and one card per account', (tester) async {
    backendAnswers(Success(accountsSnapshot(const [savings, checking])));

    await harness.pump(tester, screen());
    await tester.pump();

    expect(find.text('SALDO TOTAL'), findsOneWidget);
    expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);
    expect(find.byType(AccountCard), findsNWidgets(2));
    expect(find.text('Cuenta de ahorros'), findsOneWidget);
    expect(find.text('****1093'), findsOneWidget);
    expect(find.textContaining('Actualizado'), findsNothing);
  });

  testWidgets('opens the account that was tapped', (tester) async {
    backendAnswers(Success(accountsSnapshot(const [savings, checking])));
    await harness.pump(tester, screen());
    await tester.pump();

    await tester.tap(find.text('Cuenta corriente'));

    expect(opened, ['checking']);
  });

  testWidgets('offline, shows the saved accounts and says how old they are', (
    tester,
  ) async {
    harness = AccountsHarness(online: false);
    backendAnswers(const Failed(OfflineFailure()));

    await harness.pump(tester, screen());
    await harness.deliverAccounts(
      tester,
      accountsSnapshot(const [savings, checking], origin: DataOrigin.cache),
    );

    expect(
      find.text('Sin conexión. Mostrando datos guardados'),
      findsOneWidget,
    );
    expect(find.text('Actualizado hace 8 min'), findsOneWidget);
    expect(find.byType(AccountCard), findsNWidgets(2));
    expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);
  });

  testWidgets('when the refresh fails, keeps the saved accounts with a notice '
      'and a way to try again', (tester) async {
    backendAnswers(const Failed(TimeoutFailure()));
    await harness.pump(tester, screen());
    await harness.deliverAccounts(
      tester,
      accountsSnapshot(const [savings, checking], origin: DataOrigin.cache),
    );

    expect(find.byType(AccountCard), findsNWidgets(2));
    expect(
      find.textContaining('No pudimos actualizar tus cuentas'),
      findsOneWidget,
    );
    expect(find.text('Actualizado hace 8 min'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(harness.repository.accountRefreshes, 2);
  });

  testWidgets('with nothing saved and no connection, explains it and offers '
      'a retry', (tester) async {
    harness = AccountsHarness(online: false);
    backendAnswers(const Failed(OfflineFailure()));

    await harness.pump(tester, screen());
    await tester.pump();

    expect(find.text('No pudimos conectarnos'), findsOneWidget);
    expect(find.text('Revisa tu conexión e intenta de nuevo.'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(
      find.text('Sin conexión. Mostrando datos guardados'),
      findsNothing,
    );
    expect(find.byType(AccountCard), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(harness.repository.accountRefreshes, 2);
  });

  testWidgets('says how many attempts were made once they are exhausted', (
    tester,
  ) async {
    backendAnswers(const Failed(ServiceUnavailableFailure('accounts')));

    await harness.pump(tester, screen());
    await tester.pump();

    expect(find.text('No pudimos conectarnos'), findsOneWidget);
    expect(find.text('Lo intentamos 3 veces sin éxito.'), findsOneWidget);
  });

  testWidgets('shows progress on the retry instead of the placeholders', (
    tester,
  ) async {
    backendAnswers(const Failed(TimeoutFailure()));
    await harness.pump(tester, screen());
    await tester.pump();
    harness.repository.onRefreshAccounts = () =>
        Completer<Result<AccountsSnapshot>>().future;

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(find.text('No pudimos conectarnos'), findsOneWidget);
    expect(find.byType(SkeletonBlock), findsNothing);
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).isLoading,
      isTrue,
    );
  });

  testWidgets('a customer without accounts yet is told they are on the way', (
    tester,
  ) async {
    backendAnswers(Success(accountsSnapshot(const [])));

    await harness.pump(tester, screen());
    await tester.pump();

    expect(find.text('Estamos preparando tu cuenta'), findsOneWidget);
    expect(find.text('SALDO TOTAL'), findsNothing);
    expect(find.text('No pudimos conectarnos'), findsNothing);

    await tester.tap(find.text('Actualizar'));
    await tester.pump();
    expect(harness.repository.accountRefreshes, 2);
  });

  testWidgets('fits a small phone at 130% text in every state', (
    tester,
  ) async {
    useSmallPhone(tester);
    harness = AccountsHarness(online: false);
    backendAnswers(const Failed(TimeoutFailure()));

    await harness.pump(tester, screen(), textScale: largeText);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await harness.deliverAccounts(
      tester,
      accountsSnapshot(const [savings, checking], origin: DataOrigin.cache),
    );
    expect(tester.takeException(), isNull);
  });
}
