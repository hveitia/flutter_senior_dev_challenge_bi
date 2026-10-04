/// How dates and times are written for the customer. Pure functions of the
/// moment they describe and of the current moment, so tests need no clock.
abstract final class TimeLabels {
  static const String today = 'Hoy';
  static const String yesterday = 'Ayer';

  /// Shown when the device has saved data but does not know from when.
  static const String savedData = 'Datos guardados';

  static const String _updatedMomentsAgo = 'Actualizado hace un momento';
  static const String _separator = ' · ';

  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// `Hoy`, `Ayer`, `28 sep`, or `28 sep 2025` for another year.
  static String day(DateTime date, {required DateTime now}) {
    final thisDay = _midnight(now);
    final thatDay = _midnight(date);
    if (thatDay == thisDay) return today;
    // Built from the calendar fields, so it is right across a change of
    // month and when a day is not 24 hours long.
    if (thatDay == DateTime(now.year, now.month, now.day - 1)) return yesterday;

    return date.year == now.year ? _dayAndMonth(date) : _date(date);
  }

  /// `09:12`, on a 24-hour clock.
  static String time(DateTime moment) =>
      '${_twoDigits(moment.hour)}:${_twoDigits(moment.minute)}';

  /// `Hoy · 09:12`, as written under a movement.
  static String moment(DateTime moment, {required DateTime now}) =>
      '${day(moment, now: now)}$_separator${time(moment)}';

  /// `09:12 · Cuenta de ahorros ****4821`, as written under a movement in a
  /// list that mixes accounts. Without a [label] it is the time alone.
  static String timeWith(DateTime moment, String? label) =>
      label == null ? time(moment) : '${time(moment)}$_separator$label';

  /// `3 oct 2026 · 08:45`, as written in the details of a movement.
  static String fullMoment(DateTime moment) =>
      '${_date(moment)}$_separator${time(moment)}';

  /// `Actualizado hace 8 min`: how old the data on screen is.
  ///
  /// A [syncedAt] later than [now] happens when the device clock is moved
  /// back; it is reported as a moment ago rather than as a negative age.
  static String freshness(DateTime? syncedAt, {required DateTime now}) {
    if (syncedAt == null) return savedData;

    final age = now.difference(syncedAt);
    if (age < const Duration(minutes: 1)) return _updatedMomentsAgo;
    if (age < const Duration(hours: 1)) {
      return 'Actualizado hace ${age.inMinutes} min';
    }
    if (age < const Duration(days: 1)) {
      return 'Actualizado hace ${age.inHours} h';
    }
    return 'Actualizado el ${_dayAndMonth(syncedAt)}';
  }

  static DateTime _midnight(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  static String _dayAndMonth(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  static String _date(DateTime date) => '${_dayAndMonth(date)} ${date.year}';

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
