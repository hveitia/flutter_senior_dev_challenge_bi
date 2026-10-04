import 'dart:async';

import 'package:feature_auth/src/data/ports.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/biometric_authenticator.dart';
import 'package:feature_auth/src/domain/session.dart';
import 'package:feature_auth/src/domain/user_profile.dart';

/// An identity provider the test scripts by hand.
///
/// Accounts live in memory. Set one of the `fail…` fields to make the next
/// calls of that operation throw.
final class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({AuthAccount? restored}) : _signedIn = restored;

  final Map<String, ({String password, AuthAccount account})> _accounts = {};
  AuthAccount? _signedIn;
  int _nextUid = 1;

  Object? failSignIn;
  Object? failCreateAccount;
  Object? failPasswordReset;
  Object? failSignOut;

  int signInCalls = 0;
  int createAccountCalls = 0;
  final List<String> passwordResets = [];

  AuthAccount? get signedIn => _signedIn;

  /// Registers an account as if it had been created earlier.
  AuthAccount seed({required String email, required String password}) {
    final account = AuthAccount(uid: 'uid-${_nextUid++}', email: email);
    _accounts[email] = (password: password, account: account);
    return account;
  }

  @override
  Future<AuthAccount?> restoredAccount() async => _signedIn;

  @override
  Future<AuthAccount> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    _throwIfSet(failSignIn);

    final entry = _accounts[email];
    if (entry == null || entry.password != password) {
      throw const AuthRejected(AuthFailure.invalidCredentials);
    }
    return _signedIn = entry.account;
  }

  @override
  Future<AuthAccount> createAccount({
    required String email,
    required String password,
  }) async {
    createAccountCalls++;
    _throwIfSet(failCreateAccount);
    if (_accounts.containsKey(email)) {
      throw const AuthRejected(AuthFailure.emailAlreadyInUse);
    }
    return _signedIn = seed(email: email, password: password);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _throwIfSet(failPasswordReset);
    passwordResets.add(email);
  }

  @override
  Future<void> signOut() async {
    _throwIfSet(failSignOut);
    _signedIn = null;
  }
}

/// Profiles kept in memory. [failRead] and [failCreate] make the next calls
/// throw.
final class InMemoryProfileStore implements ProfileStore {
  final Map<String, UserProfile> profiles = {};

  Object? failRead;
  Object? failCreate;

  /// When set, a failed [create] still stores the profile: the write reached
  /// the backend and only its answer was lost.
  bool createLandsDespiteFailure = false;

  int readCalls = 0;
  int createCalls = 0;

  @override
  Future<UserProfile?> read(String uid) async {
    readCalls++;
    _throwIfSet(failRead);
    return profiles[uid];
  }

  @override
  Future<void> create(UserProfile profile) async {
    createCalls++;
    if (failCreate == null || createLandsDespiteFailure) {
      profiles[profile.uid] = profile;
    }
    _throwIfSet(failCreate);
  }

  Object? failUpdate;
  int updateCalls = 0;

  @override
  Future<void> updatePreferences(
    String uid, {
    required Segment segment,
    required Set<Interest> interests,
  }) async {
    updateCalls++;
    _throwIfSet(failUpdate);
    profiles[uid] = profiles[uid]!.withPreferences(
      segment: segment,
      interests: interests,
    );
  }
}

/// Throws [failure] as the scripted outcome of a call, whatever its type.
void _throwIfSet(Object? failure) {
  if (failure != null) Error.throwWithStackTrace(failure, StackTrace.current);
}

final class InMemoryUnlockPreferences implements UnlockPreferences {
  final Set<String> enabled = {};

  /// When set, reading and writing the preference throw it, as device
  /// storage does when it is unavailable.
  Object? failure;

  @override
  Future<bool> isEnabled(String uid) async {
    _throwIfSet(failure);
    return enabled.contains(uid);
  }

  @override
  Future<void> setEnabled(String uid, {required bool enabled}) async {
    _throwIfSet(failure);
    if (enabled) {
      this.enabled.add(uid);
    } else {
      this.enabled.remove(uid);
    }
  }
}

/// A biometric sensor the test answers for.
final class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({this.available = true, this.passes = true});

  bool available;
  bool passes;

  /// When set, [authenticate] throws it, as a plugin does when the sensor
  /// is locked out.
  Object? failure;

  /// Holds the answer of [isAvailable] until the test completes it.
  Completer<void>? availabilityGate;

  /// Holds the answer of [authenticate] until the test completes it, as a
  /// system prompt that stays on screen does.
  Completer<void>? promptGate;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async {
    await availabilityGate?.future;
    return available;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    await promptGate?.future;
    _throwIfSet(failure);
    return passes;
  }
}

/// A repository that announces what the test tells it to and answers every
/// operation with the result set beforehand.
final class FakeAuthRepository implements AuthRepository {
  final StreamController<Session> _sessions =
      StreamController<Session>.broadcast(sync: true);

  /// What [restore] announces.
  Session restored = const SignedOutSession();

  /// What [retry] announces.
  Session? retried;
  AuthResult<void> signInResult = const AuthOk(null);
  AuthResult<void> signUpResult = const AuthOk(null);
  AuthResult<void> completeProfileResult = const AuthOk(null);
  AuthResult<void> passwordResetResult = const AuthOk(null);

  /// Completes every operation only when the test calls it, to observe the
  /// state while the operation is in flight.
  Completer<void>? gate;

  final List<({String email, String password})> signIns = [];
  final List<SignUpRequest> signUps = [];
  final List<ProfileDraft> completedProfiles = [];
  final List<String> passwordResets = [];
  int restoreCalls = 0;
  int retryCalls = 0;
  int signOutCalls = 0;

  void announce(Session session) => _sessions.add(session);

  @override
  Stream<Session> get sessions => _sessions.stream;

  @override
  Future<void> restore() async {
    restoreCalls++;
    announce(restored);
  }

  @override
  Future<void> retry() async {
    retryCalls++;
    await gate?.future;
    if (retried case final Session session) announce(session);
  }

  @override
  Future<AuthResult<void>> signIn({
    required String email,
    required String password,
  }) async {
    signIns.add((email: email, password: password));
    await gate?.future;
    return signInResult;
  }

  @override
  Future<AuthResult<void>> signUp(SignUpRequest request) async {
    signUps.add(request);
    await gate?.future;
    return signUpResult;
  }

  @override
  Future<AuthResult<void>> completeProfile(ProfileDraft draft) async {
    completedProfiles.add(draft);
    await gate?.future;
    return completeProfileResult;
  }

  @override
  Future<AuthResult<void>> sendPasswordReset(String email) async {
    passwordResets.add(email);
    await gate?.future;
    return passwordResetResult;
  }

  AuthResult<void> updatePreferencesResult = const AuthOk(null);
  final List<({Segment segment, Set<Interest> interests})> preferenceUpdates =
      [];

  /// Set to the signed-in profile so a successful update announces the
  /// changed one, as the real repository does.
  UserProfile? signedInProfile;

  @override
  Future<AuthResult<void>> updatePreferences({
    required Segment segment,
    required Set<Interest> interests,
  }) async {
    preferenceUpdates.add((segment: segment, interests: interests));
    await gate?.future;
    final result = updatePreferencesResult;
    if (result is AuthOk<void>) {
      if (signedInProfile case final profile?) {
        final updated = profile.withPreferences(
          segment: segment,
          interests: interests,
        );
        signedInProfile = updated;
        announce(ActiveSession(updated, unlockRequired: false));
      }
    }
    return result;
  }

  /// Runs when a sign-out starts, before the session is announced as
  /// closed: a test reads here what was still alive at that moment.
  void Function()? onSignOut;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    onSignOut?.call();
    announce(const SignedOutSession());
  }
}
