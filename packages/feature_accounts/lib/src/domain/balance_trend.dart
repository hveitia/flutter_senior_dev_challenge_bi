import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/domain/movement.dart';

/// How a balance moved over the last days: what it closed at on each of
/// them, in cents, oldest first. The last value is the balance now.
final class BalanceTrend extends Equatable {
  const BalanceTrend(this.closingCents);

  final List<int> closingCents;

  /// How many days the trend covers.
  int get days => closingCents.length;

  @override
  List<Object?> get props => [closingCents];
}

/// The fewest days worth drawing: a line needs two points.
const int minTrendDays = 2;

/// The trend of a balance over the last [days] days, today included.
///
/// Nothing is stored about past balances, so they are worked out: starting
/// from [currentCents], which is what the day is closing at, each day's
/// [movements] are taken back to get what the day before closed at. The
/// figures are therefore exactly as true as the balance and the movements.
///
/// [isComplete] says whether [movements] holds every movement of the
/// period. When it does not, the read stopped somewhere inside its oldest
/// day, which may be missing movements, so the trend only covers the days
/// after that one.
///
/// Returns null when fewer than [minTrendDays] days can be worked out.
BalanceTrend? balanceTrend({
  required int currentCents,
  required Iterable<Movement> movements,
  required DateTime now,
  required int days,
  required bool isComplete,
}) {
  final today = DateTime(now.year, now.month, now.day);

  /// Whole days between the day of [moment] and today.
  int daysAgo(DateTime moment) {
    final day = DateTime(moment.year, moment.month, moment.day);
    // Rounded: a day with a clock change is not exactly 24 hours long.
    return (today.difference(day).inHours / Duration.hoursPerDay).round();
  }

  final movedByDay = <int, int>{};
  int? oldestRead;
  for (final movement in movements) {
    final age = daysAgo(movement.postedAt);
    if (age < 0) continue;
    if (oldestRead == null || age > oldestRead) oldestRead = age;
    movedByDay[age] = (movedByDay[age] ?? 0) + movement.amountCents;
  }

  final covered = isComplete || oldestRead == null
      ? days
      : (oldestRead < days ? oldestRead : days);
  if (covered < minTrendDays) return null;

  final closing = List<int>.filled(covered, 0);
  var balance = currentCents;
  for (var age = 0; age < covered; age++) {
    closing[covered - 1 - age] = balance;
    balance -= movedByDay[age] ?? 0;
  }
  return BalanceTrend(List.unmodifiable(closing));
}
