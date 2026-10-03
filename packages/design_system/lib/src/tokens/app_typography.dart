import 'package:flutter/painting.dart';

/// Type scale. Sizes and line heights mirror `tokens/tokens.json`.
///
/// Styles carry no color on purpose: color comes from the theme so the same
/// scale works on every allowed surface. Letter spacing is always explicit,
/// otherwise Material's default tracking would leak into the scale.
abstract final class AppTypography {
  static const String _package = 'design_system';
  static const String headingFamily = 'Poppins';
  static const String textFamily = 'Open Sans';

  static const TextStyle display = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: 0,
  );

  static const TextStyle title = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: 0,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 24 / 17,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: textFamily,
    package: _package,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 22 / 15,
    letterSpacing: 0,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: textFamily,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 22 / 15,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: textFamily,
    package: _package,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: 0,
  );

  static const TextStyle captionStrong = TextStyle(
    fontFamily: textFamily,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: 0,
  );

  /// Rendered in uppercase by the components that use it.
  static const TextStyle overline = TextStyle(
    fontFamily: textFamily,
    package: _package,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    height: 16 / 11,
    letterSpacing: 0.6,
  );

  /// Amounts align in columns, so digits must share one advance width.
  static const List<FontFeature> amountFeatures = [
    FontFeature.tabularFigures(),
  ];

  /// Cents are drawn at this fraction of the integer part's size.
  static const double amountCentsScale = 0.64;
}
