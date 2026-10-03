/// Spacing on a 4pt grid. Named tokens mirror `tokens/tokens.json`; the
/// numbered steps are multiples of [grid] for use inside components.
abstract final class AppSpacing {
  static const double grid = 4;
  static const double screenMargin = 20;
  static const double moduleGap = 24;
  static const double componentGap = 16;

  static const double x1 = grid;
  static const double x2 = grid * 2;
  static const double x3 = grid * 3;
  static const double x4 = grid * 4;
  static const double x6 = grid * 6;
  static const double x8 = grid * 8;
}
