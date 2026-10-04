import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/push_message.dart';
import 'package:feature_notifications/src/notifications_telemetry.dart';

/// Keeps this device registered for the signed-in customer while the system
/// allows notifications, and forgets it when the session ends.
///
/// One per signed-in customer. Its operations run one at a time, in the
/// order they were asked for: a sign-out that arrives while a registration
/// is still in flight waits for it and then undoes it.
final class DeviceRegistrar {
  DeviceRegistrar({
    required PushMessaging messaging,
    required DeviceStore devices,
    required DeviceIdentity identity,
    Telemetry telemetry = const NoopTelemetry(),
    this.forgetTimeout = defaultForgetTimeout,
  }) : _messaging = messaging,
       _devices = devices,
       _identity = identity,
       _telemetry = telemetry;

  /// How long signing out waits for the device to be forgotten. Past it the
  /// session ends anyway: a customer is never kept signed in by a network
  /// that does not answer.
  static const Duration defaultForgetTimeout = Duration(seconds: 5);

  /// Steps named in [NotificationsTelemetry.deviceFailed].
  static const String registerStep = 'register';
  static const String subscribeStep = 'subscribe';
  static const String unsubscribeStep = 'unsubscribe';
  static const String removeStep = 'remove';
  static const String deleteTokenStep = 'delete_token';

  final PushMessaging _messaging;
  final DeviceStore _devices;
  final DeviceIdentity _identity;
  final Telemetry _telemetry;
  final Duration forgetTimeout;

  Future<void> _last = Future.value();
  StreamSubscription<String>? _tokenChanges;
  String? _topic;
  bool _isRegistered = false;
  bool _isForgotten = false;

  /// Registers the device for the customer and follows their segment's
  /// topic. Does nothing unless the system allows notifications, and nothing
  /// when it is already registered for that segment.
  Future<void> register(String segmentId) => _enqueue(() async {
    if (_isForgotten) return;
    if (await _messaging.permission() != NotificationPermission.granted) {
      return;
    }

    if (!_isRegistered) {
      final saved = await _attempt(registerStep, _saveCurrentToken);
      if (!saved) return;
      _isRegistered = true;
      _tokenChanges ??= _messaging.tokenChanges.listen(_onTokenChanged);
      _telemetry.event(NotificationsTelemetry.deviceRegistered);
    }
    await _follow(segmentTopic(segmentId));
  });

  /// Forgets the device: stops following the segment, removes the
  /// registration and deletes the local address, so nothing sent to the
  /// customer reaches this device afterwards.
  ///
  /// It never throws and never takes longer than [forgetTimeout]. After it,
  /// this registrar registers nothing again.
  Future<void> forget() {
    final forgotten = _enqueue(() async {
      _isForgotten = true;
      // Not waited for: from here on a new address is ignored anyway.
      unawaited(_tokenChanges?.cancel());
      _tokenChanges = null;

      if (_topic case final topic?) {
        await _attempt(unsubscribeStep, () => _messaging.unsubscribe(topic));
        _topic = null;
      }
      if (_isRegistered) {
        await _attempt(removeStep, () async {
          await _devices.remove(await _identity.id());
        });
        await _attempt(deleteTokenStep, _messaging.deleteToken);
        _isRegistered = false;
      }
    });
    return forgotten.timeout(forgetTimeout, onTimeout: () {});
  }

  Future<void> _saveCurrentToken() async {
    final token = await _messaging.token();
    if (token == null) throw StateError('no token');
    await _save(token);
  }

  Future<void> _save(String token) async {
    await _devices.save(
      deviceId: await _identity.id(),
      token: token,
      platform: _identity.platform,
    );
  }

  /// The service replaced the address: the registration follows it.
  void _onTokenChanged(String token) {
    unawaited(
      _enqueue(() async {
        if (_isForgotten) return;
        await _attempt(registerStep, () => _save(token));
      }),
    );
  }

  /// A customer who changes segment stops hearing the previous one.
  Future<void> _follow(String topic) async {
    if (_topic == topic) return;
    if (_topic case final previous?) {
      await _attempt(unsubscribeStep, () => _messaging.unsubscribe(previous));
      _topic = null;
    }
    final subscribed = await _attempt(
      subscribeStep,
      () => _messaging.subscribe(topic),
    );
    if (subscribed) _topic = topic;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    return _last = _last.then((_) => operation());
  }

  /// Runs one step. A failure is reported with the step only: its message
  /// could quote the address of the device.
  Future<bool> _attempt(String step, Future<void> Function() run) async {
    try {
      await run();
      return true;
    } on Object catch (error, stackTrace) {
      _telemetry
        ..event(
          NotificationsTelemetry.deviceFailed,
          parameters: {NotificationsTelemetry.stepKey: step},
        )
        ..recordError(
          RedactedError(error.runtimeType),
          stackTrace,
          reason: NotificationsTelemetry.deviceFailed,
        );
      return false;
    }
  }
}
