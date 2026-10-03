import 'package:design_system/src/tokens/app_colors.dart';
import 'package:design_system/src/tokens/app_text_colors.dart';
import 'package:design_system/src/tokens/app_tone.dart';
import 'package:flutter/material.dart';

/// Colors Material's `ColorScheme` has no slot for.
///
/// Components read colors from here instead of from the raw palette, so a
/// future theme only has to provide another instance of this class.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.brandFill,
    required this.brandFillPressed,
    required this.onBrandFill,
    required this.brandTint,
    required this.link,
    required this.textSecondary,
    required this.textDisabled,
    required this.icon,
    required this.line,
    required this.surfaceInset,
    required this.focusRing,
    required this.success,
    required this.successTint,
    required this.danger,
    required this.dangerTint,
    required this.warning,
    required this.warningTint,
    required this.info,
    required this.infoTint,
  });

  static const AppSemanticColors light = AppSemanticColors(
    brandFill: AppColors.brand500,
    brandFillPressed: AppColors.brand600,
    onBrandFill: AppTextColors.onBrand,
    brandTint: AppColors.brand50,
    link: AppTextColors.link,
    textSecondary: AppTextColors.secondary,
    textDisabled: AppTextColors.disabled,
    icon: AppColors.ink600,
    line: AppColors.line,
    surfaceInset: AppColors.surface2,
    focusRing: AppColors.focusRing,
    success: AppColors.success500,
    successTint: AppColors.successTint,
    danger: AppColors.danger500,
    dangerTint: AppColors.dangerTint,
    warning: AppColors.warning500,
    warningTint: AppColors.warningTint,
    info: AppColors.info500,
    infoTint: AppColors.infoTint,
  );

  /// Fill of primary actions. Never a text color.
  final Color brandFill;
  final Color brandFillPressed;
  final Color onBrandFill;
  final Color brandTint;
  final Color link;
  final Color textSecondary;
  final Color textDisabled;
  final Color icon;
  final Color line;
  final Color surfaceInset;
  final Color focusRing;
  final Color success;
  final Color successTint;
  final Color danger;
  final Color dangerTint;
  final Color warning;
  final Color warningTint;
  final Color info;
  final Color infoTint;

  /// Text-safe color of [tone].
  Color foreground(AppTone tone) => switch (tone) {
    AppTone.success => success,
    AppTone.danger => danger,
    AppTone.warning => warning,
    AppTone.info => info,
  };

  /// Background tint that [foreground] of the same [tone] is designed for.
  Color tint(AppTone tone) => switch (tone) {
    AppTone.success => successTint,
    AppTone.danger => dangerTint,
    AppTone.warning => warningTint,
    AppTone.info => infoTint,
  };

  @override
  AppSemanticColors copyWith({
    Color? brandFill,
    Color? brandFillPressed,
    Color? onBrandFill,
    Color? brandTint,
    Color? link,
    Color? textSecondary,
    Color? textDisabled,
    Color? icon,
    Color? line,
    Color? surfaceInset,
    Color? focusRing,
    Color? success,
    Color? successTint,
    Color? danger,
    Color? dangerTint,
    Color? warning,
    Color? warningTint,
    Color? info,
    Color? infoTint,
  }) {
    return AppSemanticColors(
      brandFill: brandFill ?? this.brandFill,
      brandFillPressed: brandFillPressed ?? this.brandFillPressed,
      onBrandFill: onBrandFill ?? this.onBrandFill,
      brandTint: brandTint ?? this.brandTint,
      link: link ?? this.link,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      icon: icon ?? this.icon,
      line: line ?? this.line,
      surfaceInset: surfaceInset ?? this.surfaceInset,
      focusRing: focusRing ?? this.focusRing,
      success: success ?? this.success,
      successTint: successTint ?? this.successTint,
      danger: danger ?? this.danger,
      dangerTint: dangerTint ?? this.dangerTint,
      warning: warning ?? this.warning,
      warningTint: warningTint ?? this.warningTint,
      info: info ?? this.info,
      infoTint: infoTint ?? this.infoTint,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      brandFill: mix(brandFill, other.brandFill),
      brandFillPressed: mix(brandFillPressed, other.brandFillPressed),
      onBrandFill: mix(onBrandFill, other.onBrandFill),
      brandTint: mix(brandTint, other.brandTint),
      link: mix(link, other.link),
      textSecondary: mix(textSecondary, other.textSecondary),
      textDisabled: mix(textDisabled, other.textDisabled),
      icon: mix(icon, other.icon),
      line: mix(line, other.line),
      surfaceInset: mix(surfaceInset, other.surfaceInset),
      focusRing: mix(focusRing, other.focusRing),
      success: mix(success, other.success),
      successTint: mix(successTint, other.successTint),
      danger: mix(danger, other.danger),
      dangerTint: mix(dangerTint, other.dangerTint),
      warning: mix(warning, other.warning),
      warningTint: mix(warningTint, other.warningTint),
      info: mix(info, other.info),
      infoTint: mix(infoTint, other.infoTint),
    );
  }

  List<Color> get _values => [
    brandFill,
    brandFillPressed,
    onBrandFill,
    brandTint,
    link,
    textSecondary,
    textDisabled,
    icon,
    line,
    surfaceInset,
    focusRing,
    success,
    successTint,
    danger,
    dangerTint,
    warning,
    warningTint,
    info,
    infoTint,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSemanticColors && _listEquals(other._values, _values);

  @override
  int get hashCode => Object.hashAll(_values);
}

bool _listEquals(List<Color> a, List<Color> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
