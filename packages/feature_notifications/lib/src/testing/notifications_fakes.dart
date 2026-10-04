import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/inbox_item.dart';
import 'package:feature_notifications/src/domain/notifications_repository.dart';
import 'package:feature_notifications/src/domain/push_message.dart';

/// An [InboxSource] a test drives by hand.
final class FakeInboxSource implements InboxSource {
  final StreamController<InboxSnapshot> deliveries =
      StreamController<InboxSnapshot>.broadcast();

  /// What `fetch` answers. Throwing makes the fetch fail.
  Future<InboxSnapshot> Function() onFetch = () async =>
      const InboxSnapshot(items: [], fromCache: false);

  /// Throwing makes marking as read fail.
  Future<void> Function(String id) onMarkRead = (_) async {};

  final List<String> markedRead = [];
  int watches = 0;

  @override
  Stream<InboxSnapshot> watch({required int limit}) {
    watches++;
    return deliveries.stream;
  }

  @override
  Future<InboxSnapshot> fetch({required int limit}) => onFetch();

  @override
  Future<void> markRead(String id) async {
    await onMarkRead(id);
    markedRead.add(id);
  }
}

/// A [NotificationsRepository] a test drives by hand.
final class FakeNotificationsRepository implements NotificationsRepository {
  StreamController<InboxSnapshot> inbox =
      StreamController<InboxSnapshot>.broadcast();

  Future<Result<InboxSnapshot>> Function() onRefresh = () async =>
      const Success(InboxSnapshot(items: [], fromCache: false));

  Future<Result<void>> Function(String id) onMarkRead = (_) async =>
      const Success(null);

  final List<String> markedRead = [];
  int watches = 0;
  int refreshes = 0;

  @override
  Stream<InboxSnapshot> watchInbox() {
    watches++;
    return inbox.stream;
  }

  @override
  Future<Result<InboxSnapshot>> refreshInbox() {
    refreshes++;
    return onRefresh();
  }

  @override
  Future<Result<void>> markRead(String id) {
    markedRead.add(id);
    return onMarkRead(id);
  }
}

/// A [PushMessaging] that records every call, in order, in [calls].
final class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.current = NotificationPermission.notAsked,
    this.afterPrompt = NotificationPermission.granted,
    this.currentToken = 'token-1',
    List<String>? calls,
  }) : calls = calls ?? [];

  NotificationPermission current;

  /// What the customer answers to the system prompt.
  NotificationPermission afterPrompt;
  String? currentToken;

  /// Shared with other fakes when a test checks the order across them.
  final List<String> calls;

  /// Names of the calls that throw.
  final Set<String> failing = {};

  /// Completes the calls named here only when the test says so.
  final Map<String, Completer<void>> held = {};

  PushMessage? initial;

  final StreamController<String> tokens = StreamController<String>.broadcast();
  final StreamController<PushMessage> foregroundMessages =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> openedMessages =
      StreamController<PushMessage>.broadcast();

  int prompts = 0;

  Future<void> _call(String name) async {
    calls.add(name);
    if (held[name] case final gate?) await gate.future;
    if (failing.contains(name)) throw StateError(name);
  }

  @override
  Future<NotificationPermission> permission() async => current;

  @override
  Future<NotificationPermission> requestPermission() async {
    prompts++;
    return current = afterPrompt;
  }

  @override
  Future<String?> token() async {
    await _call('token');
    return currentToken;
  }

  @override
  Stream<String> get tokenChanges => tokens.stream;

  @override
  Future<void> subscribe(String topic) => _call('subscribe:$topic');

  @override
  Future<void> unsubscribe(String topic) => _call('unsubscribe:$topic');

  @override
  Future<void> deleteToken() => _call('deleteToken');

  @override
  Stream<PushMessage> get foreground => foregroundMessages.stream;

  @override
  Stream<PushMessage> get opened => openedMessages.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;
}

/// A [DeviceStore] kept in memory.
final class FakeDeviceStore implements DeviceStore {
  FakeDeviceStore({List<String>? calls}) : calls = calls ?? [];

  /// Device id to token.
  final Map<String, String> saved = {};
  final List<String> calls;
  bool failing = false;

  @override
  Future<void> save({
    required String deviceId,
    required String token,
    required String platform,
  }) async {
    calls.add('save:$deviceId:$token:$platform');
    if (failing) throw StateError('save');
    saved[deviceId] = token;
  }

  @override
  Future<void> remove(String deviceId) async {
    calls.add('remove:$deviceId');
    if (failing) throw StateError('remove');
    saved.remove(deviceId);
  }
}

final class FakeDeviceIdentity implements DeviceIdentity {
  const FakeDeviceIdentity({this.deviceId = 'device-1'});

  final String deviceId;

  @override
  Future<String> id() async => deviceId;

  @override
  String get platform => 'android';
}

final class FakePrimerMemory implements PrimerMemory {
  FakePrimerMemory({this.wasAnswered = false});

  @override
  bool wasAnswered;

  @override
  Future<void> rememberAnswered() async => wasAnswered = true;
}

final class FakeSystemSettings implements SystemSettings {
  int opened = 0;
  bool failing = false;

  @override
  Future<void> openNotificationSettings() async {
    if (failing) throw StateError('settings');
    opened++;
  }
}
