import 'package:feature_accounts/src/presentation/formatting/time_labels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  group('day', () {
    test('names today and yesterday', () {
      expect(TimeLabels.day(DateTime(2026, 10, 3, 0, 1), now: now), 'Hoy');
      expect(TimeLabels.day(DateTime(2026, 10, 2, 23, 59), now: now), 'Ayer');
    });

    test('yesterday crosses the end of a month', () {
      expect(
        TimeLabels.day(DateTime(2026, 9, 30, 12), now: DateTime(2026, 10)),
        'Ayer',
      );
    });

    test('writes other days of this year as day and short month', () {
      expect(TimeLabels.day(DateTime(2026, 9, 28), now: now), '28 sep');
      expect(TimeLabels.day(DateTime(2026, 1, 5), now: now), '5 ene');
    });

    test('adds the year when it is not the current one', () {
      expect(TimeLabels.day(DateTime(2025, 12, 31), now: now), '31 dic 2025');
    });

    test('a date in the future is written out, not called today', () {
      expect(TimeLabels.day(DateTime(2026, 10, 4), now: now), '4 oct');
    });
  });

  test('time uses a 24-hour clock with two digits', () {
    expect(TimeLabels.time(DateTime(2026, 10, 3, 9, 12)), '09:12');
    expect(TimeLabels.time(DateTime(2026, 10, 3, 16, 4)), '16:04');
    expect(TimeLabels.time(DateTime(2026, 10, 3)), '00:00');
  });

  test('moment joins the day and the time', () {
    expect(
      TimeLabels.moment(DateTime(2026, 10, 3, 8, 45), now: now),
      'Hoy · 08:45',
    );
    expect(
      TimeLabels.moment(DateTime(2026, 9, 28, 16, 4), now: now),
      '28 sep · 16:04',
    );
  });

  test('fullMoment always carries the date and the year', () {
    expect(
      TimeLabels.fullMoment(DateTime(2026, 10, 3, 8, 45)),
      '3 oct 2026 · 08:45',
    );
  });

  group('freshness', () {
    String freshness(Duration ago) =>
        TimeLabels.freshness(now.subtract(ago), now: now);

    test('says so when the device does not know how old the data is', () {
      expect(TimeLabels.freshness(null, now: now), 'Datos guardados');
    });

    test('under a minute is a moment ago', () {
      expect(freshness(Duration.zero), 'Actualizado hace un momento');
      expect(
        freshness(const Duration(seconds: 59)),
        'Actualizado hace un momento',
      );
    });

    test('counts minutes up to an hour', () {
      expect(freshness(const Duration(minutes: 1)), 'Actualizado hace 1 min');
      expect(freshness(const Duration(minutes: 8)), 'Actualizado hace 8 min');
      expect(freshness(const Duration(minutes: 59)), 'Actualizado hace 59 min');
    });

    test('counts hours up to a day', () {
      expect(freshness(const Duration(minutes: 60)), 'Actualizado hace 1 h');
      expect(freshness(const Duration(hours: 23)), 'Actualizado hace 23 h');
    });

    test('gives the date once it is a day old or more', () {
      expect(freshness(const Duration(hours: 24)), 'Actualizado el 2 oct');
      expect(freshness(const Duration(days: 40)), 'Actualizado el 24 ago');
    });

    test('a clock set back does not produce a negative age', () {
      expect(
        TimeLabels.freshness(now.add(const Duration(minutes: 5)), now: now),
        'Actualizado hace un momento',
      );
    });
  });
}
