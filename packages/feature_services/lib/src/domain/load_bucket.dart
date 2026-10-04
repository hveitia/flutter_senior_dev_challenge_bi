/// How long a mini app took to load, as the coarse range that is reported.
///
/// A range is enough to see partners getting slow, and says nothing about a
/// single customer's connection.
abstract final class LoadBucket {
  static const String underOneSecond = 'under_1s';
  static const String oneToThreeSeconds = '1_to_3s';
  static const String threeToEightSeconds = '3_to_8s';
  static const String overEightSeconds = 'over_8s';

  /// The range [elapsed] falls in. A bound belongs to the range it opens.
  static String of(Duration elapsed) {
    if (elapsed < _short) return underOneSecond;
    if (elapsed < _medium) return oneToThreeSeconds;
    if (elapsed < _long) return threeToEightSeconds;
    return overEightSeconds;
  }

  static const Duration _short = Duration(seconds: 1);
  static const Duration _medium = Duration(seconds: 3);
  static const Duration _long = Duration(seconds: 8);
}
