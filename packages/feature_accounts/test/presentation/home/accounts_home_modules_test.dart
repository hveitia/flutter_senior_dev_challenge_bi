import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/presentation/home/total_balance_module.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/module_kit.dart';
import 'package:module_kit/testing.dart';

import '../../support/fixtures.dart';
import '../../support/pump_accounts.dart';

void main() {
  late FakeAccountsRepository repository;
  late InMemoryTelemetry telemetry;
  late RecordingModuleHost host;
  late FakeDestinationResolver destinations;
  late HomeModuleRegistry registry;
  late List<String> openedAccounts;

  const unavailable = Failed<MovementsSnapshot>(
    ServiceUnavailableFailure(ServiceIds.movements),
  );

  HomeModuleContext module(
    String type, {
    required Set<String> composedTypes,
    Map<String, Object?> props = const {},
  }) {
    return HomeModuleContext(
      id: type,
      type: type,
      props: props,
      destinations: destinations,
      host: host,
      composedTypes: composedTypes,
    );
  }

  /// Pumps the modules of [types], top to bottom, as the home would.
  Future<void> pumpModules(
    WidgetTester tester,
    List<String> types, {
    Map<String, Object?> props = const {},
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AccountsRepository>.value(value: repository),
          RepositoryProvider<Telemetry>.value(value: telemetry),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AccountsBloc>(
              create: (_) =>
                  AccountsBloc(repository: repository, telemetry: telemetry)
                    ..add(const AccountsStarted()),
            ),
            BlocProvider<AmountVisibilityCubit>(
              create: (_) => AmountVisibilityCubit(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: app!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  children: [
                    for (final type in types)
                      registry.builderFor(type)!(
                        context,
                        module(
                          type,
                          props: props,
                          composedTypes: types.toSet(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<Result<AccountsSnapshot>> bothAccounts() async =>
      Success(accountsSnapshot(const [savings, checking]));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  setUp(() {
    repository = FakeAccountsRepository();
    telemetry = InMemoryTelemetry();
    host = RecordingModuleHost();
    destinations = FakeDestinationResolver(
      available: {Destinations.accounts},
    );
    openedAccounts = [];
    registry = HomeModuleRegistry();
    registerAccountsHomeModules(
      registry,
      now: () => now,
      onOpenAccount: (context, accountId) => openedAccounts.add(accountId),
    );
  });

  test('registers the modules the accounts domain owns', () {
    expect(registry.types, {
      AccountsModuleTypes.totalBalance,
      AccountsModuleTypes.accountCarousel,
      AccountsModuleTypes.investmentSummary,
      AccountsModuleTypes.recentMovements,
    });
  });

  group('total balance', () {
    const types = [AccountsModuleTypes.totalBalance];

    testWidgets('shows what the accounts add up to', (tester) async {
      repository.onRefreshAccounts = () async =>
          Success(accountsSnapshot(const [savings, checking]));

      await pumpModules(tester, types);
      await settle(tester);

      expect(find.text('SALDO TOTAL'), findsOneWidget);
      expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);
      expect(
        host.statuses[AccountsModuleTypes.totalBalance],
        HomeModuleStatus.ready,
      );
    });

    testWidgets('waits with a placeholder while nothing has arrived', (
      tester,
    ) async {
      repository.onRefreshAccounts = () => Future.any([]);

      await pumpModules(tester, types);

      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(
        host.statuses[AccountsModuleTypes.totalBalance],
        HomeModuleStatus.waiting,
      );
    });

    testWidgets('says it failed and retries when asked', (tester) async {
      repository.onRefreshAccounts = () async => const Failed(TimeoutFailure());

      await pumpModules(tester, types);
      await settle(tester);

      expect(find.text('No pudimos cargar tu saldo'), findsOneWidget);
      expect(
        host.statuses[AccountsModuleTypes.totalBalance],
        HomeModuleStatus.failed,
      );

      await tester.tap(find.text('Reintentar'));
      await settle(tester);

      expect(repository.accountRefreshes, 2);
    });

    testWidgets('hides and shows the amounts with the eye', (tester) async {
      repository.onRefreshAccounts = () async =>
          Success(accountsSnapshot(const [savings, checking]));
      await pumpModules(tester, const [
        AccountsModuleTypes.totalBalance,
        AccountsModuleTypes.accountCarousel,
      ]);
      await settle(tester);

      await tester.tap(find.byTooltip('Ocultar montos'));
      await settle(tester);

      expect(find.text(r'$4,820.35', findRichText: true), findsNothing);
      expect(find.text(r'$3,570.35', findRichText: true), findsNothing);
      expect(find.text(AmountText.obscuredText), findsWidgets);

      await tester.tap(find.byTooltip('Mostrar montos'));
      await settle(tester);

      expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);
    });

    testWidgets('says how old saved data is', (tester) async {
      await pumpModules(tester, types);
      repository.accounts.add(
        accountsSnapshot(const [savings, checking], origin: DataOrigin.cache),
      );
      await settle(tester);

      expect(find.text('Actualizado hace 8 min'), findsOneWidget);
    });

    testWidgets('refreshes the accounts when the home is refreshed', (
      tester,
    ) async {
      repository.onRefreshAccounts = () async =>
          Success(accountsSnapshot(const [savings]));
      await pumpModules(tester, types);
      await settle(tester);

      final refreshed = host.refreshAll();
      await settle(tester);
      await refreshed;

      expect(repository.accountRefreshes, 2);
    });

    testWidgets('tells a customer without accounts that they are on the way', (
      tester,
    ) async {
      repository.onRefreshAccounts = () async =>
          Success(accountsSnapshot(const []));

      await pumpModules(tester, types);
      await settle(tester);

      expect(find.text('Estamos preparando tu cuenta'), findsOneWidget);
    });
  });

  group('account carousel', () {
    const types = [AccountsModuleTypes.accountCarousel];

    testWidgets('shows a card per account and opens the one tapped', (
      tester,
    ) async {
      repository.onRefreshAccounts = () async =>
          Success(accountsSnapshot(const [savings, checking]));

      await pumpModules(tester, types);
      await settle(tester);

      expect(find.byType(AccountCard), findsNWidgets(2));
      await tester.tap(find.text('Cuenta de ahorros'));

      expect(openedAccounts, ['savings']);
      expect(
        host.statuses[AccountsModuleTypes.accountCarousel],
        HomeModuleStatus.ready,
      );
    });

    testWidgets('with the balance above it, leaves a failure for the balance '
        'to say, and takes no space', (tester) async {
      repository.onRefreshAccounts = () async => const Failed(TimeoutFailure());

      await pumpModules(tester, const [
        AccountsModuleTypes.totalBalance,
        AccountsModuleTypes.accountCarousel,
      ]);
      await settle(tester);

      expect(find.byType(AccountCard), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('No pudimos cargar tu saldo'), findsOneWidget);
      expect(
        host.statuses[AccountsModuleTypes.accountCarousel],
        HomeModuleStatus.hidden,
      );
    });

    testWidgets('published without the balance, says the failure itself and '
        'retries when asked', (tester) async {
      repository.onRefreshAccounts = () async => const Failed(TimeoutFailure());

      await pumpModules(tester, types);
      await settle(tester);

      expect(find.text('No pudimos cargar tus cuentas'), findsOneWidget);
      expect(
        host.statuses[AccountsModuleTypes.accountCarousel],
        HomeModuleStatus.failed,
      );

      await tester.tap(find.text('Reintentar'));
      await settle(tester);

      expect(repository.accountRefreshes, 2);
    });

    testWidgets('takes no space for a customer without accounts', (
      tester,
    ) async {
      repository.onRefreshAccounts = () async =>
          Success(accountsSnapshot(const []));

      await pumpModules(tester, types);
      await settle(tester);

      expect(
        host.statuses[AccountsModuleTypes.accountCarousel],
        HomeModuleStatus.hidden,
      );
    });
  });

  group('recent movements', () {
    const types = [AccountsModuleTypes.recentMovements];

    testWidgets('lists the latest movements, as many as published', (
      tester,
    ) async {
      repository.onRefreshRecentMovements = () async =>
          Success(movementsSnapshot([salary, groceries]));

      await pumpModules(tester, types, props: const {'limit': 2});
      await settle(tester);

      expect(repository.recentListeners, [2]);
      expect(find.text('Últimos movimientos'), findsOneWidget);
      expect(find.text('Nómina de septiembre'), findsOneWidget);
      expect(find.text('Supermercado'), findsOneWidget);
      expect(
        host.statuses[AccountsModuleTypes.recentMovements],
        HomeModuleStatus.ready,
      );
    });

    for (final MapEntry(key: description, value: published) in {
      'missing': null,
      'zero': 0,
      'negative': -3,
      'a text': '7',
      'a fraction': 2.5,
      'a list': [3],
    }.entries) {
      testWidgets('uses its default when the published limit is $description', (
        tester,
      ) async {
        await pumpModules(tester, types, props: {'limit': ?published});

        expect(repository.recentListeners, [
          RecentMovementsModule.defaultLimit,
        ]);
      });
    }

    testWidgets('caps a huge published limit: the module is a summary', (
      tester,
    ) async {
      await pumpModules(tester, types, props: const {'limit': 9999999});

      expect(repository.recentListeners, [RecentMovementsModule.maxLimit]);
    });

    testWidgets('uses its default when the limit is missing or absurd', (
      tester,
    ) async {
      await pumpModules(tester, types, props: const {'limit': -3});

      expect(repository.recentListeners, [
        RecentMovementsModule.defaultLimit,
      ]);
    });

    testWidgets('fails alone: the balance and the accounts stay on screen', (
      tester,
    ) async {
      repository
        ..onRefreshAccounts = bothAccounts
        ..onRefreshRecentMovements = () async => unavailable;

      await pumpModules(tester, const [
        AccountsModuleTypes.totalBalance,
        AccountsModuleTypes.accountCarousel,
        AccountsModuleTypes.recentMovements,
      ]);
      await settle(tester);

      expect(find.text('No pudimos cargar tus movimientos'), findsOneWidget);
      expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);
      expect(find.byType(AccountCard), findsNWidgets(2));
      expect(host.statuses, {
        AccountsModuleTypes.totalBalance: HomeModuleStatus.ready,
        AccountsModuleTypes.accountCarousel: HomeModuleStatus.ready,
        AccountsModuleTypes.recentMovements: HomeModuleStatus.failed,
      });
    });

    testWidgets('recovers when the customer retries and the service is back', (
      tester,
    ) async {
      repository.onRefreshRecentMovements = () async => unavailable;
      await pumpModules(tester, types);
      await settle(tester);

      repository.onRefreshRecentMovements = () async =>
          Success(movementsSnapshot([salary]));
      await tester.tap(find.text('Reintentar'));
      await settle(tester);

      expect(find.text('No pudimos cargar tus movimientos'), findsNothing);
      expect(find.text('Nómina de septiembre'), findsOneWidget);
    });

    testWidgets('keeps saved movements on screen when a refresh fails', (
      tester,
    ) async {
      repository.onRefreshRecentMovements = () async => unavailable;
      await pumpModules(tester, types);
      repository.recentMovements.add(
        movementsSnapshot([salary], origin: DataOrigin.cache),
      );
      await settle(tester);

      expect(find.text('Nómina de septiembre'), findsOneWidget);
      expect(find.textContaining('No pudimos actualizar'), findsOneWidget);
      expect(find.text('Actualizado hace 8 min'), findsOneWidget);
    });

    testWidgets('offers to see them all only when the app can take there', (
      tester,
    ) async {
      repository.onRefreshRecentMovements = () async =>
          Success(movementsSnapshot([salary]));
      await pumpModules(tester, types);
      await settle(tester);

      await tester.tap(find.text('Ver todos'));
      expect(destinations.opened, [Destinations.accounts]);

      destinations.available.clear();
      await pumpModules(tester, types);
      await settle(tester);

      expect(find.text('Ver todos'), findsNothing);
    });

    testWidgets('says so when there are no movements yet', (tester) async {
      repository.onRefreshRecentMovements = () async =>
          Success(movementsSnapshot(const []));

      await pumpModules(tester, types);
      await settle(tester);

      expect(find.text('Aún no tienes movimientos'), findsOneWidget);
    });
  });

  group('balance trend', () {
    const types = [AccountsModuleTypes.totalBalance];
    const withTrend = {'trendDays': 30};

    // Today +$1,850.00 and -$64.80: yesterday closed $1,785.20 lower.
    Future<Result<MovementsSnapshot>> twoToday() async =>
        Success(movementsSnapshot([salary, groceries]));

    testWidgets('is not asked for, nor drawn, unless the configuration '
        'publishes a period', (tester) async {
      repository.onRefreshAccounts = bothAccounts;

      await pumpModules(tester, types);
      await settle(tester);

      expect(find.byType(TrendLine), findsNothing);
      expect(repository.sinceRequests, isEmpty);
    });

    testWidgets('draws how the money that can be spent moved over the '
        'period, ending at the balance on screen', (tester) async {
      repository
        ..onRefreshAccounts = bothAccounts
        ..onMovementsSince = twoToday;

      await pumpModules(tester, types, props: withTrend);
      await settle(tester);

      final line = tester.widget<TrendLine>(find.byType(TrendLine));
      expect(line.values, hasLength(30));
      expect(line.values.last, 482035);
      expect(line.values[28], 482035 - 185000 + 6480);
      expect(find.text('Tus cuentas, últimos 30 días'), findsOneWidget);
    });

    testWidgets('leaves the investments out of the line even when the total '
        'includes them: nothing says how they moved', (tester) async {
      repository
        ..onRefreshAccounts = () async {
          return Success(accountsSnapshot(const [savings, checking, fund]));
        }
        ..onMovementsSince = twoToday;

      await pumpModules(
        tester,
        types,
        props: const {'trendDays': 30, 'includesInvestments': true},
      );
      await settle(tester);

      expect(find.text(r'$29,420.35', findRichText: true), findsOneWidget);
      expect(
        tester.widget<TrendLine>(find.byType(TrendLine)).values.last,
        482035,
      );
    });

    testWidgets('says the amounts it runs between to a screen reader, and '
        'not when the customer hid the amounts', (tester) async {
      repository
        ..onRefreshAccounts = bothAccounts
        ..onMovementsSince = twoToday;

      await pumpModules(tester, types, props: withTrend);
      await settle(tester);
      expect(
        tester.widget<TrendLine>(find.byType(TrendLine)).semanticLabel,
        'Tendencia de tus cuentas en los últimos 30 días: de 3035 dólares '
        'con 15 centavos a 4820 dólares con 35 centavos',
      );

      await tester.tap(find.byTooltip('Ocultar montos'));
      await tester.pump();
      expect(
        tester.widget<TrendLine>(find.byType(TrendLine)).semanticLabel,
        'Tendencia de tus cuentas en los últimos 30 días',
      );
    });

    testWidgets('draws nothing and keeps the balance when its movements '
        'cannot be read', (tester) async {
      repository
        ..onRefreshAccounts = bothAccounts
        ..onMovementsSince = () async {
          return const Failed(ServiceUnavailableFailure(ServiceIds.movements));
        };

      await pumpModules(tester, types, props: withTrend);
      await settle(tester);

      expect(find.byType(TrendLine), findsNothing);
      expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(
        host.statuses[AccountsModuleTypes.totalBalance],
        HomeModuleStatus.ready,
      );
    });

    testWidgets('reads the movements again when the home is refreshed', (
      tester,
    ) async {
      repository
        ..onRefreshAccounts = bothAccounts
        ..onMovementsSince = twoToday;
      await pumpModules(tester, types, props: withTrend);
      await settle(tester);

      await host.refreshAll();

      expect(repository.sinceRequests, hasLength(2));
    });

    for (final MapEntry(key: description, value: published) in {
      'a text': '30',
      'a single day': 1,
      'negative': -30,
      'a fraction': 7.5,
    }.entries) {
      testWidgets('is not drawn when the published period is $description', (
        tester,
      ) async {
        repository.onRefreshAccounts = bothAccounts;

        await pumpModules(tester, types, props: {'trendDays': published});
        await settle(tester);

        expect(find.byType(TrendLine), findsNothing);
        expect(repository.sinceRequests, isEmpty);
      });
    }

    testWidgets('caps a huge published period', (tester) async {
      repository
        ..onRefreshAccounts = bothAccounts
        ..onMovementsSince = twoToday;

      await pumpModules(tester, types, props: const {'trendDays': 5000});
      await settle(tester);

      expect(
        tester.widget<TrendLine>(find.byType(TrendLine)).values,
        hasLength(TotalBalanceModule.maxTrendDays),
      );
    });
  });

  group('with investments', () {
    Future<Result<AccountsSnapshot>> withFund() async =>
        Success(accountsSnapshot(const [savings, checking, fund]));

    testWidgets('the total is the money the customer can spend, unless the '
        'configuration asks to include what is invested', (tester) async {
      repository.onRefreshAccounts = withFund;

      await pumpModules(tester, const [AccountsModuleTypes.totalBalance]);
      await settle(tester);
      expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);

      await pumpModules(
        tester,
        const [AccountsModuleTypes.totalBalance],
        props: const {'includesInvestments': true},
      );
      await settle(tester);
      expect(find.text(r'$29,420.35', findRichText: true), findsOneWidget);
    });

    testWidgets('the carousel shows the spending accounts only', (
      tester,
    ) async {
      repository.onRefreshAccounts = withFund;

      await pumpModules(tester, const [AccountsModuleTypes.accountCarousel]);
      await settle(tester);

      expect(find.byType(AccountCard), findsNWidgets(2));
      expect(find.text('Fondo de inversión'), findsNothing);
    });

    testWidgets('the investments module says what is invested, product by '
        'product', (tester) async {
      repository.onRefreshAccounts = withFund;

      await pumpModules(tester, const [AccountsModuleTypes.investmentSummary]);
      await settle(tester);

      expect(find.text('Inversiones'), findsOneWidget);
      expect(find.text('Fondo de inversión'), findsOneWidget);
      expect(find.text(r'$24,600.00', findRichText: true), findsWidgets);
      expect(
        host.statuses[AccountsModuleTypes.investmentSummary],
        HomeModuleStatus.ready,
      );
    });

    testWidgets('the investments module hides its amounts with the eye', (
      tester,
    ) async {
      repository.onRefreshAccounts = withFund;

      await pumpModules(tester, const [
        AccountsModuleTypes.totalBalance,
        AccountsModuleTypes.investmentSummary,
      ]);
      await settle(tester);
      await tester.tap(find.byTooltip('Ocultar montos'));
      await tester.pump();

      expect(find.text(r'$24,600.00', findRichText: true), findsNothing);
    });

    testWidgets('the investments module takes no space for a customer '
        'without investments', (tester) async {
      repository.onRefreshAccounts = bothAccounts;

      await pumpModules(tester, const [AccountsModuleTypes.investmentSummary]);
      await settle(tester);

      expect(find.text('Inversiones'), findsNothing);
      expect(
        host.statuses[AccountsModuleTypes.investmentSummary],
        HomeModuleStatus.hidden,
      );
    });

    testWidgets('the investments module leaves a failure for the balance to '
        'say', (tester) async {
      repository.onRefreshAccounts = () async => const Failed(TimeoutFailure());

      await pumpModules(tester, const [
        AccountsModuleTypes.totalBalance,
        AccountsModuleTypes.investmentSummary,
      ]);
      await settle(tester);

      expect(find.text('Reintentar'), findsOneWidget);
      expect(
        host.statuses[AccountsModuleTypes.investmentSummary],
        HomeModuleStatus.hidden,
      );
    });

    testWidgets('the investments module says the failure itself when '
        'published without the balance', (tester) async {
      repository.onRefreshAccounts = () async => const Failed(TimeoutFailure());

      await pumpModules(tester, const [AccountsModuleTypes.investmentSummary]);
      await settle(tester);

      expect(find.text('No pudimos cargar tus inversiones'), findsOneWidget);
      expect(
        host.statuses[AccountsModuleTypes.investmentSummary],
        HomeModuleStatus.failed,
      );
    });

    testWidgets('the investments module takes to the accounts when the app '
        'can', (tester) async {
      repository.onRefreshAccounts = withFund;

      await pumpModules(tester, const [AccountsModuleTypes.investmentSummary]);
      await settle(tester);
      await tester.tap(find.text('Ver inversiones'));

      expect(destinations.opened, [Destinations.accounts]);
    });
  });

  testWidgets('the three modules fit a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = smallPhone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository
      ..onRefreshAccounts = bothAccounts
      ..onRefreshRecentMovements = () async {
        return Success(movementsSnapshot(movements));
      };

    await pumpModules(tester, const [
      AccountsModuleTypes.totalBalance,
      AccountsModuleTypes.accountCarousel,
      AccountsModuleTypes.recentMovements,
    ], textScale: largeText);
    await settle(tester);

    expect(tester.takeException(), isNull);
  });
}
