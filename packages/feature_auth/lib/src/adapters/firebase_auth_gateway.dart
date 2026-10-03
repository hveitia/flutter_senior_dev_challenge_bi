import 'package:app_platform/app_platform.dart';
import 'package:feature_auth/src/data/ports.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// [AuthGateway] on Firebase Authentication.
///
/// It translates the provider's error codes and nothing else: retries and
/// timeouts belong to the resilience policy that calls it.
final class FirebaseAuthGateway implements AuthGateway {
  const FirebaseAuthGateway(this._auth);

  final FirebaseAuth _auth;

  /// Codes that mean "these credentials do not open an account". They are
  /// folded into one reason so the app cannot be used to find out which
  /// emails are registered.
  static const Set<String> _rejectedCredentials = {
    'invalid-credential',
    'invalid-email',
    'user-disabled',
    'user-not-found',
    'wrong-password',
  };

  static const String _noNetwork = 'network-request-failed';
  static const String _throttled = 'too-many-requests';

  @override
  Future<AuthAccount?> restoredAccount() async {
    // The first event arrives once the SDK has read the persisted session.
    final user = await _auth.authStateChanges().first;
    return user == null ? null : _account(user);
  }

  @override
  Future<AuthAccount> signIn({
    required String email,
    required String password,
  }) {
    return _translating(
      () async {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _account(credential.user!);
      },
      rejections: {
        for (final code in _rejectedCredentials)
          code: AuthFailure.invalidCredentials,
      },
    );
  }

  @override
  Future<AuthAccount> createAccount({
    required String email,
    required String password,
  }) {
    return _translating(
      () async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _account(credential.user!);
      },
      rejections: const {
        'email-already-in-use': AuthFailure.emailAlreadyInUse,
        'weak-password': AuthFailure.weakPassword,
      },
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _translating(
        () => _auth.sendPasswordResetEmail(email: email),
        rejections: {
          for (final code in _rejectedCredentials)
            code: AuthFailure.invalidCredentials,
        },
      );
    } on AuthRejected {
      // An unknown address answers exactly like a known one.
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _translating<T>(
    Future<T> Function() call, {
    required Map<String, AuthFailure> rejections,
  }) async {
    try {
      return await call();
    } on FirebaseAuthException catch (error) {
      if (error.code == _noNetwork) throw const OfflineFailure();
      // Throttling is a rejection, not an outage: retrying at once would
      // only extend it.
      if (error.code == _throttled) {
        throw const AuthRejected(AuthFailure.unavailable);
      }
      final reason = rejections[error.code];
      if (reason != null) throw AuthRejected(reason);
      rethrow;
    }
  }

  AuthAccount _account(User user) =>
      AuthAccount(uid: user.uid, email: user.email ?? '');
}
