import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/session.dart';
import 'package:feature_auth/src/domain/user_profile.dart';

/// What sign-up needs to create the account and its profile.
final class SignUpRequest {
  const SignUpRequest({
    required this.email,
    required this.password,
    required this.profile,
    required this.biometricUnlock,
  });

  final String email;
  final String password;
  final ProfileDraft profile;

  /// Ask for a biometric check when this device restores the session.
  final bool biometricUnlock;
}

/// Access to the customer's account and profile.
///
/// Every change of who is signed in is announced on [sessions]; the methods
/// return only whether the operation they were asked for went through.
abstract interface class AuthRepository {
  /// Emits each time the session changes. It does not replay: subscribe
  /// before calling [restore].
  Stream<Session> get sessions;

  /// Finds out whether a session survived from a previous run.
  Future<void> restore();

  Future<AuthResult<void>> signIn({
    required String email,
    required String password,
  });

  /// Creates the account and then stores the profile.
  ///
  /// Succeeds as soon as the account exists. If storing the profile fails,
  /// the session becomes [IncompleteSession] and the customer finishes
  /// through [completeProfile].
  Future<AuthResult<void>> signUp(SignUpRequest request);

  /// Stores the profile of an account that has none.
  Future<AuthResult<void>> completeProfile(ProfileDraft draft);

  /// Tries again to read the profile after [UnavailableSession].
  Future<void> retry();

  /// Asks for a password reset email. The outcome never reveals whether the
  /// address belongs to an account.
  Future<AuthResult<void>> sendPasswordReset(String email);

  Future<void> signOut();
}
