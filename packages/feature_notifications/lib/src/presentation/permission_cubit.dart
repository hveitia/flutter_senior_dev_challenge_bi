import 'package:app_platform/app_platform.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/push_message.dart';
import 'package:feature_notifications/src/notifications_telemetry.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class PermissionState extends Equatable {
  const PermissionState({
    this.permission,
    this.isPrimerDue = false,
    this.isAsking = false,
  });

  /// Null until the system has been asked what it allows.
  final NotificationPermission? permission;

  /// The invitation should be shown now: the system has not asked yet and
  /// the customer has not answered the app's own invitation on this device.
  final bool isPrimerDue;

  /// The system prompt is on screen.
  final bool isAsking;

  bool get isGranted => permission == NotificationPermission.granted;

  /// Switched off in the system: only its settings can turn it on.
  bool get isDenied => permission == NotificationPermission.denied;

  /// The customer said "Ahora no" before and may still be invited when they
  /// ask for it.
  bool get canInvite =>
      permission == NotificationPermission.notAsked && !isPrimerDue;

  @override
  List<Object?> get props => [permission, isPrimerDue, isAsking];
}

/// Decides when the customer is invited to turn notifications on, and asks
/// the system only after they accept.
///
/// The system shows its prompt once. Spending it at start-up, before the
/// customer knows what the notifications are for, wastes it; so the app
/// explains first and remembers the answer on the device.
final class PermissionCubit extends Cubit<PermissionState> {
  PermissionCubit({
    required PushMessaging messaging,
    required PrimerMemory memory,
    required SystemSettings settings,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _messaging = messaging,
       _memory = memory,
       _settings = settings,
       _telemetry = telemetry,
       super(const PermissionState());

  final PushMessaging _messaging;
  final PrimerMemory _memory;
  final SystemSettings _settings;
  final Telemetry _telemetry;

  /// Reads what the system allows. Called when the customer signs in and
  /// again whenever the app comes back to the front, since the customer may
  /// have changed it in the system settings meanwhile.
  Future<void> check() async {
    final permission = await _messaging.permission();
    if (isClosed) return;
    emit(
      PermissionState(
        permission: permission,
        isPrimerDue:
            permission == NotificationPermission.notAsked &&
            !_memory.wasAnswered,
        isAsking: state.isAsking,
      ),
    );
  }

  /// The invitation is on screen.
  void primerShown() => _telemetry.event(NotificationsTelemetry.primerShown);

  /// The customer accepted the invitation: now the system may ask.
  Future<void> accept() async {
    if (state.isAsking) return;
    emit(PermissionState(permission: state.permission, isAsking: true));
    _telemetry.event(NotificationsTelemetry.primerAccepted);
    await _memory.rememberAnswered();

    final permission = await _messaging.requestPermission();
    _telemetry.event(
      NotificationsTelemetry.permissionResult,
      parameters: {NotificationsTelemetry.resultKey: permission.name},
    );
    if (isClosed) return;
    emit(PermissionState(permission: permission));
  }

  /// "Ahora no". The app does not invite again by itself on this device.
  Future<void> decline() async {
    _telemetry.event(NotificationsTelemetry.primerDeclined);
    await _memory.rememberAnswered();
    if (isClosed) return;
    emit(PermissionState(permission: state.permission));
  }

  Future<void> openSystemSettings() => _settings.openNotificationSettings();
}
