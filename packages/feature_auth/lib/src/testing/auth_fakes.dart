import 'package:feature_auth/src/data/ports.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
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
  Future<void> signOut() async => _signedIn = null;
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
}

/// Throws [failure] as the scripted outcome of a call, whatever its type.
void _throwIfSet(Object? failure) {
  if (failure != null) Error.throwWithStackTrace(failure, StackTrace.current);
}

final class InMemoryUnlockPreferences implements UnlockPreferences {
  final Set<String> enabled = {};

  @override
  Future<bool> isEnabled(String uid) async => enabled.contains(uid);

  @override
  Future<void> setEnabled(String uid, {required bool enabled}) async {
    if (enabled) {
      this.enabled.add(uid);
    } else {
      this.enabled.remove(uid);
    }
  }
}
