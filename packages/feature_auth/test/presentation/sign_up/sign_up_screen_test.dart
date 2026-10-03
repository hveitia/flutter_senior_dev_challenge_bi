import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_cubit.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_screen.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/pump_auth.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeBiometricAuthenticator biometrics;
  var leaves = 0;
  var signOuts = 0;

  Future<void> pumpNewAccount(
    WidgetTester tester, {
    bool online = true,
    double textScale = 1,
  }) async {
    final cubit = SignUpCubit.newAccount(
      repository: repository,
      biometrics: biometrics,
    );
    await cubit.start();
    await pumpAuth(
      tester,
      SignUpScreen(onLeave: () => leaves++),
      providers: [BlocProvider<SignUpCubit>.value(value: cubit)],
      online: online,
      textScale: textScale,
    );
    addTearDown(cubit.close);
  }

  Future<void> pumpCompletion(
    WidgetTester tester, {
    ProfileDraft? unsavedDraft,
  }) async {
    await pumpAuth(
      tester,
      SignUpScreen(onSignOut: () => signOuts++),
      providers: [
        BlocProvider<SignUpCubit>(
          create: (_) => SignUpCubit.completeProfile(
            repository: repository,
            email: email,
            unsavedDraft: unsavedDraft,
          ),
        ),
      ],
    );
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(AppTextField, label),
    matching: find.byType(TextField),
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> fillPersonalData(WidgetTester tester) async {
    await tester.enterText(field('Cédula'), draft.nationalId);
    await tester.enterText(field('Nombres y apellidos'), draft.fullName);
    if (tester.widget<TextField>(field('Correo electrónico')).enabled ?? true) {
      await tester.enterText(field('Correo electrónico'), email);
    }
    await tester.enterText(field('Celular'), '099 123 4567');
  }

  Future<void> reachInterests(WidgetTester tester) async {
    await fillPersonalData(tester);
    await tap(tester, find.text('Continuar'));
  }

  Future<void> reachAccess(WidgetTester tester) async {
    await reachInterests(tester);
    await tap(tester, find.text('Ahorrar'));
    await tap(tester, find.text('Viajar'));
    await tap(tester, find.text('Familia'));
    await tap(tester, find.text('Continuar'));
  }

  setUp(() {
    repository = FakeAuthRepository();
    biometrics = FakeBiometricAuthenticator();
    leaves = 0;
    signOuts = 0;
  });

  group('step 1', () {
    testWidgets('shows where the customer is in the flow', (tester) async {
      await pumpNewAccount(tester);

      expect(find.text('Abre tu cuenta'), findsOneWidget);
      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Tus datos'), findsOneWidget);
    });

    testWidgets('explains under each field what is wrong with it', (
      tester,
    ) async {
      await pumpNewAccount(tester);
      await tester.enterText(field('Cédula'), '123456789');

      await tap(tester, find.text('Continuar'));

      expect(
        find.text('Ingresa una cédula válida de 10 dígitos'),
        findsOneWidget,
      );
      expect(find.text('Ingresa tus nombres y apellidos'), findsOneWidget);
      expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
      expect(
        find.text('Ingresa un celular válido de 10 dígitos'),
        findsOneWidget,
      );
      expect(find.text('Paso 1 de 3'), findsOneWidget);
      // Errors are part of the form, never a transient message.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('accepts only digits in the cédula, ten at most', (
      tester,
    ) async {
      await pumpNewAccount(tester);

      await tester.enterText(field('Cédula'), '17a1003-40650000');

      expect(find.text('1710034065'), findsOneWidget);
    });

    testWidgets('leaves the flow when going back from the first step', (
      tester,
    ) async {
      await pumpNewAccount(tester);

      await tester.tap(find.byTooltip('Volver'));

      expect(leaves, 1);
    });

    testWidgets('says there is no connection before the customer tries', (
      tester,
    ) async {
      await pumpNewAccount(tester, online: false);

      expect(
        find.widgetWithText(
          InlineAlert,
          'Sin conexión. Revisa tu red e intenta de nuevo',
        ),
        findsOneWidget,
      );
    });
  });

  group('step 2', () {
    testWidgets('asks for interests and segment', (tester) async {
      await pumpNewAccount(tester);

      await reachInterests(tester);

      expect(find.text('Paso 2 de 3'), findsOneWidget);
      expect(find.text('Cuéntanos qué te interesa'), findsOneWidget);
      expect(find.byType(AppChip), findsNWidgets(Interest.values.length));
      expect(find.byType(RadioCard), findsNWidgets(Segment.values.length));
    });

    testWidgets('starts with "Estoy empezando" chosen and marks one segment '
        'at a time', (tester) async {
      await pumpNewAccount(tester);
      await reachInterests(tester);

      RadioCard card(String label) =>
          tester.widget<RadioCard>(find.widgetWithText(RadioCard, label));

      expect(card('Estoy empezando').selected, isTrue);

      await tap(tester, find.text('Patrimonio'));

      expect(card('Patrimonio').selected, isTrue);
      expect(card('Estoy empezando').selected, isFalse);
    });

    testWidgets('returns to step 1 with every answer still there', (
      tester,
    ) async {
      await pumpNewAccount(tester);
      await reachInterests(tester);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pump();

      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.text(draft.nationalId), findsOneWidget);
      expect(find.text(draft.fullName), findsOneWidget);
      expect(find.text(email), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Celular')).controller!.text,
        '099 123 4567',
      );
      expect(leaves, 0);
    });

    testWidgets('can be skipped', (tester) async {
      await pumpNewAccount(tester);
      await reachInterests(tester);

      await tap(tester, find.text('Omitir por ahora'));

      expect(find.text('Paso 3 de 3'), findsOneWidget);
    });
  });

  group('step 3', () {
    testWidgets('ticks each password requirement as it is met', (tester) async {
      await pumpNewAccount(tester);
      await reachAccess(tester);

      await tester.enterText(field('Contraseña'), 'Segura12');
      await tester.pump();

      RequirementItem item(String label) => tester.widget<RequirementItem>(
        find.widgetWithText(RequirementItem, label),
      );
      expect(item('Al menos 8 caracteres').met, isTrue);
      expect(item('Una letra mayúscula').met, isTrue);
      expect(item('Un número').met, isTrue);
      expect(item('Un símbolo').met, isFalse);
    });

    testWidgets('keeps the button disabled until the password complies and '
        'the terms are accepted', (tester) async {
      await pumpNewAccount(tester);
      await reachAccess(tester);

      AppButton create() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Crear mi cuenta'),
      );
      expect(create().onPressed, isNull);

      await tester.enterText(field('Contraseña'), password);
      await tester.pump();
      expect(create().onPressed, isNull);

      await tap(tester, find.byType(Checkbox));
      expect(create().onPressed, isNotNull);
    });

    testWidgets('creates the account with every answer of the three steps', (
      tester,
    ) async {
      await pumpNewAccount(tester);
      await reachAccess(tester);
      await tester.enterText(field('Contraseña'), password);
      await tap(tester, find.byType(Checkbox));

      await tap(tester, find.text('Crear mi cuenta'));

      final request = repository.signUps.single;
      expect(request.email, email);
      expect(request.password, password);
      expect(request.profile, draft);
      expect(request.biometricUnlock, isTrue);
    });

    testWidgets('offers biometric unlock only on a device that has it', (
      tester,
    ) async {
      biometrics.available = false;
      await pumpNewAccount(tester);

      await reachAccess(tester);

      expect(find.byType(ToggleRow), findsNothing);
    });

    testWidgets('shows progress while the account is being created', (
      tester,
    ) async {
      repository.gate = Completer<void>();
      final handle = tester.ensureSemantics();
      await pumpNewAccount(tester);
      await reachAccess(tester);
      await tester.enterText(field('Contraseña'), password);
      await tap(tester, find.byType(Checkbox));

      await tap(tester, find.text('Crear mi cuenta'));

      expect(
        find.bySemanticsLabel('Crear mi cuenta, cargando'),
        findsOneWidget,
      );
      repository.gate!.complete();
      await tester.pump();
      handle.dispose();
    });

    testWidgets('goes back to the email, with its error under the field, '
        'when the address already has an account', (tester) async {
      repository.signUpResult = const AuthError(AuthFailure.emailAlreadyInUse);
      await pumpNewAccount(tester);
      await reachAccess(tester);
      await tester.enterText(field('Contraseña'), password);
      await tap(tester, find.byType(Checkbox));

      await tap(tester, find.text('Crear mi cuenta'));

      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Este correo ya está registrado'), findsOneWidget);
      expect(find.byType(InlineAlert), findsNothing);
      expect(find.text(email), findsOneWidget);
    });

    testWidgets('explains above the form why creating the account failed', (
      tester,
    ) async {
      repository.signUpResult = const AuthError(AuthFailure.offline);
      await pumpNewAccount(tester);
      await reachAccess(tester);
      await tester.enterText(field('Contraseña'), password);
      await tap(tester, find.byType(Checkbox));

      await tap(tester, find.text('Crear mi cuenta'));

      expect(find.text('Paso 3 de 3'), findsOneWidget);
      expect(
        find.widgetWithText(
          InlineAlert,
          'Sin conexión. Revisa tu red e intenta de nuevo',
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens the terms from their link', (tester) async {
      await pumpNewAccount(tester);
      await reachAccess(tester);
      await tester.ensureVisible(find.byType(CheckboxRow));
      await tester.pump();

      final label = find.descendant(
        of: find.byType(CheckboxRow),
        matching: find.byType(RichText),
      );
      final span = tester.widget<RichText>(label).text as TextSpan;
      await tester.tapOnText(
        find.textRange.ofSubstring('términos y condiciones'),
      );
      await tester.pumpAndSettle();

      expect(span.toPlainText(), contains('política de privacidad'));
      expect(find.text('Términos y condiciones'), findsOneWidget);
      expect(find.textContaining('Documento de demostración'), findsOneWidget);
    });
  });

  group('completing a profile', () {
    testWidgets('has two steps, a fixed email and a way to sign out instead '
        'of going back', (tester) async {
      await pumpCompletion(tester);

      expect(find.text('Completa tu perfil'), findsOneWidget);
      expect(find.text('Paso 1 de 2'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Correo electrónico')).enabled,
        isFalse,
      );
      expect(find.text(email), findsOneWidget);
      expect(find.byTooltip('Volver'), findsNothing);

      await tester.tap(find.text('Cerrar sesión'));
      expect(signOuts, 1);
    });

    testWidgets('starts from what could not be stored and says so', (
      tester,
    ) async {
      await pumpCompletion(tester, unsavedDraft: draft);

      expect(find.text(draft.nationalId), findsOneWidget);
      expect(find.text(draft.fullName), findsOneWidget);
      expect(
        find.widgetWithText(
          InlineAlert,
          'No pudimos completar la operación. Intenta de nuevo en unos '
          'minutos.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('stores the profile at the end of step 2', (tester) async {
      await pumpCompletion(tester);
      await reachInterests(tester);
      expect(find.text('Paso 2 de 2'), findsOneWidget);
      await tap(tester, find.text('Ahorrar'));
      await tap(tester, find.text('Viajar'));
      await tap(tester, find.text('Familia'));

      await tap(tester, find.text('Continuar'));

      expect(repository.completedProfiles, [draft]);
    });
  });

  group('accessibility', () {
    testWidgets('step 1 with errors meets the guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpNewAccount(tester);
      await tap(tester, find.text('Continuar'));

      await expectAccessible(tester);
      handle.dispose();
    });

    testWidgets('step 2 meets the guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpNewAccount(tester);
      await reachInterests(tester);

      await expectAccessible(tester);
      handle.dispose();
    });

    testWidgets('step 3 meets the contrast and labeling guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpNewAccount(tester);
      await reachAccess(tester);

      // Tap target size is not asserted here: the two links inside the
      // sentence are inline text, which WCAG 2.5.8 exempts.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('every step fits a small phone at 130% text', (tester) async {
      useSmallPhone(tester);
      await pumpNewAccount(tester, online: false, textScale: largeText);
      await tap(tester, find.text('Continuar'));
      expect(tester.takeException(), isNull);

      await reachInterests(tester);
      expect(tester.takeException(), isNull);

      await tap(tester, find.text('Continuar'));
      expect(find.text('Paso 3 de 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
