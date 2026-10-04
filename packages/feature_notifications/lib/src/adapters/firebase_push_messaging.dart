import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/inbox_item.dart';
import 'package:feature_notifications/src/domain/push_message.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys of the data a push carries, as the console sends them.
abstract final class PushDataKeys {
  static const String destination = 'destination';
  static const String kind = 'kind';
}

/// What the app needs from a push, read from the service's message.
PushMessage pushMessageOf({
  required String? title,
  required Map<String, Object?> data,
}) {
  final destination = data[PushDataKeys.destination];
  return PushMessage(
    title: title ?? '',
    destination: destination is String ? destination : '',
    kind: NotificationKind.parse(data[PushDataKeys.kind]),
  );
}

/// The permission as the app understands it.
///
/// Android reports "denied" both before its prompt was ever shown and after
/// the customer refused it, so the adapter remembers whether it asked:
/// [wasAsked] tells the two apart.
NotificationPermission permissionOf(
  AuthorizationStatus status, {
  required bool wasAsked,
}) => switch (status) {
  AuthorizationStatus.authorized ||
  AuthorizationStatus.provisional => NotificationPermission.granted,
  AuthorizationStatus.notDetermined => NotificationPermission.notAsked,
  AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently =>
    wasAsked ? NotificationPermission.denied : NotificationPermission.notAsked,
};

/// [PushMessaging] on Firebase Cloud Messaging.
final class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._messaging, this._preferences);

  static const String _askedKey = 'notifications.system_prompt_shown';

  final FirebaseMessaging _messaging;
  final SharedPreferences _preferences;
  bool _initialMessageRead = false;

  bool get _wasAsked => _preferences.getBool(_askedKey) ?? false;

  @override
  Future<NotificationPermission> permission() async {
    final settings = await _messaging.getNotificationSettings();
    return permissionOf(settings.authorizationStatus, wasAsked: _wasAsked);
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    final settings = await _messaging.requestPermission();
    await _preferences.setBool(_askedKey, true);
    return permissionOf(settings.authorizationStatus, wasAsked: true);
  }

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenChanges => _messaging.onTokenRefresh;

  @override
  Future<void> subscribe(String topic) => _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribe(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<PushMessage> get foreground => FirebaseMessaging.onMessage.map(_read);

  @override
  Stream<PushMessage> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map(_read);

  @override
  Future<PushMessage?> initialMessage() async {
    // The service keeps answering with the same notification for as long as
    // the process lives. It started the app once, so it is handed over once.
    if (_initialMessageRead) return null;
    _initialMessageRead = true;
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _read(message);
  }

  static PushMessage _read(RemoteMessage message) =>
      pushMessageOf(title: message.notification?.title, data: message.data);
}
