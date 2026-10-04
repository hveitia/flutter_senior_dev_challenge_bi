import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_dependencies.dart';

void main() {
  const profile = UserProfile(
    uid: 'uid-1',
    email: 'valentina@example.com',
    fullName: 'Valentina Andrade',
    nationalId: '1710034065',
    phone: '0991234567',
    segment: Segment.starting,
    interests: {},
  );
  const savings = Account(
    id: 'savings',
    name: 'Cuenta de ahorros',
    kind: AccountKind.savings,
    number: '22004821',
    availableCents: 357035,
    ledgerCents: 357035,
    currency: 'USD',
  );
  final syncedAt = DateTime(2026, 10, 3, 10);
  final salary = Movement(
    id: 'salary',
    accountId: 'savings',
    description: 'Nómina de septiembre',
    category: MovementCategory.salary,
    amountCents: 185000,
    postedAt: DateTime(2026, 10, 3, 9, 12),
    reference: 'MOV-1',
    channel: MovementChannel.payroll,
    status: MovementStatus.completed,
  );

  late FakeAccountsRepository accounts;
  late TestDependencies app;

  Future<Result<DataSnapshot<List<Account>>>> accountsAnswer() async => Success(
    DataSnapshot(
      value: const [savings],
      origin: DataOrigin.server,
      syncedAt: syncedAt,
    ),
  );

  Future<Result<DataSnapshot<List<Movement>>>> movementsAnswer() async =>
      Success(
        DataSnapshot(
          value: [salary],
          origin: DataOrigin.server,
          syncedAt: syncedAt,
        ),
      );

  Future<void> pumpApp(WidgetTester tester, {bool signedIn = true}) async {
    accounts
      ..onRefreshAccounts = accountsAnswer
      ..onRefreshRecentMovements = movementsAnswer;
    app = TestDependencies(accountsRepositoryFor: (_) => accounts);
    if (signedIn) {
      app.auth.restored = const ActiveSession(profile, unlockRequired: false);
    }

    await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
    await tester.pumpAndSettle();
  }

  Finder destination(String label) => find.descendant(
    of: find.byType(AppBottomNavigation),
    matching: find.text(label),
  );

  Future<void> signOut(WidgetTester tester) async {
    await tester.tap(destination('Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
  }

  setUp(() => accounts = FakeAccountsRepository());

  group('the home', () {
    testWidgets('is drawn from the configuration, by the modules each '
        'domain registered', (tester) async {
      await pumpApp(tester);

      expect(find.text('Hola, Valentina'), findsOneWidget);
      expect(find.text('SALDO TOTAL'), findsOneWidget);
      expect(find.byType(AccountCard), findsOneWidget);
      expect(find.text('Últimos movimientos'), findsOneWidget);
      expect(find.text('Nómina de septiembre'), findsOneWidget);
    });

    testWidgets('changes when a new configuration is published, without '
        'restarting', (tester) async {
      await pumpApp(tester);

      app.config.publish(
        homeDocument(
          configVersion: 15,
          modules: [
            moduleDocument('movements', 'recentMovements'),
            moduleDocument('balance', 'totalBalance'),
            moduleDocument('accounts', 'accountCarousel', visible: false),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccountCard), findsNothing);
      expect(
        tester.getTopLeft(find.text('Últimos movimientos')).dy,
        lessThan(tester.getTopLeft(find.text('SALDO TOTAL')).dy),
      );
    });

    testWidgets('offers the actions this build can open, transfers among '
        'them', (tester) async {
      await pumpApp(tester);

      expect(find.text('Pagar'), findsOneWidget);
      expect(find.text('Transferir'), findsOneWidget);

      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Productos del banco y de nuestros aliados'),
        findsOneWidget,
      );
    });

    testWidgets('takes to the accounts from the latest movements', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.ensureVisible(find.text('Ver todos'));
      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .currentIndex,
        1,
      );
    });
  });

  group('personalization', () {
    final twoSegments = {
      ...homeDocument(
        modules: [
          moduleDocument('balance', 'totalBalance'),
          moduleDocument('accounts', 'accountCarousel'),
        ],
      ),
    };
    (twoSegments['segments']! as Map<String, Object?>)['wealth'] = {
      'label': 'Patrimonio',
      'modules': [
        moduleDocument('movements', 'recentMovements'),
        moduleDocument('balance', 'totalBalance'),
      ],
      'features': {'transfers': true, 'partnerServices': true},
    };

    testWidgets('Perfil says which segment the home is composed for', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(destination('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Estoy empezando'), findsOneWidget);
      expect(find.text('Personalización'), findsOneWidget);
    });

    testWidgets('a customer who changes their segment in Perfil gets the '
        'home of the new one, without signing in again', (tester) async {
      await pumpApp(tester);
      app.auth.signedInProfile = profile;
      app.config.publish(twoSegments);
      await tester.pumpAndSettle();
      expect(find.byType(AccountCard), findsOneWidget);
      expect(find.text('Últimos movimientos'), findsNothing);

      await tester.tap(destination('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis intereses'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Patrimonio'));
      await tester.tap(find.text('Patrimonio'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      // Back in Perfil, which now names the new segment.
      expect(find.text('Guardar cambios'), findsNothing);
      expect(find.text('Patrimonio'), findsOneWidget);

      await tester.tap(destination('Inicio'));
      await tester.pumpAndSettle();

      expect(find.text('Últimos movimientos'), findsOneWidget);
      expect(find.byType(AccountCard), findsNothing);
      expect(app.auth.signOutCalls, 0);
    });
  });

  group('the published configuration', () {
    testWidgets('is not listened to before a customer signs in', (
      tester,
    ) async {
      await pumpApp(tester, signedIn: false);

      expect(app.config.subscriptions, 0);
    });

    testWidgets('is listened to during the session and no longer after it', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(app.config.hasListener, isTrue);

      await signOut(tester);

      expect(app.config.hasListener, isFalse);
    });
  });

  group('the faults of the resilience lab', () {
    testWidgets('reach the policy as soon as they are published', (
      tester,
    ) async {
      await pumpApp(tester);

      app.config.publish(
        homeDocument(
          configVersion: 15,
          latencyMs: 5000,
          movementsUnavailable: true,
          modules: [moduleDocument('balance', 'totalBalance')],
        ),
      );
      await tester.pumpAndSettle();

      expect(app.faults.current.latency, const Duration(seconds: 5));
      expect(app.faults.current.isUnavailable(ServiceIds.movements), isTrue);
    });

    testWidgets('are lifted when the session ends', (tester) async {
      await pumpApp(tester);
      app.config.publish(
        homeDocument(
          movementsUnavailable: true,
          modules: [moduleDocument('balance', 'totalBalance')],
        ),
      );
      await tester.pumpAndSettle();

      await signOut(tester);

      expect(app.faults.current, same(ResilienceSettings.none));
    });
  });

  group('the diagnostics in Perfil', () {
    testWidgets('state the configuration in use and the build', (tester) async {
      await pumpApp(tester);

      await tester.tap(destination('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('DIAGNÓSTICO'), findsOneWidget);
      expect(find.text('En línea'), findsOneWidget);
      expect(find.text('v14 · incluida en la app'), findsOneWidget);
      expect(find.text('1.0.0 (12)'), findsOneWidget);
    });

    testWidgets('follow a newly published configuration', (tester) async {
      await pumpApp(tester);
      await tester.tap(destination('Perfil'));
      await tester.pumpAndSettle();

      app.config.publish(
        homeDocument(
          configVersion: 15,
          modules: [moduleDocument('balance', 'totalBalance')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('v15 · publicada'), findsOneWidget);
    });
  });
}
