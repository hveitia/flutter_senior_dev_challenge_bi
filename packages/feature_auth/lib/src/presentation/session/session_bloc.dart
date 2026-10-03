import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_auth/src/auth_telemetry.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/biometric_authenticator.dart';
import 'package:feature_auth/src/domain/session.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';

sealed class SessionEvent {
  const SessionEvent();
}

/// The app started: find out who, if anyone, is signed in.
final class SessionStarted extends SessionEvent {
  const SessionStarted();
}

final class SessionUnlockRequested extends SessionEvent {
  const SessionUnlockRequested();
}

final class SessionRetryRequested extends SessionEvent {
  const SessionRetryRequested();
}

final class SessionSignOutRequested extends SessionEvent {
  const SessionSignOutRequested();
}

final class _SessionAnnounced extends SessionEvent {
  const _SessionAnnounced(this.session);

  final Session session;
}

/// What the app shows depending on who is signed in.
sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => const [];
}

/// Still finding out. The splash stays on screen.
final class SessionStarting extends SessionState {
  const SessionStarting();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

/// A session was restored and waits for the biometric check.
final class SessionLocked extends SessionState {
  const SessionLocked(this.profile, {this.lastAttemptFailed = false});

  final UserProfile profile;
  final bool lastAttemptFailed;

  @override
  List<Object?> get props => [profile, lastAttemptFailed];
}

final class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

/// The account has no profile yet; the customer must complete it.
final class SessionProfilePending extends SessionState {
  const SessionProfilePending({required this.email, this.unsavedDraft});

  final String email;
  final ProfileDraft? unsavedDraft;

  @override
  List<Object?> get props => [email, unsavedDraft];
}

/// Signed in, but the profile could not be loaded.
final class SessionUnavailable extends SessionState {
  const SessionUnavailable({this.isRetrying = false});

  final bool isRetrying;

  @override
  List<Object?> get props => [isRetrying];
}

/// Handles each event only after the previous one has finished.
///
/// Bloc runs handlers concurrently by default. Deciding what to show for a
/// session can wait on the device, so a later session could be shown first
/// and then be overwritten by the older one.
EventTransformer<E> _oneAtATime<E>() =>
    (events, mapper) => events.asyncExpand(mapper);

/// Decides which part of the app the customer sees: it follows the session
/// the repository announces and adds the biometric lock on top of it.
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc({
    required AuthRepository repository,
    required BiometricAuthenticator biometrics,
    String unlockReason = AuthStrings.unlockReason,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _repository = repository,
       _biometrics = biometrics,
       _unlockReason = unlockReason,
       _telemetry = telemetry,
       super(const SessionStarting()) {
    on<SessionStarted>(_onStarted);
    on<_SessionAnnounced>(_onAnnounced, transformer: _oneAtATime());
    on<SessionUnlockRequested>(_onUnlockRequested);
    on<SessionRetryRequested>(_onRetryRequested);
    on<SessionSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _repository;
  final BiometricAuthenticator _biometrics;

  /// Text of the system prompt.
  final String _unlockReason;
  final Telemetry _telemetry;

  StreamSubscription<Session>? _sessions;

  /// How many sessions the repository has announced so far.
  int _announcements = 0;

  Future<void> _onStarted(
    SessionStarted event,
    Emitter<SessionState> emit,
  ) async {
    if (_sessions != null) return;
    _sessions = _repository.sessions.listen((session) {
      _announcements++;
      add(_SessionAnnounced(session));
    });
    await _repository.restore();
  }

  Future<void> _onAnnounced(
    _SessionAnnounced event,
    Emitter<SessionState> emit,
  ) async {
    switch (event.session) {
      case SignedOutSession():
        emit(const SessionSignedOut());
      case UnavailableSession():
        emit(const SessionUnavailable());
      case IncompleteSession(:final account, :final unsavedDraft):
        emit(
          SessionProfilePending(
            email: account.email,
            unsavedDraft: unsavedDraft,
          ),
        );
      case ActiveSession(:final profile, unlockRequired: false):
        emit(SessionSignedIn(profile));
      case ActiveSession(:final profile, unlockRequired: true):
        if (await _biometrics.isAvailable()) {
          emit(SessionLocked(profile));
        } else {
          // The customer removed their biometrics from the device. The
          // password still proves who they are.
          await _repository.signOut();
        }
    }
  }

  Future<void> _onUnlockRequested(
    SessionUnlockRequested event,
    Emitter<SessionState> emit,
  ) async {
    final locked = state;
    if (locked is! SessionLocked) return;

    final passed = await _passesBiometricCheck();
    // The system prompt can stay open while the session changes underneath,
    // for instance when it is signed out. Its answer then opens nothing.
    if (state != locked) return;

    if (passed) {
      _telemetry.event(AuthTelemetry.unlockSucceeded);
      emit(SessionSignedIn(locked.profile));
    } else {
      _telemetry.event(AuthTelemetry.unlockFailed);
      emit(SessionLocked(locked.profile, lastAttemptFailed: true));
    }
  }

  Future<bool> _passesBiometricCheck() async {
    try {
      return await _biometrics.authenticate(reason: _unlockReason);
    } on Object {
      // A sensor that is locked out or cancelled throws. Either way the
      // check did not pass.
      return false;
    }
  }

  Future<void> _onRetryRequested(
    SessionRetryRequested event,
    Emitter<SessionState> emit,
  ) async {
    if (state is! SessionUnavailable) return;
    final announcedBefore = _announcements;
    emit(const SessionUnavailable(isRetrying: true));
    await _repository.retry();

    // A retry normally ends with a new session, which replaces this state.
    // When the repository had nothing to retry it announces none, and the
    // progress indicator would stay forever.
    if (_announcements == announcedBefore) emit(const SessionUnavailable());
  }

  Future<void> _onSignOutRequested(
    SessionSignOutRequested event,
    Emitter<SessionState> emit,
  ) => _repository.signOut();

  @override
  Future<void> close() async {
    await _sessions?.cancel();
    return super.close();
  }
}
