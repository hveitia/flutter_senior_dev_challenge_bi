import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/session.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/session/session_bloc.dart';
import 'package:feature_auth/src/presentation/session/session_unavailable_screen.dart';
import 'package:feature_auth/src/presentation/unlock/unlock_screen.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/pump_auth.dart';

void main() {
  const account = AuthAccount(uid: 'uid-1', email: email);
  final profile = UserProfile.fromDraft(account, draft);

  late FakeAuthRepository repository;
  late FakeBiometricAuthenticator biometrics;

  Future<SessionBloc> pump(WidgetTester tester, Widget screen) async {
    final bloc = SessionBloc(
      repository: repository,
      biometrics: biometrics,
    )..add(const SessionStarted());
    addTearDown(bloc.close);
    await tester.pump();

    await pumpAuth(
      tester,
      screen,
      providers: [BlocProvider<SessionBloc>.value(value: bloc)],
    );
    await tester.pump();
    return bloc;
  }

  setUp(() {
    repository = FakeAuthRepository()
      ..restored = ActiveSession(profile, unlockRequired: true);
    biometrics = FakeBiometricAuthenticator();
  });

  group('UnlockScreen', () {
    testWidgets('asks for the biometric check as soon as it opens', (
      tester,
    ) async {
      final bloc = await pump(tester, const UnlockScreen());

      expect(biometrics.prompts, 1);
      expect(bloc.state, SessionSignedIn(profile));
    });

    testWidgets('greets the customer by first name and explains the failure '
        'when the check does not pass', (tester) async {
      biometrics.passes = false;

      await pump(tester, const UnlockScreen());

      expect(find.text('Hola de nuevo, Valentina'), findsOneWidget);
      expect(
        find.widgetWithText(
          InlineAlert,
          'No pudimos confirmar tu identidad. Intenta de nuevo o ingresa con '
          'tu contraseña.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows neither a name nor the email while it locks an '
        'account whose profile is still pending', (tester) async {
      repository.restored = const IncompleteSession(
        account,
        unlockRequired: true,
      );
      biometrics.passes = false;

      await pump(tester, const UnlockScreen());

      expect(find.text('Hola de nuevo'), findsOneWidget);
      expect(find.textContaining(email), findsNothing);
    });

    testWidgets('tries again on request', (tester) async {
      biometrics.passes = false;
      final bloc = await pump(tester, const UnlockScreen());
      biometrics.passes = true;

      await tester.tap(find.text('Ingresar con huella o rostro'));
      await tester.pump();

      expect(biometrics.prompts, 2);
      expect(bloc.state, SessionSignedIn(profile));
    });

    testWidgets('falls back to the password by signing out', (tester) async {
      biometrics.passes = false;
      final bloc = await pump(tester, const UnlockScreen());

      await tester.tap(find.text('Ingresar con contraseña'));
      await tester.pump();

      expect(repository.signOutCalls, 1);
      expect(bloc.state, const SessionSignedOut());
    });

    testWidgets('meets the accessibility guidelines', (tester) async {
      biometrics.passes = false;
      final handle = tester.ensureSemantics();
      await pump(tester, const UnlockScreen());

      await expectAccessible(tester);
      handle.dispose();
    });
  });

  group('SessionUnavailableScreen', () {
    setUp(() => repository.restored = const UnavailableSession(account));

    testWidgets('explains that the information could not be loaded', (
      tester,
    ) async {
      await pump(tester, const SessionUnavailableScreen());

      expect(find.text('No pudimos cargar tu información'), findsOneWidget);
      expect(
        find.text('Revisa tu conexión e intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('retries on request', (tester) async {
      repository.retried = ActiveSession(profile, unlockRequired: false);
      final bloc = await pump(tester, const SessionUnavailableScreen());

      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(repository.retryCalls, 1);
      expect(bloc.state, SessionSignedIn(profile));
    });

    testWidgets('lets the customer sign out instead', (tester) async {
      await pump(tester, const SessionUnavailableScreen());

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();

      expect(repository.signOutCalls, 1);
    });

    testWidgets('meets the accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const SessionUnavailableScreen());

      await expectAccessible(tester);
      handle.dispose();
    });
  });
}
