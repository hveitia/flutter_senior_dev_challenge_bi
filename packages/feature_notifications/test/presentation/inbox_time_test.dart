import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/src/presentation/inbox_time.dart';
import 'package:feature_notifications/src/presentation/notifications_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  group('groupInbox', () {
    test('splits today from before, keeping the order', () {
      final groups = groupInbox([salary, signIn, travel, transfer], now: now);

      expect(groups.today, [salary, signIn]);
      expect(groups.earlier, [travel, transfer]);
    });

    test('the first minute of the day is today and the last of the previous '
        'one is not', () {
      final midnight = salary.createdAt.copyWith(hour: 0, minute: 0);
      final beforeMidnight = DateTime(2026, 10, 2, 23, 59);

      final groups = groupInbox(
        [
          _at(midnight, 'a'),
          _at(beforeMidnight, 'b'),
        ],
        now: now,
      );

      expect(groups.today.single.id, 'a');
      expect(groups.earlier.single.id, 'b');
    });
  });

  group('arrivalLabel', () {
    test('today shows the time alone', () {
      expect(arrivalLabel(DateTime(2026, 10, 3, 9, 12), now: now), '09:12');
    });

    test('yesterday says so', () {
      expect(
        arrivalLabel(DateTime(2026, 10, 2, 15, 20), now: now),
        'Ayer · 15:20',
      );
    });

    test('before that shows the day and the short month', () {
      expect(
        arrivalLabel(DateTime(2026, 9, 28, 16, 4), now: now),
        '28 sep · 16:04',
      );
    });

    test('yesterday crosses the month', () {
      expect(
        arrivalLabel(
          DateTime(2026, 9, 30, 8, 5),
          now: DateTime(2026, 10, 1, 7),
        ),
        'Ayer · 08:05',
      );
    });
  });

  group('destinationLabel', () {
    test('names the destinations the app has words for', () {
      expect(NotificationsStrings.destinationLabel('accounts'), 'Tus cuentas');
      expect(
        NotificationsStrings.destinationLabel('partner:travelInsurance'),
        'Servicios de aliados',
      );
    });

    test('has nothing to say about a name it does not know', () {
      expect(NotificationsStrings.destinationLabel('loans'), isNull);
    });
  });

  test('the bell counts for a screen reader', () {
    expect(
      NotificationsStrings.bellWithUnread(1),
      'Notificaciones, 1 sin leer',
    );
    expect(
      NotificationsStrings.bellWithUnread(3),
      'Notificaciones, 3 sin leer',
    );
  });
}

InboxItem _at(DateTime at, String id) => InboxItem(
  id: id,
  title: 'Aviso',
  body: '',
  kind: NotificationKind.benefit,
  destination: '',
  createdAt: at,
  isRead: true,
);
