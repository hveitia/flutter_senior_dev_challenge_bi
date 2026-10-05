import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fixtures.dart';
import '../support/pump_accounts.dart';

void main() {
  late FakeAccountsRepository repository;

  Future<void> pumpRoutes(
    WidgetTester tester, {
    String initialLocation = AccountsPaths.accounts,
  }) async {
    Future<Result<AccountsSnapshot>> accountsAnswer() async =>
        Success(accountsSnapshot(const [savings, checking]));
    Future<Result<MovementsSnapshot>> movementsAnswer() async =>
        Success(movementsSnapshot(movements));
    repository
      ..onRefreshAccounts = accountsAnswer
      ..onRefreshMovements = movementsAnswer;
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        accountsTabRoute(now: () => now),
        accountDetailRoute(now: () => now),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AccountsRepository>.value(value: repository),
          RepositoryProvider<Telemetry>.value(value: InMemoryTelemetry()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ConnectivityCubit>(
              create: (_) => ConnectivityCubit(
                monitor: FakeConnectivityMonitor(),
              )..start(),
            ),
            BlocProvider<AccountsBloc>(
              create: (_) =>
                  AccountsBloc(repository: repository)
                    ..add(const AccountsStarted()),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => repository = FakeAccountsRepository());

  testWidgets('tapping an account opens it and follows its movements', (
    tester,
  ) async {
    await pumpRoutes(tester);

    await tester.tap(find.text('Cuenta corriente'));
    await tester.pumpAndSettle();

    expect(find.text('DISPONIBLE'), findsOneWidget);
    expect(find.text('Buscar movimientos'), findsOneWidget);
    expect(repository.movementListeners, [
      ('checking', MovementsBloc.defaultPageSize),
    ]);
  });

  testWidgets('going back returns to the accounts and stops following', (
    tester,
  ) async {
    await pumpRoutes(tester);
    await tester.tap(find.text('Cuenta de ahorros'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('SALDO TOTAL'), findsOneWidget);
    expect(repository.movements.hasListener, isFalse);
  });

  testWidgets('a link to an account the customer does not own leads back to '
      'the list', (tester) async {
    await pumpRoutes(
      tester,
      initialLocation: AccountsPaths.account('someone-else'),
    );

    expect(find.text('No encontramos esta cuenta'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('SALDO TOTAL'), findsOneWidget);
  });

  testWidgets('the back gesture of the device, on an account opened with '
      'nothing behind it, leads to the list instead of leaving the app', (
    tester,
  ) async {
    // How the result of a transfer opens the account: as the only screen.
    await pumpRoutes(
      tester,
      initialLocation: AccountsPaths.account('savings'),
    );
    expect(find.text('DISPONIBLE'), findsOneWidget);

    final left = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(left, isTrue, reason: 'the app handles it; it is not closed');
    expect(find.text('SALDO TOTAL'), findsOneWidget);
  });

  test('an account id is escaped when it becomes part of a location', () {
    expect(AccountsPaths.account('a/b c'), '/cuentas/a%2Fb%20c');
  });
}
