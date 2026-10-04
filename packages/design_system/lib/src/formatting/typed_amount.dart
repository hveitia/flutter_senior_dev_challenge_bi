import 'dart:math';

/// An amount as the customer types it: whole dollars, then optionally a
/// decimal point and up to two decimals. `1` is one dollar and `1.5` is one
/// fifty.
///
/// The text is what was typed, kept as text so that `1.` and `1.50` stay on
/// screen as written. Its value is read digit by digit into whole cents,
/// never through a fraction: `0.29` as a double is not 29 cents.
abstract final class TypedAmount {
  static const String decimalPoint = '.';

  /// The largest amount the entry holds. It is far above any limit a
  /// product sets: it only keeps a long run of digits from overflowing a
  /// number.
  static const int maxCents = 999999999;

  /// Digits of the whole part. With two decimals, the longest entry is
  /// exactly [maxCents].
  static const int maxWholeDigits = 7;
  static const int maxDecimals = 2;

  /// [typed] after pressing [digit]. Unchanged when there is no room for
  /// it: a third decimal, or a whole part already at its longest.
  static String withDigit(String typed, int digit) {
    if (digit < 0 || digit > 9) return typed;
    final point = typed.indexOf(decimalPoint);
    if (point >= 0) {
      final decimals = typed.length - point - 1;
      return decimals >= maxDecimals ? typed : '$typed$digit';
    }
    // A leading zero is replaced, not kept: 0 then 7 is 7.
    if (typed == '0') return '$digit';
    if (typed.length >= maxWholeDigits) return typed;
    return '$typed$digit';
  }

  /// [typed] after pressing the decimal point. A point pressed first
  /// starts at zero, and a second one is ignored.
  static String withDecimalPoint(String typed) {
    if (typed.contains(decimalPoint)) return typed;
    return typed.isEmpty ? '0$decimalPoint' : '$typed$decimalPoint';
  }

  /// [typed] without its last character.
  static String withoutLast(String typed) =>
      typed.isEmpty ? typed : typed.substring(0, typed.length - 1);

  /// The amount [typed] stands for, in cents. Anything that is not a digit
  /// or the first decimal point is ignored, and so are decimals beyond the
  /// second. A whole part too long to be real is held at [maxCents]:
  /// cutting it to its first digits would show a different, plausible
  /// amount.
  static int cents(String typed) {
    final clean = typed.replaceAll(RegExp('[^0-9.]'), '');
    final point = clean.indexOf(decimalPoint);
    final whole = (point < 0 ? clean : clean.substring(0, point)).replaceFirst(
      RegExp('^0+'),
      '',
    );
    final decimals = point < 0
        ? ''
        : clean.substring(point + 1).replaceAll(decimalPoint, '');
    if (whole.length > maxWholeDigits) return maxCents;

    final fraction = decimals
        .padRight(maxDecimals, '0')
        .substring(0, maxDecimals);
    final dollars = whole.isEmpty ? 0 : int.parse(whole);
    return min(dollars * 100 + int.parse(fraction), maxCents);
  }

  /// [cents] written as it would have been typed, so an amount already
  /// chosen can be edited again: `150` is `1.50` and `100` is `1`.
  static String fromCents(int cents) {
    if (cents <= 0) return '';
    final dollars = cents ~/ 100;
    final fraction = cents % 100;
    if (fraction == 0) return '$dollars';
    return '$dollars$decimalPoint${'$fraction'.padLeft(maxDecimals, '0')}';
  }
}
