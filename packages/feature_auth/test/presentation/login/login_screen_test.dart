import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/presentation/login/login_cubit.dart';
import 'package:feature_auth/src/presentation/login/login_screen.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/pump_auth.dart';

void main() {
  const genericError =
      'No pudimos validar tus datos. Revisa e intenta de nuevo.';
  const offlineMessage = 'Sin conexión. Revisa tu red e intenta de nuevo';

  late FakeAuthRepository repository;
  var openAccountTaps = 0;

  Future<void> pump(
    WidgetTester tester, {
    bool online = true,
    double textScale = 1,
  }) async {
    await pumpAuth(
      tester,
      LoginScreen(onOpenAccount: () => openAccountTaps++),
      providers: [
        BlocProvider<LoginCubit>(
          create: (_) => LoginCubit(repository: repository),
        ),
      ],
      online: online,
      textScale: textScale,
    );
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(AppTextField, label),
    matching: find.byType(TextField),
  );

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(field('Correo electrónico'), email);
    await tester.enterText(field('Contraseña'), password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
  }

  setUp(() {
    repository = FakeAuthRepository();
    openAccountTaps = 0;
  });

  testWidgets('greets the returning customer', (tester) async {
    await pump(tester);

    expect(find.text('Hola de nuevo'), findsOneWidget);
    expect(
      find.text('Tu dinero y tus proyectos, aquí contigo.'),
      findsOneWidget,
    );
    expect(find.byType(InlineAlert), findsNothing);
  });

  testWidgets('signs in with what was typed', (tester) async {
    await pump(tester);
    await fill(tester);

    await submit(tester);

    expect(repository.signIns, [(email: email, password: password)]);
  });

  testWidgets('marks the empty fields instead of calling the backend', (
    tester,
  ) async {
    await pump(tester);

    await submit(tester);

    expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    expect(repository.signIns, isEmpty);
  });

  testWidgets('shows progress on the button while signing in', (tester) async {
    repository.gate = Completer<void>();
    final handle = tester.ensureSemantics();
    await pump(tester);
    await fill(tester);

    await submit(tester);

    expect(find.bySemanticsLabel('Ingresar, cargando'), findsOneWidget);
    repository.gate!.complete();
    await tester.pump();
    expect(find.bySemanticsLabel('Ingresar, cargando'), findsNothing);
    handle.dispose();
  });

  testWidgets('answers rejected credentials with one generic message and '
      'keeps what was typed', (tester) async {
    repository.signInResult = const AuthError(AuthFailure.invalidCredentials);
    await pump(tester);
    await fill(tester);

    await submit(tester);

    expect(find.widgetWithText(InlineAlert, genericError), findsOneWidget);
    // Nothing points at the email or at the password in particular.
    expect(find.text('Ingresa un correo electrónico válido'), findsNothing);
    expect(find.text('Ingresa tu contraseña'), findsNothing);
    expect(find.text(email), findsOneWidget);
  });

  testWidgets('says there is no connection when sign-in fails offline', (
    tester,
  ) async {
    repository.signInResult = const AuthError(AuthFailure.offline);
    await pump(tester);
    await fill(tester);

    await submit(tester);

    expect(find.widgetWithText(InlineAlert, offlineMessage), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });

  testWidgets('says there is no connection before the customer even tries', (
    tester,
  ) async {
    await pump(tester, online: false);

    expect(find.widgetWithText(InlineAlert, offlineMessage), findsOneWidget);
  });

  testWidgets('reveals and hides the password on request', (tester) async {
    await pump(tester);

    expect(tester.widget<TextField>(field('Contraseña')).obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(tester.widget<TextField>(field('Contraseña')).obscureText, isFalse);

    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();
    expect(tester.widget<TextField>(field('Contraseña')).obscureText, isTrue);
  });

  testWidgets('confirms a password reset without saying whether the email '
      'has an account', (tester) async {
    await pump(tester);
    await tester.enterText(field('Correo electrónico'), email);

    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pump();

    expect(repository.passwordResets, [email]);
    expect(
      find.widgetWithText(
        InlineAlert,
        'Si el correo está registrado, te enviaremos un enlace para '
        'restablecer tu contraseña.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('asks for the email before requesting a reset', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pump();

    expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
    expect(repository.passwordResets, isEmpty);
  });

  testWidgets('offers to open an account', (tester) async {
    await pump(tester);

    await tester.ensureVisible(find.text('Abre tu cuenta'));
    await tester.tap(find.text('Abre tu cuenta'));

    expect(openAccountTaps, 1);
  });

  testWidgets('meets the accessibility guidelines, error state included', (
    tester,
  ) async {
    repository.signInResult = const AuthError(AuthFailure.invalidCredentials);
    final handle = tester.ensureSemantics();
    await pump(tester);
    await fill(tester);
    await submit(tester);

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('fits a small phone at 130% text with errors showing', (
    tester,
  ) async {
    useSmallPhone(tester);
    await pump(tester, online: false, textScale: largeText);

    await submit(tester);

    expect(tester.takeException(), isNull);
  });
}
