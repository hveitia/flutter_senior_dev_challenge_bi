import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  List<String> ids(
    MovementFilter filter, {
    String query = '',
    List<Movement>? from,
  }) {
    return filterMovements(
      from ?? movements,
      filter: filter,
      query: query,
      now: now,
    ).map((movement) => movement.id).toList();
  }

  group('filterMovements', () {
    test('keeps everything, in order, when nothing is filtered', () {
      expect(ids(MovementFilter.all), [
        'salary',
        'groceries',
        'coffee',
        'received',
      ]);
    });

    test('income keeps only money that came in', () {
      expect(ids(MovementFilter.income), ['salary', 'received']);
    });

    test('expenses keeps only money that went out', () {
      expect(ids(MovementFilter.expenses), ['groceries', 'coffee']);
    });

    test('a movement of zero is neither income nor an expense', () {
      final zero = movement(
        id: 'zero',
        description: 'Ajuste',
        amountCents: 0,
        postedAt: now,
      );

      expect(ids(MovementFilter.income, from: [zero]), isEmpty);
      expect(ids(MovementFilter.expenses, from: [zero]), isEmpty);
      expect(ids(MovementFilter.all, from: [zero]), ['zero']);
    });

    test('this month leaves out earlier months', () {
      expect(ids(MovementFilter.thisMonth), ['salary', 'groceries', 'coffee']);
    });

    test('this month does not confuse the same month of another year', () {
      final lastYear = movement(
        id: 'last-year',
        description: 'Compra',
        amountCents: -100,
        postedAt: DateTime(2025, 10, 3),
      );

      expect(ids(MovementFilter.thisMonth, from: [lastYear]), isEmpty);
    });

    test('the search matches part of the description', () {
      expect(ids(MovementFilter.all, query: 'super'), ['groceries']);
    });

    test('the search ignores case, accents and surrounding spaces', () {
      expect(ids(MovementFilter.all, query: '  NOMINA '), ['salary']);
      expect(ids(MovementFilter.all, query: 'cafe'), ['coffee']);
      expect(ids(MovementFilter.all, query: 'mañana'), ['coffee']);
    });

    test('the search and the filter apply together', () {
      expect(ids(MovementFilter.income, query: 'transferencia'), ['received']);
      expect(ids(MovementFilter.expenses, query: 'transferencia'), isEmpty);
    });
  });

  group('groupByDay', () {
    test('puts the movements of one day together, newest day first', () {
      final days = groupByDay(movements);

      expect(days.map((day) => day.day), [
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 2),
        DateTime(2026, 9, 28),
      ]);
      expect(days.first.movements.map((movement) => movement.id), [
        'salary',
        'groceries',
      ]);
    });

    test('has no days when there are no movements', () {
      expect(groupByDay(const []), isEmpty);
    });

    test('splits at midnight, not after 24 hours', () {
      final late = movement(
        id: 'late',
        description: 'Cena',
        amountCents: -2000,
        postedAt: DateTime(2026, 10, 2, 23, 59),
      );
      final early = movement(
        id: 'early',
        description: 'Taxi',
        amountCents: -500,
        postedAt: DateTime(2026, 10, 3, 0, 1),
      );

      expect(groupByDay([early, late]), hasLength(2));
    });
  });
}
