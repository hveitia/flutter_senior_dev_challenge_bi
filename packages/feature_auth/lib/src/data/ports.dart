import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';

/// The identity provider, reduced to what the repository needs.
///
/// Implementations throw [AuthRejected] when the provider refuses the
/// request, and an `AppFailure` from `app_platform` when it cannot be reached.
abstract interface class AuthGateway {
  /// The account restored from a previous run, once the SDK has loaded it.
  Future<AuthAccount?> restoredAccount();

  Future<AuthAccount> signIn({required String email, required String password});

  Future<AuthAccount> createAccount({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

/// Storage of customer profiles.
abstract interface class ProfileStore {
  /// The profile of [uid], or null when it was never stored.
  Future<UserProfile?> read(String uid);

  Future<void> create(UserProfile profile);

  /// Changes the segment and the interests of the stored profile of [uid],
  /// and nothing else.
  Future<void> updatePreferences(
    String uid, {
    required Segment segment,
    required Set<Interest> interests,
  });
}

/// Per-device preference: does this customer want a biometric check when
/// the session is restored here. Not personal data.
abstract interface class UnlockPreferences {
  Future<bool> isEnabled(String uid);

  Future<void> setEnabled(String uid, {required bool enabled});
}

/// The provider understood the request and refused it.
final class AuthRejected implements Exception {
  const AuthRejected(this.reason);

  final AuthFailure reason;

  @override
  String toString() => 'AuthRejected(${reason.name})';
}
