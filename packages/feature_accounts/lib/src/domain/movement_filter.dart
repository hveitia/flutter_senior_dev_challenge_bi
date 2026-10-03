import 'package:feature_accounts/src/domain/movement.dart';

/// Which movements of a list the customer wants to see.
enum MovementFilter { all, income, expenses, thisMonth }

/// The movements of [movements] that pass [filter] and whose description
/// contains [query], in their original order.
///
/// The search ignores case, accents and surrounding spaces, so "nomina"
/// finds "Nómina". [now] decides what "this month" means.
List<Movement> filterMovements(
  List<Movement> movements, {
  required MovementFilter filter,
  required String query,
  required DateTime now,
}) {
  final wanted = _searchable(query);

  bool passesFilter(Movement movement) => switch (filter) {
    MovementFilter.all => true,
    MovementFilter.income => movement.amountCents > 0,
    MovementFilter.expenses => movement.amountCents < 0,
    MovementFilter.thisMonth =>
      movement.postedAt.year == now.year &&
          movement.postedAt.month == now.month,
  };

  return [
    for (final movement in movements)
      if (passesFilter(movement) &&
          _searchable(movement.description).contains(wanted))
        movement,
  ];
}

/// Lower case, trimmed and without the accents Spanish uses. The letter ñ is
/// kept: it is a different letter, not an accented n.
String _searchable(String text) {
  final lower = text.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_unaccented[character] ?? character);
  }
  return buffer.toString();
}

const Map<String, String> _unaccented = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
};

/// The movements of one calendar day.
final class MovementDay {
  const MovementDay({required this.day, required this.movements});

  /// Midnight of the day, in the device's time zone.
  final DateTime day;
  final List<Movement> movements;
}

/// [movements] split by the calendar day they were posted, keeping their
/// order: a list sorted newest first gives days sorted newest first.
List<MovementDay> groupByDay(List<Movement> movements) {
  final days = <MovementDay>[];
  for (final movement in movements) {
    final posted = movement.postedAt;
    final day = DateTime(posted.year, posted.month, posted.day);
    if (days.isNotEmpty && days.last.day == day) {
      days.last.movements.add(movement);
    } else {
      days.add(MovementDay(day: day, movements: [movement]));
    }
  }
  return days;
}
