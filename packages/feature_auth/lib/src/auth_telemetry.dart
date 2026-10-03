/// Names of what the access flows report. Parameters carry step numbers and
/// failure kinds only: never an email, a name, a cédula or a phone number.
abstract final class AuthTelemetry {
  static const String sessionRestored = 'auth_session_restored';
  static const String signInSucceeded = 'auth_sign_in_succeeded';
  static const String signInFailed = 'auth_sign_in_failed';
  static const String signUpStepCompleted = 'auth_sign_up_step_completed';
  static const String signUpInterestsSkipped = 'auth_sign_up_interests_skipped';
  static const String signUpSucceeded = 'auth_sign_up_succeeded';
  static const String signUpFailed = 'auth_sign_up_failed';

  /// The account was created but its profile could not be stored.
  static const String profileSaveFailed = 'auth_profile_save_failed';
  static const String profileCompleted = 'auth_profile_completed';
  static const String passwordResetRequested = 'auth_password_reset_requested';
  static const String unlockSucceeded = 'auth_unlock_succeeded';
  static const String unlockFailed = 'auth_unlock_failed';
  static const String signedOut = 'auth_signed_out';

  static const String reasonKey = 'reason';
  static const String stepKey = 'step';
  static const String outcomeKey = 'outcome';

  /// Reason attached to an error the provider did not explain.
  static const String unexpectedError = 'auth_unexpected';

  /// Backend services, as named to the resilience policy.
  static const String authService = 'auth';
  static const String profileService = 'profile';
}

/// Values of [AuthTelemetry.outcomeKey] for a restored session.
abstract final class RestoreOutcome {
  static const String signedOut = 'signed_out';
  static const String active = 'active';
  static const String profileIncomplete = 'profile_incomplete';
  static const String unavailable = 'unavailable';
}
