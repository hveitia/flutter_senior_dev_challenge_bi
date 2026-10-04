import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

/// A movement of [cents] posted [daysAgo] days before the fixtures' "now"
/// (Saturday 3 October 2026, 10:00), at [hour] o'clock.
Movement _moved(int cents, {required int daysAgo, int hour = 9}) => movement(
  id: 'm$daysAgo-$hour-$cents',
  description: 'Movimiento',
  amountCents: cents,
  postedAt: DateTime(2026, 10, 3 - daysAgo, hour),
);

void main() {
  group('balanceTrend', () {
    // Worked by hand. Today the customer has $1,000.00.
    //   today      +200.00 and -50.00  -> yesterday closed at  850.00
    //   yesterday  nothing             -> 2 days ago closed at 850.00
    //   2 days ago -100.00             -> 3 days ago closed at 950.00
    //   3 days ago +400.00             -> 4 days ago closed at 550.00
    final movements = [
      _moved(20000, daysAgo: 0),
      _moved(-5000, daysAgo: 0, hour: 8),
      _moved(-10000, daysAgo: 2),
      _moved(40000, daysAgo: 3),
    ];

    test('walks the balance back through the movements, one closing balance '
        'per day, oldest first', () {
      final trend = balanceTrend(
        currentCents: 100000,
        movements: movements,
        now: now,
        days: 5,
        isComplete: true,
      );

      expect(trend!.closingCents, [55000, 95000, 85000, 85000, 100000]);
      expect(trend.days, 5);
    });

    test('ends at what the customer has now, whatever the period', () {
      for (final days in [2, 3, 30]) {
        final trend = balanceTrend(
          currentCents: 100000,
          movements: movements,
          now: now,
          days: days,
          isComplete: true,
        );

        expect(trend!.closingCents.last, 100000);
        expect(trend.closingCents, hasLength(days));
      }
    });

    test(
      'is flat for a period without movements: the balance did not move',
      () {
        final trend = balanceTrend(
          currentCents: 100000,
          movements: const [],
          now: now,
          days: 4,
          isComplete: true,
        );

        expect(trend!.closingCents, [100000, 100000, 100000, 100000]);
      },
    );

    test('ignores movements older than the period', () {
      final trend = balanceTrend(
        currentCents: 100000,
        movements: [...movements, _moved(999999, daysAgo: 9)],
        now: now,
        days: 5,
        isComplete: true,
      );

      expect(trend!.closingCents.first, 55000);
    });

    test('counts a movement posted just after midnight on its own day', () {
      final trend = balanceTrend(
        currentCents: 100000,
        movements: [
          movement(
            id: 'early',
            description: 'Madrugada',
            amountCents: -3000,
            postedAt: DateTime(2026, 10, 3, 0, 5),
          ),
          movement(
            id: 'late',
            description: 'Noche',
            amountCents: -7000,
            postedAt: DateTime(2026, 10, 2, 23, 55),
          ),
        ],
        now: now,
        days: 3,
        isComplete: true,
      );

      expect(trend!.closingCents, [110000, 103000, 100000]);
    });

    group('when the movements read do not reach back the whole period', () {
      test('covers only the days it has every movement of', () {
        // The read stopped somewhere inside the day 3 days ago, so that
        // day may be missing movements and is not drawn.
        final trend = balanceTrend(
          currentCents: 100000,
          movements: movements,
          now: now,
          days: 30,
          isComplete: false,
        );

        expect(trend!.closingCents, [85000, 85000, 100000]);
        expect(trend.days, 3);
      });

      test('is not enough to draw anything when a single day is covered', () {
        final trend = balanceTrend(
          currentCents: 100000,
          movements: [_moved(20000, daysAgo: 0), _moved(-100, daysAgo: 1)],
          now: now,
          days: 30,
          isComplete: false,
        );

        expect(trend, isNull);
      });
    });

    test(
      'is not enough to draw anything for a period shorter than two days',
      () {
        expect(
          balanceTrend(
            currentCents: 100000,
            movements: movements,
            now: now,
            days: 1,
            isComplete: true,
          ),
          isNull,
        );
      },
    );
  });
}
