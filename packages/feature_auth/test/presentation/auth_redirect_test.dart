import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/auth_routes.dart';
import 'package:feature_auth/src/presentation/session/session_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  const splash = '/';
  const home = '/inicio';
  final profile = UserProfile.fromDraft(
    const AuthAccount(uid: 'uid-1', email: email),
    draft,
  );

  String? redirect(SessionState session, String location) =>
      authRedirect(session, location: location, splash: splash, home: home);

  test('keeps the splash while the session is unknown', () {
    expect(redirect(const SessionStarting(), splash), isNull);
    expect(redirect(const SessionStarting(), home), splash);
    expect(redirect(const SessionStarting(), AuthPaths.login), splash);
  });

  test('lets a signed-out customer move between the access screens', () {
    for (final location in AuthPaths.signedOut) {
      expect(redirect(const SessionSignedOut(), location), isNull);
    }
  });

  test('sends a signed-out customer to the welcome from anywhere else', () {
    for (final location in [
      splash,
      home,
      AuthPaths.unlock,
      AuthPaths.completeProfile,
      AuthPaths.unavailable,
    ]) {
      expect(redirect(const SessionSignedOut(), location), AuthPaths.welcome);
    }
  });

  test('sends a signed-in customer home from the splash and from every '
      'access screen', () {
    for (final location in [splash, ...AuthPaths.all]) {
      expect(redirect(SessionSignedIn(profile), location), home);
    }
  });

  test('leaves a signed-in customer where they are inside the app', () {
    expect(redirect(SessionSignedIn(profile), home), isNull);
    expect(redirect(SessionSignedIn(profile), '/cuentas'), isNull);
  });

  test('holds a locked session on the unlock screen', () {
    expect(
      redirect(SessionLocked(SessionSignedIn(profile)), home),
      AuthPaths.unlock,
    );
    expect(
      redirect(SessionLocked(SessionSignedIn(profile)), AuthPaths.unlock),
      isNull,
    );
  });

  test('holds an account without profile on the completion flow', () {
    const pending = SessionProfilePending(email: email);

    expect(redirect(pending, home), AuthPaths.completeProfile);
    expect(redirect(pending, AuthPaths.signUp), AuthPaths.completeProfile);
    expect(redirect(pending, AuthPaths.completeProfile), isNull);
  });

  test('holds an unavailable session on its own screen', () {
    expect(redirect(const SessionUnavailable(), home), AuthPaths.unavailable);
    expect(
      redirect(
        const SessionUnavailable(isRetrying: true),
        AuthPaths.unavailable,
      ),
      isNull,
    );
  });
}
