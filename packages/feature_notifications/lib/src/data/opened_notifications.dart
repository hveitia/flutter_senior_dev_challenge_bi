import 'dart:async';

import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/push_message.dart';

/// Holds the notification the customer tapped until the app can open it.
///
/// A tap can arrive when nobody is signed in or while the session is behind
/// its biometric lock. Opening it then would either lose it or show the
/// customer's screens without the lock, so it waits here, outside any
/// session, and whoever shows the customer's screens takes it when they are
/// up. Only the last one tapped is kept: the customer asked for one place.
final class OpenedNotifications {
  OpenedNotifications(this._messaging);

  final PushMessaging _messaging;
  final StreamController<void> _arrivals = StreamController<void>.broadcast(
    sync: true,
  );
  StreamSubscription<PushMessage>? _subscription;
  PushMessage? _pending;

  /// Fires when a notification is waiting to be taken.
  Stream<void> get arrivals => _arrivals.stream;

  /// Starts listening, once, and picks up the notification that started
  /// the app, if one did. Called when the app starts, before any session.
  void start() {
    if (_subscription != null) return;
    _subscription = _messaging.opened.listen(_keep);
    unawaited(_keepInitial());
  }

  Future<void> _keepInitial() async {
    try {
      final message = await _messaging.initialMessage();
      if (message != null) _keep(message);
    } on Object {
      // Without it the app simply opens where it always does.
    }
  }

  void _keep(PushMessage message) {
    _pending = message;
    _arrivals.add(null);
  }

  /// The waiting notification, handed over once.
  PushMessage? take() {
    final message = _pending;
    _pending = null;
    return message;
  }

  /// Forgets the waiting notification. Called when a session ends: what one
  /// customer tapped must not open for whoever signs in next.
  void drop() => _pending = null;

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _arrivals.close();
  }
}
