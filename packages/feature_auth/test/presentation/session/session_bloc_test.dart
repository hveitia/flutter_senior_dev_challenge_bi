import 'dart:async';

import 'package:app_platform/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_auth/src/auth_telemetry.dart';
import 'package:feature_auth/src/domain/session.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/session/session_bloc.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  const account = AuthAccount(uid: 'uid-1', email: email);
  final profile = UserProfile.fromDraft(account, draft);

  late FakeAuthRepository repository;
  late FakeBiometricAuthenticator biometrics;
  late InMemoryTelemetry telemetry;

  SessionBloc build() => SessionBloc(
    repository: repository,
    biometrics: biometrics,
    telemetry: telemetry,
  );

  setUp(() {
    repository = FakeAuthRepository();
    biometrics = FakeBiometricAuthenticator();
    telemetry = InMemoryTelemetry();
  });

  test('starts without knowing who is signed in', () {
    expect(build().state, const SessionStarting());
  });

  group('on start', () {
    blocTest<SessionBloc, SessionState>(
      'is signed out when no session survived',
      build: build,
      act: (bloc) => bloc.add(const SessionStarted()),
      expect: () => [const SessionSignedOut()],
      verify: (_) => expect(repository.restoreCalls, 1),
    );

    blocTest<SessionBloc, SessionState>(
      'is signed in when the restored session needs no unlock',
      setUp: () =>
          repository.restored = ActiveSession(profile, unlockRequired: false),
      build: build,
      act: (bloc) => bloc.add(const SessionStarted()),
      expect: () => [SessionSignedIn(profile)],
    );

    blocTest<SessionBloc, SessionState>(
      'is locked when the restored session requires unlock',
      setUp: () =>
          repository.restored = ActiveSession(profile, unlockRequired: true),
      build: build,
      act: (bloc) => bloc.add(const SessionStarted()),
      expect: () => [SessionLocked(profile)],
      verify: (_) => expect(biometrics.prompts, 0),
    );

    blocTest<SessionBloc, SessionState>(
      'falls back to password sign-in when unlock is required but the '
      'device has no biometrics any more',
      setUp: () {
        repository.restored = ActiveSession(profile, unlockRequired: true);
        biometrics.available = false;
      },
      build: build,
      act: (bloc) => bloc.add(const SessionStarted()),
      expect: () => [const SessionSignedOut()],
      verify: (_) => expect(repository.signOutCalls, 1),
    );

    blocTest<SessionBloc, SessionState>(
      'asks to complete the profile of an account without one',
      setUp: () => repository.restored = const IncompleteSession(
        account,
        unsavedDraft: draft,
      ),
      build: build,
      act: (bloc) => bloc.add(const SessionStarted()),
      expect: () => [
        const SessionProfilePending(email: email, unsavedDraft: draft),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'is unavailable when the profile cannot be loaded',
      setUp: () => repository.restored = const UnavailableSession(account),
      build: build,
      act: (bloc) => bloc.add(const SessionStarted()),
      expect: () => [const SessionUnavailable()],
    );
  });

  blocTest<SessionBloc, SessionState>(
    'follows every session the repository announces after the start',
    build: build,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await Future<void>.delayed(Duration.zero);
      repository
        ..announce(ActiveSession(profile, unlockRequired: false))
        ..announce(const SignedOutSession());
    },
    expect: () => [
      const SessionSignedOut(),
      SessionSignedIn(profile),
      const SessionSignedOut(),
    ],
  );

  blocTest<SessionBloc, SessionState>(
    'ends signed out when the sign-out is announced while the restored '
    'session is still waiting to know if the device has biometrics',
    setUp: () {
      repository.restored = ActiveSession(profile, unlockRequired: true);
      biometrics.availabilityGate = Completer<void>();
    },
    build: build,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await Future<void>.delayed(Duration.zero);
      repository.announce(const SignedOutSession());
      await Future<void>.delayed(Duration.zero);
      biometrics.availabilityGate!.complete();
    },
    expect: () => [SessionLocked(profile), const SessionSignedOut()],
  );

  group('unlock', () {
    setUp(
      () => repository.restored = ActiveSession(profile, unlockRequired: true),
    );

    blocTest<SessionBloc, SessionState>(
      'ignores a check that passes after the session was signed out',
      setUp: () => biometrics.promptGate = Completer<void>(),
      build: build,
      act: (bloc) async {
        bloc.add(const SessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SessionUnlockRequested());
        await Future<void>.delayed(Duration.zero);
        repository.announce(const SignedOutSession());
        await Future<void>.delayed(Duration.zero);
        biometrics.promptGate!.complete();
      },
      expect: () => [SessionLocked(profile), const SessionSignedOut()],
    );

    blocTest<SessionBloc, SessionState>(
      'signs in when the biometric check passes',
      build: build,
      act: (bloc) async {
        bloc.add(const SessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SessionUnlockRequested());
      },
      expect: () => [SessionLocked(profile), SessionSignedIn(profile)],
      verify: (_) => expect(biometrics.prompts, 1),
    );

    blocTest<SessionBloc, SessionState>(
      'stays locked and says so when the check does not pass',
      setUp: () => biometrics.passes = false,
      build: build,
      act: (bloc) async {
        bloc.add(const SessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SessionUnlockRequested());
      },
      expect: () => [
        SessionLocked(profile),
        SessionLocked(profile, lastAttemptFailed: true),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'stays locked when the sensor throws',
      setUp: () => biometrics.failure = StateError('locked out'),
      build: build,
      act: (bloc) async {
        bloc.add(const SessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SessionUnlockRequested());
      },
      expect: () => [
        SessionLocked(profile),
        SessionLocked(profile, lastAttemptFailed: true),
      ],
    );

    blocTest<SessionBloc, SessionState>(
      'ignores an unlock request when nothing is locked',
      setUp: () => repository.restored = const SignedOutSession(),
      build: build,
      act: (bloc) async {
        bloc.add(const SessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SessionUnlockRequested());
      },
      expect: () => [const SessionSignedOut()],
      verify: (_) => expect(biometrics.prompts, 0),
    );

    blocTest<SessionBloc, SessionState>(
      'reports the outcome of each attempt without parameters',
      setUp: () => biometrics.passes = false,
      build: build,
      act: (bloc) async {
        bloc.add(const SessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SessionUnlockRequested());
        await Future<void>.delayed(Duration.zero);
        biometrics.passes = true;
        bloc.add(const SessionUnlockRequested());
      },
      skip: 3,
      verify: (_) => expect(
        {for (final event in telemetry.events) event.name: event.parameters},
        {
          AuthTelemetry.unlockFailed: <String, Object>{},
          AuthTelemetry.unlockSucceeded: <String, Object>{},
        },
      ),
    );
  });

  blocTest<SessionBloc, SessionState>(
    'signs out through the repository',
    setUp: () =>
        repository.restored = ActiveSession(profile, unlockRequired: false),
    build: build,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SessionSignOutRequested());
    },
    expect: () => [SessionSignedIn(profile), const SessionSignedOut()],
    verify: (_) => expect(repository.signOutCalls, 1),
  );

  blocTest<SessionBloc, SessionState>(
    'shows progress while retrying and follows what the retry finds',
    setUp: () {
      repository
        ..restored = const UnavailableSession(account)
        ..retried = ActiveSession(profile, unlockRequired: false);
    },
    build: build,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SessionRetryRequested());
    },
    expect: () => [
      const SessionUnavailable(),
      const SessionUnavailable(isRetrying: true),
      SessionSignedIn(profile),
    ],
    verify: (_) => expect(repository.retryCalls, 1),
  );

  blocTest<SessionBloc, SessionState>(
    'stops showing progress when the retry finds the profile still '
    'unavailable',
    setUp: () {
      repository
        ..restored = const UnavailableSession(account)
        ..retried = const UnavailableSession(account);
    },
    build: build,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SessionRetryRequested());
    },
    expect: () => [
      const SessionUnavailable(),
      const SessionUnavailable(isRetrying: true),
      const SessionUnavailable(),
    ],
  );

  test('stops listening to the repository when closed', () async {
    final bloc = build()..add(const SessionStarted());
    await Future<void>.delayed(Duration.zero);

    await bloc.close();

    expect(
      () => repository.announce(const SignedOutSession()),
      returnsNormally,
    );
    expect(bloc.state, const SessionSignedOut());
  });
}
