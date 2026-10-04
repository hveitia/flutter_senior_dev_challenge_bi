import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:feature_auth/src/auth_telemetry.dart';
import 'package:feature_auth/src/data/default_auth_repository.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/session.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  late FakeAuthGateway gateway;
  late InMemoryProfileStore profiles;
  late InMemoryUnlockPreferences unlockPreferences;
  late InMemoryTelemetry telemetry;
  late DefaultAuthRepository repository;
  late List<Session> sessions;
  late StreamSubscription<Session> subscription;

  void build({AuthAccount? restored}) {
    gateway = FakeAuthGateway(restored: restored);
    profiles = InMemoryProfileStore();
    unlockPreferences = InMemoryUnlockPreferences();
    telemetry = InMemoryTelemetry();
    repository = DefaultAuthRepository(
      gateway: gateway,
      profiles: profiles,
      unlockPreferences: unlockPreferences,
      // Backoff between retries does not wait in tests.
      policy: ResiliencePolicy(delay: (_) async {}),
      telemetry: telemetry,
    );
    sessions = [];
    subscription = repository.sessions.listen(sessions.add);
  }

  /// An account with a stored profile, as left by an earlier sign-up.
  UserProfile seedCustomer() {
    final account = gateway.seed(email: email, password: password);
    final profile = UserProfile.fromDraft(account, draft);
    profiles.profiles[account.uid] = profile;
    return profile;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Forgets the sessions announced so far, once they have been delivered.
  Future<void> forgetSessions() async {
    await settle();
    sessions.clear();
  }

  setUp(build);
  tearDown(() => subscription.cancel());

  group('restore', () {
    test('announces signed out when no session survived', () async {
      await repository.restore();
      await settle();

      expect(sessions, [const SignedOutSession()]);
    });

    test('announces the restored customer with their profile', () async {
      const account = AuthAccount(uid: 'uid-9', email: email);
      build(restored: account);
      final profile = UserProfile.fromDraft(account, draft);
      profiles.profiles[account.uid] = profile;

      await repository.restore();
      await settle();

      expect(sessions, [ActiveSession(profile, unlockRequired: false)]);
    });

    test(
      'requires unlock when the customer enabled it on this device',
      () async {
        const account = AuthAccount(uid: 'uid-9', email: email);
        build(restored: account);
        final profile = UserProfile.fromDraft(account, draft);
        profiles.profiles[account.uid] = profile;
        unlockPreferences.enabled.add(account.uid);

        await repository.restore();
        await settle();

        expect(sessions, [ActiveSession(profile, unlockRequired: true)]);
      },
    );

    test('requires unlock when the preference cannot be read, and reports '
        'it', () async {
      const account = AuthAccount(uid: 'uid-9', email: email);
      build(restored: account);
      final profile = UserProfile.fromDraft(account, draft);
      profiles.profiles[account.uid] = profile;
      unlockPreferences.failure = StateError('storage unavailable');

      await repository.restore();
      await settle();

      expect(sessions, [ActiveSession(profile, unlockRequired: true)]);
      expect(telemetry.errors.single.error, isA<RedactedError>());
    });

    test('announces an incomplete profile when the account has none', () async {
      const account = AuthAccount(uid: 'uid-9', email: email);
      build(restored: account);

      await repository.restore();
      await settle();

      expect(sessions, [const IncompleteSession(account)]);
    });

    test('requires unlock for a restored account without profile when the '
        'customer enabled it on this device', () async {
      const account = AuthAccount(uid: 'uid-9', email: email);
      build(restored: account);
      unlockPreferences.enabled.add(account.uid);

      await repository.restore();
      await settle();

      expect(sessions, [
        const IncompleteSession(account, unlockRequired: true),
      ]);
    });

    test('requires unlock after a retry finds the profile, when the customer '
        'enabled it on this device', () async {
      const account = AuthAccount(uid: 'uid-9', email: email);
      build(restored: account);
      final profile = UserProfile.fromDraft(account, draft);
      profiles.profiles[account.uid] = profile;
      unlockPreferences.enabled.add(account.uid);
      profiles.failRead = const OfflineFailure();
      await repository.restore();

      profiles.failRead = null;
      await repository.retry();
      await settle();

      expect(sessions.last, ActiveSession(profile, unlockRequired: true));
    });

    test('announces unavailable when the profile cannot be read', () async {
      const account = AuthAccount(uid: 'uid-9', email: email);
      build(restored: account);
      profiles.failRead = const OfflineFailure();

      await repository.restore();
      await settle();

      expect(sessions, [const UnavailableSession(account)]);
    });

    test('retry reads the profile again after it was unavailable', () async {
      const account = AuthAccount(uid: 'uid-9', email: email);
      build(restored: account);
      final profile = UserProfile.fromDraft(account, draft);
      profiles.profiles[account.uid] = profile;
      profiles.failRead = const OfflineFailure();
      await repository.restore();

      profiles.failRead = null;
      await repository.retry();
      await settle();

      expect(sessions, [
        const UnavailableSession(account),
        // Still the restored session, so the unlock preference applies.
        ActiveSession(profile, unlockRequired: false),
      ]);
    });

    test('retries a profile read that the backend could not serve', () async {
      const account = AuthAccount(uid: 'uid-9', email: email);
      build(restored: account);
      profiles.failRead = const ServiceUnavailableFailure();

      await repository.restore();

      expect(profiles.readCalls, ResiliencePolicy.maxAttempts);
    });
  });

  group('signIn', () {
    test('announces the customer and succeeds', () async {
      final profile = seedCustomer();

      final result = await repository.signIn(email: email, password: password);
      await settle();

      expect(result, isA<AuthOk<void>>());
      expect(sessions, [ActiveSession(profile, unlockRequired: false)]);
    });

    test('never asks for unlock right after typing the password', () async {
      final profile = seedCustomer();
      unlockPreferences.enabled.add(profile.uid);

      await repository.signIn(email: email, password: password);
      await settle();

      expect(sessions, [ActiveSession(profile, unlockRequired: false)]);
    });

    test('fails with invalid credentials and announces nothing', () async {
      seedCustomer();

      final result = await repository.signIn(email: email, password: 'wrong');
      await settle();

      expect(
        result,
        isA<AuthError<void>>().having(
          (error) => error.failure,
          'failure',
          AuthFailure.invalidCredentials,
        ),
      );
      expect(sessions, isEmpty);
    });

    test('does not repeat a sign-in the provider rejected', () async {
      seedCustomer();

      await repository.signIn(email: email, password: 'wrong');

      expect(gateway.signInCalls, 1);
    });

    test('fails as offline without a connection', () async {
      seedCustomer();
      gateway.failSignIn = const OfflineFailure();

      final result = await repository.signIn(email: email, password: password);

      expect(
        (result as AuthError<void>).failure,
        AuthFailure.offline,
      );
    });

    test('retries when the provider does not answer, then fails as '
        'unavailable', () async {
      seedCustomer();
      gateway.failSignIn = const TimeoutFailure();

      final result = await repository.signIn(email: email, password: password);

      expect(gateway.signInCalls, ResiliencePolicy.maxAttempts);
      expect((result as AuthError<void>).failure, AuthFailure.unavailable);
    });

    test('fails as unexpected for an error nobody anticipated and reports '
        'only its type', () async {
      seedCustomer();
      gateway.failSignIn = StateError('boom for $email');

      final result = await repository.signIn(email: email, password: password);

      expect((result as AuthError<void>).failure, AuthFailure.unexpected);
      final report = telemetry.errors.single;
      expect(report.error, isA<RedactedError>());
      expect(report.reason, AuthTelemetry.unexpectedError);
      expect('${report.error}', isNot(contains(email)));
    });

    test('signs back out when the profile cannot be read, so the customer '
        'is not left half signed in', () async {
      seedCustomer();
      profiles.failRead = const OfflineFailure();

      final result = await repository.signIn(email: email, password: password);
      await settle();

      expect((result as AuthError<void>).failure, AuthFailure.offline);
      expect(gateway.signedIn, isNull);
      expect(sessions, isEmpty);
    });

    test('still fails with the reason the profile could not be read when '
        'signing back out fails too', () async {
      seedCustomer();
      profiles.failRead = const OfflineFailure();
      gateway.failSignOut = StateError('provider unreachable');

      final result = await repository.signIn(email: email, password: password);
      await settle();

      expect((result as AuthError<void>).failure, AuthFailure.offline);
      expect(sessions, isEmpty);
      expect(telemetry.errors.single.error, isA<RedactedError>());
    });

    test(
      'announces an incomplete profile for an account without one',
      () async {
        final account = gateway.seed(email: email, password: password);

        final result = await repository.signIn(
          email: email,
          password: password,
        );
        await settle();

        expect(result, isA<AuthOk<void>>());
        expect(sessions, [IncompleteSession(account)]);
      },
    );
  });

  group('signUp', () {
    test('creates the account, stores the profile and announces the '
        'customer', () async {
      final result = await repository.signUp(signUpRequest);
      await settle();

      final account = gateway.signedIn!;
      final profile = UserProfile.fromDraft(account, draft);
      expect(result, isA<AuthOk<void>>());
      expect(profiles.profiles[account.uid], profile);
      expect(sessions, [ActiveSession(profile, unlockRequired: false)]);
    });

    test(
      'fails when the email already has an account and stores nothing',
      () async {
        gateway.seed(email: email, password: 'Otra#2026');

        final result = await repository.signUp(signUpRequest);
        await settle();

        expect(
          (result as AuthError<void>).failure,
          AuthFailure.emailAlreadyInUse,
        );
        expect(profiles.createCalls, 0);
        expect(sessions, isEmpty);
      },
    );

    test('creates the account exactly once even when the provider does not '
        'answer', () async {
      gateway.failCreateAccount = const TimeoutFailure();

      final result = await repository.signUp(signUpRequest);

      expect(gateway.createAccountCalls, 1);
      expect((result as AuthError<void>).failure, AuthFailure.unavailable);
    });

    test(
      'keeps what the customer typed when the profile cannot be stored',
      () async {
        profiles.failCreate = const TimeoutFailure();

        final result = await repository.signUp(signUpRequest);
        await settle();

        // The account exists: sign-up as such went through.
        expect(result, isA<AuthOk<void>>());
        expect(profiles.createCalls, 1);
        expect(sessions, [
          IncompleteSession(gateway.signedIn!, unsavedDraft: draft),
        ]);
      },
    );

    test(
      'remembers the unlock preference for this device when asked',
      () async {
        await repository.signUp(
          const SignUpRequest(
            email: email,
            password: password,
            profile: draft,
            biometricUnlock: true,
          ),
        );

        expect(unlockPreferences.enabled, {gateway.signedIn!.uid});
      },
    );

    test('does not ask for unlock unless the customer chose it', () async {
      await repository.signUp(signUpRequest);

      expect(unlockPreferences.enabled, isEmpty);
    });

    group('when the unlock preference cannot be saved', () {
      const withUnlock = SignUpRequest(
        email: email,
        password: password,
        profile: draft,
        biometricUnlock: true,
      );

      setUp(
        () => unlockPreferences.failure = StateError('storage unavailable'),
      );

      test('still stores the profile and announces the customer', () async {
        final result = await repository.signUp(withUnlock);
        await settle();

        final profile = UserProfile.fromDraft(gateway.signedIn!, draft);
        expect(result, isA<AuthOk<void>>());
        expect(profiles.profiles[profile.uid], profile);
        expect(sessions, [ActiveSession(profile, unlockRequired: false)]);
        expect(telemetry.errors.single.error, isA<RedactedError>());
      });

      test('still keeps what the customer typed when the profile cannot be '
          'stored either', () async {
        profiles.failCreate = const TimeoutFailure();

        final result = await repository.signUp(withUnlock);
        await settle();

        expect(result, isA<AuthOk<void>>());
        expect(sessions, [
          IncompleteSession(gateway.signedIn!, unsavedDraft: draft),
        ]);
      });
    });
  });

  group('completeProfile', () {
    Future<AuthAccount> halfCreatedAccount() async {
      profiles.failCreate = const TimeoutFailure();
      await repository.signUp(signUpRequest);
      profiles
        ..failCreate = null
        ..createCalls = 0;
      await forgetSessions();
      return gateway.signedIn!;
    }

    test('stores the profile and announces the customer', () async {
      final account = await halfCreatedAccount();

      final result = await repository.completeProfile(draft);
      await settle();

      final profile = UserProfile.fromDraft(account, draft);
      expect(result, isA<AuthOk<void>>());
      expect(profiles.profiles[account.uid], profile);
      expect(sessions, [ActiveSession(profile, unlockRequired: false)]);
    });

    test('uses the stored profile when the earlier write did reach the '
        'backend', () async {
      profiles
        ..failCreate = const TimeoutFailure()
        ..createLandsDespiteFailure = true;
      await repository.signUp(signUpRequest);
      profiles
        ..failCreate = null
        ..createCalls = 0;
      await forgetSessions();
      const corrected = ProfileDraft(
        fullName: 'Valentina Andrade Paz',
        nationalId: '1710034065',
        phone: '0991234567',
      );

      final result = await repository.completeProfile(corrected);
      await settle();

      final stored = UserProfile.fromDraft(gateway.signedIn!, draft);
      expect(result, isA<AuthOk<void>>());
      // Writing again would be rejected by the security rules.
      expect(profiles.createCalls, 0);
      expect(sessions, [ActiveSession(stored, unlockRequired: false)]);
    });

    test(
      'fails and keeps the session incomplete when storing fails again',
      () async {
        final account = await halfCreatedAccount();
        profiles.failCreate = const OfflineFailure();

        final result = await repository.completeProfile(draft);
        await settle();

        expect((result as AuthError<void>).failure, AuthFailure.offline);
        expect(sessions, [
          IncompleteSession(account, unsavedDraft: draft),
        ]);
      },
    );

    test('completes an account found without profile at sign-in', () async {
      final account = gateway.seed(email: email, password: password);
      await repository.signIn(email: email, password: password);
      await forgetSessions();

      await repository.completeProfile(draft);
      await settle();

      expect(sessions, [
        ActiveSession(
          UserProfile.fromDraft(account, draft),
          unlockRequired: false,
        ),
      ]);
    });

    test('is refused when nobody is signed in', () async {
      final result = await repository.completeProfile(draft);

      expect((result as AuthError<void>).failure, AuthFailure.unexpected);
      expect(profiles.createCalls, 0);
    });
  });

  group('sendPasswordReset', () {
    test('asks the provider for the email', () async {
      final result = await repository.sendPasswordReset(email);

      expect(result, isA<AuthOk<void>>());
      expect(gateway.passwordResets, [email]);
    });

    test('fails as offline without a connection', () async {
      gateway.failPasswordReset = const OfflineFailure();

      final result = await repository.sendPasswordReset(email);

      expect((result as AuthError<void>).failure, AuthFailure.offline);
    });
  });

  group('updatePreferences', () {
    Future<UserProfile> signedIn() async {
      final profile = seedCustomer();
      await repository.signIn(email: email, password: password);
      await forgetSessions();
      return profile;
    }

    test('stores the new segment and interests and announces the profile '
        'that has them', () async {
      final profile = await signedIn();

      final result = await repository.updatePreferences(
        segment: Segment.wealth,
        interests: {Interest.investing},
      );
      await settle();

      expect(result, isA<AuthOk<void>>());
      final stored = profiles.profiles[profile.uid]!;
      expect(stored.segment, Segment.wealth);
      expect(stored.interests, {Interest.investing});
      expect(stored.nationalId, profile.nationalId);
      expect(sessions, [ActiveSession(stored, unlockRequired: false)]);
    });

    test('leaves the session as it was when storing fails', () async {
      final profile = await signedIn();
      profiles.failUpdate = const ServiceUnavailableFailure();

      final result = await repository.updatePreferences(
        segment: Segment.wealth,
        interests: const {},
      );
      await settle();

      expect(
        result,
        isA<AuthError<void>>().having(
          (error) => error.failure,
          'failure',
          AuthFailure.unavailable,
        ),
      );
      expect(profiles.profiles[profile.uid]!.segment, Segment.family);
      expect(sessions, isEmpty);
    });

    test('does not bring back a session that ended while the change was being '
        'stored', () async {
      await signedIn();
      final release = Completer<void>();
      profiles.holdUpdate = release.future;

      final update = repository.updatePreferences(
        segment: Segment.wealth,
        interests: {Interest.investing},
      );
      await repository.signOut();
      await forgetSessions();
      release.complete();
      await update;
      await settle();

      expect(sessions, isEmpty);
    });

    test('is refused without a signed-in customer', () async {
      final result = await repository.updatePreferences(
        segment: Segment.wealth,
        interests: const {},
      );

      expect(result, isA<AuthError<void>>());
      expect(profiles.updateCalls, 0);
    });

    test('reports that preferences changed and nothing about which', () async {
      await signedIn();
      telemetry.events.clear();

      await repository.updatePreferences(
        segment: Segment.wealth,
        interests: {Interest.investing},
      );

      expect(telemetry.events.single.name, AuthTelemetry.preferencesUpdated);
      expect(telemetry.events.single.parameters, isEmpty);
    });
  });

  group('signOut', () {
    test('signs out of the provider and announces it', () async {
      seedCustomer();
      await repository.signIn(email: email, password: password);
      await forgetSessions();

      await repository.signOut();
      await settle();

      expect(gateway.signedIn, isNull);
      expect(sessions, [const SignedOutSession()]);
    });
  });

  group('telemetry', () {
    Map<String, Map<String, Object>> reported() => {
      for (final event in telemetry.events) event.name: event.parameters,
    };

    test('reports how the session was restored', () async {
      await repository.restore();

      expect(reported(), {
        AuthTelemetry.sessionRestored: {
          AuthTelemetry.outcomeKey: RestoreOutcome.signedOut,
        },
      });
    });

    test('reports a sign-in and its failure reason, nothing else', () async {
      seedCustomer();

      await repository.signIn(email: email, password: 'wrong');
      await repository.signIn(email: email, password: password);

      expect(reported(), {
        AuthTelemetry.signInFailed: {
          AuthTelemetry.reasonKey: AuthFailure.invalidCredentials.name,
        },
        AuthTelemetry.signInSucceeded: <String, Object>{},
      });
    });

    test('reports a half-created account with the failure reason', () async {
      profiles.failCreate = const TimeoutFailure();

      await repository.signUp(signUpRequest);

      expect(reported(), {
        AuthTelemetry.profileSaveFailed: {
          AuthTelemetry.reasonKey: AuthFailure.unavailable.name,
        },
      });
    });

    test('reports sign-up, completion, reset and sign-out without '
        'parameters', () async {
      await repository.signUp(signUpRequest);
      await repository.sendPasswordReset(email);
      await repository.signOut();

      expect(reported(), {
        AuthTelemetry.signUpSucceeded: <String, Object>{},
        AuthTelemetry.passwordResetRequested: <String, Object>{},
        AuthTelemetry.signedOut: <String, Object>{},
      });
    });

    test('never contains anything that identifies the customer', () async {
      gateway.failSignIn = StateError('rejected $email');
      await repository.signIn(email: email, password: password);
      gateway.failSignIn = null;
      await repository.signUp(signUpRequest);
      await repository.signOut();
      await repository.signIn(email: email, password: password);
      await repository.sendPasswordReset(email);

      final everything = [
        for (final event in telemetry.events)
          '${event.name} ${event.parameters}',
        for (final entry in telemetry.logs) '${entry.message} ${entry.context}',
        for (final report in telemetry.errors)
          '${report.error} ${report.reason}',
        '${telemetry.context}',
      ].join('\n');

      for (final datum in personalData) {
        expect(everything, isNot(contains(datum)));
      }
    });
  });
}
