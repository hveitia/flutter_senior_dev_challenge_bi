import 'package:design_system/src/tokens/app_colors.dart';
import 'package:flutter/painting.dart';

/// The only colors text may use.
///
/// The brand orange is absent on purpose: it does not reach AA on any light
/// surface, so it is a fill and an accent, never a text color. The contrast
/// tests verify every pairing listed here.
abstract final class AppTextColors {
  static const Color primary = AppColors.ink900;
  static const Color secondary = AppColors.textSecondary;

  /// Links and text buttons.
  static const Color link = AppColors.brand700;

  /// Text and icons placed on the brand fill.
  static const Color onBrand = AppColors.ink900;

  /// Exempt from contrast requirements (WCAG 1.4.3, inactive components).
  static const Color disabled = AppColors.ink300;

  static const List<Color> values = [
    primary,
    secondary,
    link,
    onBrand,
    disabled,
    AppColors.success500,
    AppColors.danger500,
    AppColors.warning500,
    AppColors.info500,
  ];
}
