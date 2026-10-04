import 'package:banca_digital/app.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_saved_customer_data.dart';
import 'support/test_dependencies.dart';

void main() {
  const account = AuthAccount(uid: 'uid-1', email: 'valentina@example.com');
  const profile = UserProfile(
    uid: 'uid-1',
    email: 'valentina@example.com',
    fullName: 'Valentina Andrade',
    nationalId: '1710034065',
    phone: '0991234567',
    segment: Segment.starting,
    interests: {},
  );

  late FakeAuthRepository repository;
  late FakeBiometricAuthenticator biometrics;
  late FakeSavedCustomerData savedData;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      BancaDigitalApp(
        dependencies: TestDependencies(
          auth: repository,
          biometrics: biometrics,
          savedData: savedData,
        ).dependencies,
      ),
    );
  }

  setUp(() {
    repository = FakeAuthRepository();
    biometrics = FakeBiometricAuthenticator();
    savedData = FakeSavedCustomerData();
  });

  group('while the session is unknown', () {
    testWidgets('shows the product wordmark', (tester) async {
      await pumpApp(tester);

      expect(find.text('Banca Digital'), findsOneWidget);
    });

    testWidgets('is themed by the design system', (tester) async {
      await pumpApp(tester);

      final context = tester.element(find.text('Banca Digital'));
      final wordmark = tester.widget<Text>(find.text('Banca Digital'));

      expect(Theme.of(context).extension<AppSemanticColors>(), isNotNull);
      expect(wordmark.style!.fontFamily, AppTypography.display.fontFamily);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.surface0,
      );
    });

    testWidgets('shows progress under the wordmark', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
      handle.dispose();
    });
  });

  group('signed out', () {
    testWidgets('lands on the welcome screen', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(find.text('Tu banco, sin filas ni sucursales'), findsOneWidget);
    });

    testWidgets('removes what an earlier use of the app left on the device', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(savedData.clears, 1);
    });

    testWidgets('reaches the login from the welcome and comes back', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ya soy cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Hola de nuevo'), findsOneWidget);

      // The login screen has no back button of its own, as in the design;
      // the customer goes back with the system gesture.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Tu banco, sin filas ni sucursales'), findsOneWidget);
    });

    testWidgets('reaches the sign-up from the welcome', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir mi cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Paso 1 de 3'), findsOneWidget);
    });

    testWidgets('enters the app when the session becomes active', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya soy cliente'));
      await tester.pumpAndSettle();

      repository.announce(const ActiveSession(profile, unlockRequired: false));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Valentina'), findsOneWidget);
      expect(find.text('Hola de nuevo'), findsNothing);
    });
  });

  group('signed in', () {
    setUp(
      () => repository.restored = const ActiveSession(
        profile,
        unlockRequired: false,
      ),
    );

    testWidgets('greets the customer by first name', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(find.text('Hola, Valentina'), findsOneWidget);
    });

    testWidgets('keeps the saved data of a session that is still open', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(savedData.clears, 0);
    });

    testWidgets('returns to the welcome after signing out', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.text('Tu banco, sin filas ni sucursales'), findsOneWidget);
    });
  });

  testWidgets('holds a restored session behind the biometric check and '
      'enters once it passes', (tester) async {
    repository.restored = const ActiveSession(profile, unlockRequired: true);
    biometrics.passes = false;
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Hola de nuevo, Valentina'), findsOneWidget);
    expect(find.text('Hola, Valentina'), findsNothing);

    biometrics.passes = true;
    await tester.tap(find.text('Ingresar con huella o rostro'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Valentina'), findsOneWidget);
  });

  testWidgets('sends an account without profile to complete it, with what '
      'could not be stored', (tester) async {
    repository.restored = const IncompleteSession(
      account,
      unsavedDraft: ProfileDraft(
        fullName: 'Valentina Andrade',
        nationalId: '1710034065',
        phone: '0991234567',
      ),
    );
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Completa tu perfil'), findsOneWidget);
    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.text('1710034065'), findsOneWidget);
    expect(find.text('valentina@example.com'), findsOneWidget);
  });

  testWidgets('offers to retry when the profile cannot be loaded', (
    tester,
  ) async {
    repository
      ..restored = const UnavailableSession(account)
      ..retried = const ActiveSession(profile, unlockRequired: false);
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tu información'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Valentina'), findsOneWidget);
  });
}
