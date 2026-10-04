import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:banca_digital/app.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_saved_customer_data.dart';
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

  late FakeAuthRepository auth;
  late FakeAccountsRepository accounts;
  late List<String> customersAskedFor;
  late FakeSavedCustomerData savedData;
  late InMemoryTelemetry telemetry;
  late TestDependencies app;

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

    app = TestDependencies(
      auth: auth,
      telemetry: telemetry,
      savedData: savedData,
      accountsRepositoryFor: (uid) {
        customersAskedFor.add(uid);
        return accounts;
      },
    );
    await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
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
    savedData = FakeSavedCustomerData();
    telemetry = InMemoryTelemetry();
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

  testWidgets('Servicios lists what the bank and its partners offer', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    await tester.tap(destination('Servicios'));
    await tester.pumpAndSettle();

    expect(find.text('Servicios'), findsNWidgets(2));
    expect(
      find.text('Productos del banco y de nuestros aliados'),
      findsOneWidget,
    );
    expect(currentDestination(tester), 2);
  });

  testWidgets('Perfil shows who is signed in and signs out', (tester) async {
    await pumpSignedIn(tester);

    await tester.tap(destination('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Valentina Andrade'), findsOneWidget);
    expect(currentDestination(tester), 3);

    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('Tu banco, sin filas ni sucursales'), findsOneWidget);
    expect(find.byType(AppBottomNavigation), findsNothing);
  });

  testWidgets('stops reading the published configuration before the session '
      'is closed, so closing it is not reported as a failed read', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    expect(app.config.hasListener, isTrue);
    bool? listeningWhenSessionClosed;
    auth.onSignOut = () => listeningWhenSessionClosed = app.config.hasListener;

    await tester.tap(destination('Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(listeningWhenSessionClosed, isFalse);
    expect(auth.signOutCalls, 1);
  });

  group('with transfers queued without a connection', () {
    Future<void> askToSignOut(
      WidgetTester tester, {
      List<QueuedTransfer> queued = const [
        QueuedTransfer(id: 'order-0000000000000001', amountCents: 15010),
      ],
    }) async {
      await pumpSignedIn(tester);
      app.transfers.queued.add(queued);
      await tester.pump();
      await tester.tap(destination('Perfil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
    }

    testWidgets('closing the session warns that they would be discarded, and '
        'staying keeps the session open', (tester) async {
      await askToSignOut(tester);

      expect(find.text('Tienes transferencias sin enviar'), findsOneWidget);

      await tester.tap(find.text('Seguir aquí'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 0);
      expect(find.byType(AppBottomNavigation), findsOneWidget);
    });

    testWidgets('says that an order existing only on this phone is discarded', (
      tester,
    ) async {
      await askToSignOut(tester);

      expect(
        find.text(
          'Tienes 1 transferencia que solo existe en este teléfono. Si '
          'cierras sesión ahora, se descarta y no se enviará.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cerrar sesión y descartar'), findsOneWidget);
    });

    testWidgets('does not promise to discard an order the bank already has: '
        'it says it will be carried out', (tester) async {
      await askToSignOut(
        tester,
        queued: const [
          QueuedTransfer(
            id: 'order-0000000000000001',
            amountCents: 15010,
            isDelivered: true,
          ),
        ],
      );

      expect(
        find.text(
          'El banco ya recibió 1 transferencia. No se descarta: se '
          'completará cuando vuelvas a iniciar sesión.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cerrar sesión y descartar'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
    });

    testWidgets('with both kinds, says what happens to each', (tester) async {
      await askToSignOut(
        tester,
        queued: const [
          QueuedTransfer(
            id: 'order-0000000000000001',
            amountCents: 15010,
            isDelivered: true,
          ),
          QueuedTransfer(id: 'order-0000000000000002', amountCents: 100),
          QueuedTransfer(id: 'order-0000000000000003', amountCents: 200),
        ],
      );

      expect(
        find.text(
          'Tienes 2 transferencias que solo existen en este teléfono. Si '
          'cierras sesión ahora, se descartan y no se enviarán.\n\n'
          'El banco ya recibió 1 transferencia. No se descarta: se '
          'completará cuando vuelvas a iniciar sesión.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cerrar sesión y descartar'), findsOneWidget);
    });

    testWidgets('the session closes only when the customer says to discard '
        'them', (tester) async {
      await askToSignOut(tester);

      await tester.tap(find.text('Cerrar sesión y descartar'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
    });
  });

  testWidgets('stops following the accounts once signed out', (tester) async {
    await pumpSignedIn(tester);
    expect(accounts.accounts.hasListener, isTrue);

    await tester.tap(destination('Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(accounts.accounts.hasListener, isFalse);
  });

  group('once signed out', () {
    Future<void> signOut(WidgetTester tester) async {
      await tester.tap(destination('Perfil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
    }

    testWidgets('removes what the device saved, after the listeners on it '
        'are gone', (tester) async {
      await pumpSignedIn(tester);
      final followingAtClear = <bool>[];
      savedData.onClear = () =>
          followingAtClear.add(accounts.accounts.hasListener);

      await signOut(tester);

      expect(savedData.clears, 1);
      expect(followingAtClear, [false]);
    });

    testWidgets('leaves the customer signed out even when the saved data '
        'cannot be removed, and reports it', (tester) async {
      await pumpSignedIn(tester);
      savedData.failsWith = StateError('uid-1 database busy');

      await signOut(tester);

      expect(find.text('Tu banco, sin filas ni sucursales'), findsOneWidget);
      final report = telemetry.errors.single;
      expect(report.error, isA<RedactedError>());
      expect(report.error.toString(), isNot(contains('uid-1')));
    });

    testWidgets('the same customer can sign in again and sees their '
        'accounts', (tester) async {
      await pumpSignedIn(tester);
      await signOut(tester);

      auth.announce(const ActiveSession(profile, unlockRequired: false));
      await tester.pumpAndSettle();
      await tester.tap(destination('Cuentas'));
      await tester.pumpAndSettle();

      expect(customersAskedFor, ['uid-1', 'uid-1']);
      expect(accounts.accountRefreshes, 2);
      expect(find.byType(AccountCard), findsOneWidget);
      expect(savedData.clears, 1);
    });
  });
}
