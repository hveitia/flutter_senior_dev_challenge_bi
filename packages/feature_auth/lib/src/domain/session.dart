import 'package:equatable/equatable.dart';
import 'package:feature_auth/src/domain/user_profile.dart';

/// Who is using the app, as the repository knows it.
sealed class Session extends Equatable {
  const Session();
}

final class SignedOutSession extends Session {
  const SignedOutSession();

  @override
  List<Object?> get props => const [];
}

/// Signed in with a stored profile.
final class ActiveSession extends Session {
  const ActiveSession(this.profile, {required this.unlockRequired});

  final UserProfile profile;

  /// The session was restored on a device where the customer asked for a
  /// biometric check before entering.
  final bool unlockRequired;

  @override
  List<Object?> get props => [profile, unlockRequired];
}

/// The account exists but its profile was never stored: sign-up stopped
/// halfway. The customer has to complete it before using the app.
final class IncompleteSession extends Session {
  const IncompleteSession(this.account, {this.unsavedDraft});

  final AuthAccount account;

  /// What the customer had typed when storing the profile failed, kept in
  /// memory only so they do not have to type it again.
  final ProfileDraft? unsavedDraft;

  @override
  List<Object?> get props => [account, unsavedDraft];
}

/// Signed in, but the profile could not be read (no connection and nothing
/// cached, or the backend did not answer).
final class UnavailableSession extends Session {
  const UnavailableSession(this.account);

  final AuthAccount account;

  @override
  List<Object?> get props => [account];
}
