import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:banca_digital/app.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  late FakeAuthRepository auth;
  late FakeAccountsRepository accounts;
  late List<String> customersAskedFor;

  Future<void> pumpSignedIn(WidgetTester tester) async {
    auth.restored = const ActiveSession(profile, unlockRequired: false);
    final syncedAt = DateTime(2026, 10, 3, 10);
    Future<Result<DataSnapshot<List<Account>>>> accountsAnswer() async =>
        Success(
          DataSnapshot(
            value: const [savings],
            origin: DataOrigin.server,
            syncedAt: syncedAt,
          ),
        );
    Future<Result<DataSnapshot<List<Movement>>>> movementsAnswer() async =>
        Success(
          DataSnapshot(
            value: const [],
            origin: DataOrigin.server,
            syncedAt: syncedAt,
          ),
        );
    accounts
      ..onRefreshAccounts = accountsAnswer
      ..onRefreshMovements = movementsAnswer;

    await tester.pumpWidget(
      BancaDigitalApp(
        dependencies: AppDependencies(
          telemetry: InMemoryTelemetry(),
          connectivity: ConnectivityCubit(monitor: FakeConnectivityMonitor())
            ..start(),
          authRepository: auth,
          biometrics: FakeBiometricAuthenticator(),
          accountsRepositoryFor: (uid) {
            customersAskedFor.add(uid);
            return accounts;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder destination(String label) => find.descendant(
    of: find.byType(AppBottomNavigation),
    matching: find.text(label),
  );

  int currentDestination(WidgetTester tester) => tester
      .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
      .currentIndex;

  setUp(() {
    auth = FakeAuthRepository();
    accounts = FakeAccountsRepository();
    customersAskedFor = [];
  });

  testWidgets('a signed-in customer lands on Inicio with the four sections', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    expect(find.text('Hola, Valentina'), findsOneWidget);
    for (final label in ['Inicio', 'Cuentas', 'Servicios', 'Perfil']) {
      expect(destination(label), findsOneWidget, reason: label);
    }
    expect(currentDestination(tester), 0);
  });

  testWidgets('reads the accounts of the customer who signed in', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    expect(customersAskedFor, ['uid-1']);
    expect(accounts.accountRefreshes, 1);
  });

  testWidgets('Cuentas shows the accounts and marks its section', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    await tester.tap(destination('Cuentas'));
    await tester.pumpAndSettle();

    expect(find.text('SALDO TOTAL'), findsOneWidget);
    expect(find.byType(AccountCard), findsOneWidget);
    expect(currentDestination(tester), 1);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('an account opens over the navigation and going back '
      'returns to its section', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(destination('Cuentas'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AccountCard));
    await tester.pumpAndSettle();

    expect(find.text('DISPONIBLE'), findsOneWidget);
    expect(find.byType(AppBottomNavigation), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('SALDO TOTAL'), findsOneWidget);
    expect(currentDestination(tester), 1);
  });

  testWidgets('Servicios says honestly that it is not built yet', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    await tester.tap(destination('Servicios'));
    await tester.pumpAndSettle();

    expect(find.text('Servicios'), findsNWidgets(2));
    expect(find.text('Estamos construyendo esta sección'), findsOneWidget);
    expect(currentDestination(tester), 2);
  });

  testWidgets('Perfil shows who is signed in and signs out', (tester) async {
    await pumpSignedIn(tester);

    await tester.tap(destination('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Valentina Andrade'), findsOneWidget);
    expect(currentDestination(tester), 3);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('Tu banco, sin filas ni sucursales'), findsOneWidget);
    expect(find.byType(AppBottomNavigation), findsNothing);
  });

  testWidgets('stops following the accounts once signed out', (tester) async {
    await pumpSignedIn(tester);
    expect(accounts.accounts.hasListener, isTrue);

    await tester.tap(destination('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(accounts.accounts.hasListener, isFalse);
  });
}
