import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_auth/src/auth_telemetry.dart';
import 'package:feature_auth/src/data/ports.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/session.dart';
import 'package:feature_auth/src/domain/user_profile.dart';

/// [AuthRepository] over an identity provider and a profile store.
///
/// Every backend call goes through the resilience policy. Reads and sign-in
/// are declared idempotent and may be retried; creating the account and
/// storing the profile run exactly once.
final class DefaultAuthRepository implements AuthRepository {
  DefaultAuthRepository({
    required AuthGateway gateway,
    required ProfileStore profiles,
    required UnlockPreferences unlockPreferences,
    required ResiliencePolicy policy,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _gateway = gateway,
       _profiles = profiles,
       _unlockPreferences = unlockPreferences,
       _policy = policy,
       _telemetry = telemetry;

  final AuthGateway _gateway;
  final ProfileStore _profiles;
  final UnlockPreferences _unlockPreferences;
  final ResiliencePolicy _policy;
  final Telemetry _telemetry;

  final StreamController<Session> _sessions =
      StreamController<Session>.broadcast();
  Session _current = const SignedOutSession();

  @override
  Stream<Session> get sessions => _sessions.stream;

  @override
  Future<void> restore() async {
    final account = await _restoredAccount();
    if (account == null) {
      _announce(const SignedOutSession());
      _reportRestore(RestoreOutcome.signedOut);
      return;
    }
    await _announceRestored(account);
  }

  @override
  Future<void> retry() async {
    final session = _current;
    if (session is UnavailableSession) await _announceRestored(session.account);
  }

  @override
  Future<AuthResult<void>> signIn({
    required String email,
    required String password,
  }) async {
    final signedIn = await _policy.run(
      () => _gateway.signIn(email: email, password: password),
      // Checking credentials changes nothing, so it is safe to repeat.
      idempotent: true,
      serviceId: AuthTelemetry.authService,
    );

    switch (signedIn) {
      case Failed(:final failure):
        return _failed(AuthTelemetry.signInFailed, failure);
      case Success(value: final account):
        switch (await _readProfile(account)) {
          case Failed(:final failure):
            // Without the profile there is nothing to show. Leaving the
            // provider signed in would restore a broken session next time.
            await _signOutQuietly();
            return _failed(AuthTelemetry.signInFailed, failure);
          case Success(value: final profile):
            _telemetry.event(AuthTelemetry.signInSucceeded);
            _announce(
              profile == null
                  ? IncompleteSession(account)
                  // The customer has just proven who they are.
                  : ActiveSession(profile, unlockRequired: false),
            );
            return const AuthOk(null);
        }
    }
  }

  @override
  Future<AuthResult<void>> signUp(SignUpRequest request) async {
    final created = await _policy.run(
      () => _gateway.createAccount(
        email: request.email,
        password: request.password,
      ),
      idempotent: false,
      serviceId: AuthTelemetry.authService,
    );

    switch (created) {
      case Failed(:final failure):
        return _failed(AuthTelemetry.signUpFailed, failure);
      case Success(value: final account):
        if (request.biometricUnlock) await _rememberUnlock(account.uid);
        switch (await _storeProfile(account, request.profile)) {
          case Failed(:final failure):
            // The account cannot be taken back. The customer goes on to
            // complete the profile, keeping what they typed.
            _telemetry.event(
              AuthTelemetry.profileSaveFailed,
              parameters: {
                AuthTelemetry.reasonKey: _asAuthFailure(failure).name,
              },
            );
            _announce(
              IncompleteSession(account, unsavedDraft: request.profile),
            );
          case Success(value: final profile):
            _telemetry.event(AuthTelemetry.signUpSucceeded);
            _announce(ActiveSession(profile, unlockRequired: false));
        }
        return const AuthOk(null);
    }
  }

  @override
  Future<AuthResult<void>> completeProfile(ProfileDraft draft) async {
    final session = _current;
    if (session is! IncompleteSession) {
      return const AuthError(AuthFailure.unexpected);
    }
    final account = session.account;

    // The write that seemed to fail may have reached the backend. Writing a
    // second time would then be an update, which the rules reject.
    final existing = await _readProfile(account);
    if (existing case Success(value: final profile?)) {
      return _completed(profile);
    }

    switch (await _storeProfile(account, draft)) {
      case Failed(:final failure):
        _announce(IncompleteSession(account, unsavedDraft: draft));
        return _failed(AuthTelemetry.profileSaveFailed, failure);
      case Success(value: final profile):
        return _completed(profile);
    }
  }

  @override
  Future<AuthResult<void>> sendPasswordReset(String email) async {
    final sent = await _policy.run(
      () => _gateway.sendPasswordReset(email),
      // Asking twice sends the same link twice; nothing else changes.
      idempotent: true,
      serviceId: AuthTelemetry.authService,
    );

    switch (sent) {
      case Failed(:final failure):
        return AuthError(_asAuthFailure(failure));
      case Success():
        _telemetry.event(AuthTelemetry.passwordResetRequested);
        return const AuthOk(null);
    }
  }

  @override
  Future<void> signOut() async {
    await _gateway.signOut();
    _telemetry.event(AuthTelemetry.signedOut);
    _announce(const SignedOutSession());
  }

  Future<AuthAccount?> _restoredAccount() async {
    try {
      return await _gateway.restoredAccount();
    } on Object catch (error, stackTrace) {
      // A provider that cannot even say who is signed in leaves the customer
      // at the sign-in screen, which always works.
      _reportUnexpected(error, stackTrace);
      return null;
    }
  }

  Future<void> _announceRestored(AuthAccount account) async {
    switch (await _readProfile(account)) {
      case Failed():
        _announce(UnavailableSession(account));
        _reportRestore(RestoreOutcome.unavailable);
      case Success(value: null):
        _announce(
          IncompleteSession(
            account,
            unlockRequired: await _isUnlockRequired(account.uid),
          ),
        );
        _reportRestore(RestoreOutcome.profileIncomplete);
      case Success(value: final profile?):
        _announce(
          ActiveSession(
            profile,
            unlockRequired: await _isUnlockRequired(account.uid),
          ),
        );
        _reportRestore(RestoreOutcome.active);
    }
  }

  /// The account already exists when this runs, so a device that cannot
  /// store the preference must not stop the profile from being stored. The
  /// customer simply is not asked for the check on this device.
  Future<void> _rememberUnlock(String uid) async {
    try {
      await _unlockPreferences.setEnabled(uid, enabled: true);
    } on Object catch (error, stackTrace) {
      _reportUnexpected(error, stackTrace);
    }
  }

  /// A preference that cannot be read counts as enabled: asking for a check
  /// the customer did not choose costs them a moment, skipping one they did
  /// choose opens their session to whoever holds the device.
  Future<bool> _isUnlockRequired(String uid) async {
    try {
      return await _unlockPreferences.isEnabled(uid);
    } on Object catch (error, stackTrace) {
      _reportUnexpected(error, stackTrace);
      return true;
    }
  }

  /// Signs out as cleanup after another failure, which is the one the caller
  /// reports. If this fails too, the next start finds the account without a
  /// readable profile and handles it as a restored session.
  Future<void> _signOutQuietly() async {
    try {
      await _gateway.signOut();
    } on Object catch (error, stackTrace) {
      _reportUnexpected(error, stackTrace);
    }
  }

  Future<Result<UserProfile?>> _readProfile(AuthAccount account) {
    return _policy.run(
      () => _profiles.read(account.uid),
      idempotent: true,
      serviceId: AuthTelemetry.profileService,
    );
  }

  Future<Result<UserProfile>> _storeProfile(
    AuthAccount account,
    ProfileDraft draft,
  ) {
    final profile = UserProfile.fromDraft(account, draft);
    return _policy.run(
      () async {
        await _profiles.create(profile);
        return profile;
      },
      // A repeated write is an update, and the rules only allow creating.
      idempotent: false,
      serviceId: AuthTelemetry.profileService,
    );
  }

  AuthResult<void> _completed(UserProfile profile) {
    _telemetry.event(AuthTelemetry.profileCompleted);
    _announce(ActiveSession(profile, unlockRequired: false));
    return const AuthOk(null);
  }

  AuthResult<void> _failed(String event, AppFailure failure) {
    final reason = _asAuthFailure(failure);
    _telemetry.event(
      event,
      parameters: {AuthTelemetry.reasonKey: reason.name},
    );
    return AuthError(reason);
  }

  AuthFailure _asAuthFailure(AppFailure failure) {
    switch (failure) {
      case OfflineFailure():
        return AuthFailure.offline;
      case TimeoutFailure() || ServiceUnavailableFailure():
        return AuthFailure.unavailable;
      case UnexpectedFailure(cause: AuthRejected(:final reason)):
        return reason;
      case UnexpectedFailure(:final cause, :final stackTrace):
        _reportUnexpected(cause, stackTrace);
        return AuthFailure.unexpected;
    }
  }

  /// Provider errors can quote the email they were given, so only the type
  /// of the error is reported.
  void _reportUnexpected(Object error, StackTrace stackTrace) {
    _telemetry.recordError(
      RedactedError(error.runtimeType),
      stackTrace,
      reason: AuthTelemetry.unexpectedError,
    );
  }

  void _reportRestore(String outcome) {
    _telemetry.event(
      AuthTelemetry.sessionRestored,
      parameters: {AuthTelemetry.outcomeKey: outcome},
    );
  }

  void _announce(Session session) {
    _current = session;
    _sessions.add(session);
  }
}
