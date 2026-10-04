import 'package:app_platform/app_platform.dart';
import 'package:feature_notifications/src/data/device_registrar.dart';
import 'package:feature_notifications/src/data/ports.dart';

/// Hands out the registrar of the session in course and cleans up after a
/// session that ended.
///
/// It lives as long as the app, outside the customer's screens. That is
/// what lets it act when a session ends by a path that never passes through
/// those screens: a revoked or expired session, or biometrics removed from
/// the device.
final class DeviceRegistrations {
  DeviceRegistrations({
    required PushMessaging messaging,
    required DeviceStore Function(String uid) devicesFor,
    required DeviceIdentity identity,
    required RegistrationMemory memory,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _messaging = messaging,
       _devicesFor = devicesFor,
       _identity = identity,
       _memory = memory,
       _telemetry = telemetry;

  final PushMessaging _messaging;
  final DeviceStore Function(String uid) _devicesFor;
  final DeviceIdentity _identity;
  final RegistrationMemory _memory;
  final Telemetry _telemetry;

  DeviceRegistrar? _current;
  String? _uid;

  /// The registrar of the customer's session. The same one for as long as
  /// the session lasts; a new one once it was forgotten, since a forgotten
  /// registrar registers nothing again, not even for the same customer.
  DeviceRegistrar of(String uid) {
    if (_current case final current? when _uid == uid && !current.isForgotten) {
      return current;
    }
    _uid = uid;
    return _current = _registrarFor(uid);
  }

  /// A session ended, by whatever path. What can still be done without it
  /// is done: the topic is left and the local address deleted, so nothing
  /// sent to that customer reaches this device.
  ///
  /// After a sign-out that already cleaned up, this finds nothing to do.
  /// It also covers a session that ended while the app was not running: it
  /// works from what the device remembers, not from what this run did.
  Future<void> sessionEnded() {
    final registrar = _current ?? _registrarFromMemory();
    _current = null;
    _uid = null;
    return registrar?.forgetLocally() ?? Future.value();
  }

  DeviceRegistrar? _registrarFromMemory() {
    final uid = _memory.uid;
    if (uid == null && _memory.topics.isEmpty) return null;
    return _registrarFor(uid ?? '');
  }

  DeviceRegistrar _registrarFor(String uid) => DeviceRegistrar(
    uid: uid,
    messaging: _messaging,
    devices: _devicesFor(uid),
    identity: _identity,
    memory: _memory,
    telemetry: _telemetry,
  );
}
