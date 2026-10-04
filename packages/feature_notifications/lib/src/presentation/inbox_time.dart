import 'package:feature_notifications/src/domain/inbox_item.dart';
import 'package:feature_notifications/src/presentation/notifications_strings.dart';

/// The inbox split as the screen shows it: what arrived today and the rest.
/// Both keep the order they came in, newest first.
typedef InboxGroups = ({List<InboxItem> today, List<InboxItem> earlier});

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Splits [items] by the calendar day of [now], in the device's own time.
InboxGroups groupInbox(List<InboxItem> items, {required DateTime now}) {
  final today = <InboxItem>[];
  final earlier = <InboxItem>[];
  for (final item in items) {
    (_isSameDay(item.createdAt, now) ? today : earlier).add(item);
  }
  return (today: today, earlier: earlier);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// When a notification arrived, as the inbox writes it: `09:12` today,
/// `Ayer · 15:20` yesterday and `28 sep · 16:04` before that.
String arrivalLabel(DateTime at, {required DateTime now}) {
  final time = '${_twoDigits(at.hour)}:${_twoDigits(at.minute)}';
  if (_isSameDay(at, now)) return time;

  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final day = _isSameDay(at, yesterday)
      ? NotificationsStrings.yesterday
      : NotificationsStrings.shortDate(at);
  return '$day · $time';
}
