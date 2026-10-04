import 'package:feature_notifications/src/domain/inbox_item.dart';
import 'package:feature_notifications/src/domain/push_message.dart';

/// Where one customer's inbox is read from.
///
/// `watch` may answer from the device's own copy; `fetch` asks the backend
/// and throws when it cannot be reached.
abstract interface class InboxSource {
  Stream<InboxSnapshot> watch({required int limit});

  Future<InboxSnapshot> fetch({required int limit});

  Future<void> markRead(String id);
}

/// The messaging service of the device.
abstract interface class PushMessaging {
  Future<NotificationPermission> permission();

  /// Shows the system prompt when the system still allows it.
  Future<NotificationPermission> requestPermission();

  /// The address of this installation, or null when the service has none.
  Future<String?> token();

  /// A new address replacing the previous one.
  Stream<String> get tokenChanges;

  Future<void> subscribe(String topic);

  Future<void> unsubscribe(String topic);

  /// Forgets the address, so nothing sent to it reaches this device.
  Future<void> deleteToken();

  /// Messages that arrive while the app is open.
  Stream<PushMessage> get foreground;

  /// Notifications the customer tapped while the app was in the background.
  Stream<PushMessage> get opened;

  /// The notification that started the app, if one did.
  Future<PushMessage?> initialMessage();
}

/// Where the customer's devices are registered for the sender to find.
abstract interface class DeviceStore {
  Future<void> save({
    required String deviceId,
    required String token,
    required String platform,
  });

  Future<void> remove(String deviceId);
}

/// What identifies this installation among the customer's devices.
abstract interface class DeviceIdentity {
  Future<String> id();

  /// `android` or `ios`.
  String get platform;
}

/// What this installation remembers about its own registration: who it was
/// last registered for and which topics it may still be subscribed to.
///
/// It lives on the device, outside any session, so a phone that changes
/// hands can be cleaned before the next customer is registered on it. It
/// holds an identifier and topic names, never anything about the customer.
abstract interface class RegistrationMemory {
  String? get uid;

  Set<String> get topics;

  Future<void> save({required String? uid, required Set<String> topics});
}

/// Remembers, on this device, that the customer already answered the
/// invitation to turn notifications on.
abstract interface class PrimerMemory {
  bool get wasAnswered;

  Future<void> rememberAnswered();
}

/// Opens the system's settings for this app.
// Kept as an interface so tests can replace it with a named fake.
// ignore: one_member_abstracts
abstract interface class SystemSettings {
  Future<void> openNotificationSettings();
}
