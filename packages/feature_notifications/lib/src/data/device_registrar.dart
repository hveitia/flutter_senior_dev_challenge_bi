import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/push_message.dart';
import 'package:feature_notifications/src/notifications_telemetry.dart';

/// Keeps this device registered for one signed-in customer while the system
/// allows notifications, and forgets it when their session ends.
///
/// One per session. Its operations run one at a time, in the order they
/// were asked for, and a step that fails never stops the ones after it.
///
/// What the device is registered for is also written on the device itself
/// ([RegistrationMemory]), outside any session. That is what lets a phone
/// that changes hands be cleaned before it is registered for someone else,
/// even if the previous session ended without a chance to clean up.
final class DeviceRegistrar {
  DeviceRegistrar({
    required String uid,
    required PushMessaging messaging,
    required DeviceStore devices,
    required DeviceIdentity identity,
    required RegistrationMemory memory,
    Telemetry telemetry = const NoopTelemetry(),
    this.forgetTimeout = defaultForgetTimeout,
  }) : _uid = uid,
       _messaging = messaging,
       _devices = devices,
       _identity = identity,
       _memory = memory,
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

  final String _uid;
  final PushMessaging _messaging;
  final DeviceStore _devices;
  final DeviceIdentity _identity;
  final RegistrationMemory _memory;
  final Telemetry _telemetry;
  final Duration forgetTimeout;

  Future<void> _last = Future.value();
  StreamSubscription<String>? _tokenChanges;

  /// The device document was written by this registrar, so it is current.
  bool _isSaved = false;
  bool _isForgotten = false;

  /// Whether [forget] or [forgetLocally] was called. A forgotten registrar
  /// registers nothing again: the next session gets a new one.
  bool get isForgotten => _isForgotten;

  /// Brings the registration in line with what the system allows.
  ///
  /// With permission, the device is registered for the customer and follows
  /// their segment's topic and no other. Without it, a registration made
  /// earlier is withdrawn. Either way, whatever a previous customer left on
  /// this device is dropped first.
  Future<void> register(String segmentId) => _enqueue(registerStep, () async {
    if (_isForgotten) return;
    if (!await _dropPreviousCustomer()) return;

    final permission = await _messaging.permission();
    if (_isForgotten) return;
    if (permission != NotificationPermission.granted) {
      await _withdraw(removeDocument: true);
      return;
    }

    if (!_isSaved) {
      if (!await _attempt(registerStep, _saveCurrentToken)) return;
      if (_isForgotten) return;
      _tokenChanges ??= _messaging.tokenChanges.listen(_onTokenChanged);
      _telemetry.event(NotificationsTelemetry.deviceRegistered);
    }
    await _follow(segmentTopic(segmentId));
  });

  /// Forgets the device while the session is still open: stops following
  /// the segment, removes the registration and deletes the local address,
  /// so nothing sent to the customer reaches this device afterwards.
  ///
  /// It takes effect at once: from this call on nothing is registered, even
  /// by a step that was already in flight. It never throws and never keeps
  /// the caller longer than [forgetTimeout].
  Future<void> forget() => _forget(removeDocument: true);

  /// Forgets the device after the session already ended, by whatever path.
  ///
  /// The topic and the local address need no session to be dropped. The
  /// device document does, so it is left: its address is dead once deleted,
  /// the sender flags it the next time it tries, and the same customer
  /// replaces it when they register again.
  Future<void> forgetLocally() => _forget(removeDocument: false);

  Future<void> _forget({required bool removeDocument}) {
    // Before anything is queued: a registration in flight checks this
    // between its steps.
    _isForgotten = true;
    return _enqueue(
      removeStep,
      () => _withdraw(removeDocument: removeDocument),
    ).timeout(forgetTimeout, onTimeout: () {});
  }

  /// Drops the topics and the address a different customer left registered
  /// on this device. False when the address could not be dropped: saving it
  /// for this customer would leave it registered for two.
  Future<bool> _dropPreviousCustomer() async {
    final previous = _memory.uid;
    if (previous == null || previous == _uid) return true;

    for (final topic in _memory.topics) {
      await _attempt(unsubscribeStep, () => _messaging.unsubscribe(topic));
    }
    // Deleting the address also ends every subscription made with it, and
    // leaves the previous customer's device document pointing nowhere.
    if (!await _attempt(deleteTokenStep, _messaging.deleteToken)) return false;
    await _memory.save(uid: null, topics: {});
    return true;
  }

  /// Undoes this customer's registration on this device.
  Future<void> _withdraw({required bool removeDocument}) async {
    final registered = _memory.uid == _uid;
    final topics = _memory.topics;
    if (!registered && topics.isEmpty) return;

    unawaited(_tokenChanges?.cancel());
    _tokenChanges = null;
    _isSaved = false;

    final stillFollowed = <String>{};
    for (final topic in topics) {
      final left = await _attempt(
        unsubscribeStep,
        () => _messaging.unsubscribe(topic),
      );
      if (!left) stillFollowed.add(topic);
    }
    if (removeDocument && registered) {
      await _attempt(removeStep, () async {
        await _devices.remove(await _identity.id());
      });
    }
    final deleted = await _attempt(deleteTokenStep, _messaging.deleteToken);

    // What could not be dropped stays on record, so the next registration
    // on this device drops it before doing anything else.
    await _memory.save(
      uid: deleted ? null : _memory.uid,
      topics: deleted ? {} : stillFollowed,
    );
  }

  Future<void> _saveCurrentToken() async {
    final token = await _messaging.token();
    if (token == null) throw StateError('no token');
    await _save(token);
  }

  Future<void> _save(String token) async {
    final deviceId = await _identity.id();
    // The session may have ended while the address was being fetched.
    if (_isForgotten) return;
    await _devices.save(
      deviceId: deviceId,
      token: token,
      platform: _identity.platform,
    );
    _isSaved = true;
    await _memory.save(uid: _uid, topics: _memory.topics);
  }

  /// The service replaced the address: the registration follows it.
  void _onTokenChanged(String token) {
    unawaited(
      _enqueue(registerStep, () async {
        if (_isForgotten) return;
        await _attempt(registerStep, () => _save(token));
      }),
    );
  }

  /// Follows [topic] and no other.
  Future<void> _follow(String topic) async {
    for (final previous in _memory.topics.difference({topic})) {
      if (_isForgotten) return;
      final left = await _attempt(
        unsubscribeStep,
        () => _messaging.unsubscribe(previous),
      );
      if (left) {
        await _memory.save(
          uid: _uid,
          topics: _memory.topics.difference({previous}),
        );
      } else {
        // A topic that cannot be left would make the device hear two
        // segments. A new address has no subscriptions at all.
        if (!await _replaceAddress()) return;
        break;
      }
    }

    if (_isForgotten || _memory.topics.contains(topic)) return;
    final subscribed = await _attempt(
      subscribeStep,
      () => _messaging.subscribe(topic),
    );
    if (subscribed) await _memory.save(uid: _uid, topics: {topic});
  }

  /// Deletes the address and registers the one the service gives next.
  Future<bool> _replaceAddress() async {
    if (!await _attempt(deleteTokenStep, _messaging.deleteToken)) return false;
    _isSaved = false;
    await _memory.save(uid: _uid, topics: {});
    return _attempt(registerStep, _saveCurrentToken);
  }

  /// Queues [operation] behind the ones already asked for. Whatever it
  /// throws is reported under [step] and ends there: a failed operation
  /// must not keep the next one, a sign-out in particular, from running.
  Future<void> _enqueue(String step, Future<void> Function() operation) {
    return _last = _last.then((_) async {
      try {
        await operation();
      } on Object catch (error, stackTrace) {
        _report(step, error, stackTrace);
      }
    });
  }

  /// Runs one step. A failure is reported with the step only.
  Future<bool> _attempt(String step, Future<void> Function() run) async {
    try {
      await run();
      return true;
    } on Object catch (error, stackTrace) {
      _report(step, error, stackTrace);
      return false;
    }
  }

  /// The message of the error could quote the address of the device, so
  /// only its type is reported.
  void _report(String step, Object error, StackTrace stackTrace) {
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
  }
}
