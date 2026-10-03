import 'package:design_system/src/theme/app_metrics.dart';
import 'package:design_system/src/theme/app_semantic_colors.dart';
import 'package:design_system/src/tokens/app_colors.dart';
import 'package:design_system/src/tokens/app_motion.dart';
import 'package:design_system/src/tokens/app_radii.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_text_colors.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Material theme built from the design tokens.
abstract final class AppTheme {
  static ThemeData get light {
    const colors = AppSemanticColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.surface1,
      textTheme: _textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: const [colors, AppMetrics.standard],
      filledButtonTheme: FilledButtonThemeData(style: _primaryButton(colors)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _secondaryButton(colors),
      ),
      textButtonTheme: TextButtonThemeData(style: _textButton(colors)),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface0,
        foregroundColor: AppTextColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.subtitle.copyWith(
          color: AppTextColors.primary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: AppSizes.border,
        space: AppSizes.border,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand500,
        linearTrackColor: AppColors.surface2,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
    );
  }

  /// `primary` is the text-safe orange, not the brand fill. Material paints
  /// `primary` as text in many widgets (text buttons, focused labels,
  /// selected items); mapping it to brand/700 keeps all of them at AA by
  /// construction. The brand fill lives in `primaryContainer`.
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brand700,
    onPrimary: AppColors.surface0,
    primaryContainer: AppColors.brand500,
    onPrimaryContainer: AppTextColors.onBrand,
    secondary: AppColors.ink900,
    onSecondary: AppColors.surface0,
    secondaryContainer: AppColors.brand50,
    onSecondaryContainer: AppTextColors.primary,
    error: AppColors.danger500,
    onError: AppColors.surface0,
    errorContainer: AppColors.dangerTint,
    onErrorContainer: AppColors.danger500,
    surface: AppColors.surface0,
    onSurface: AppTextColors.primary,
    onSurfaceVariant: AppTextColors.secondary,
    surfaceContainerLow: AppColors.surface1,
    surfaceContainerHighest: AppColors.surface2,
    outline: AppColors.ink600,
    outlineVariant: AppColors.line,
    scrim: AppColors.scrim,
    surfaceTint: Colors.transparent,
  );

  static final TextTheme _textTheme =
      const TextTheme(
        displayLarge: AppTypography.display,
        displayMedium: AppTypography.display,
        displaySmall: AppTypography.display,
        headlineLarge: AppTypography.display,
        headlineMedium: AppTypography.display,
        headlineSmall: AppTypography.title,
        titleLarge: AppTypography.title,
        titleMedium: AppTypography.subtitle,
        titleSmall: AppTypography.bodyStrong,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.bodyStrong,
        labelMedium: AppTypography.captionStrong,
        labelSmall: AppTypography.overline,
      ).apply(
        bodyColor: AppTextColors.primary,
        displayColor: AppTextColors.primary,
      );

  static WidgetStateProperty<BorderSide?> _focusRing(
    AppSemanticColors colors, {
    BorderSide? resting,
    BorderSide? disabled,
  }) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: colors.focusRing, width: AppSizes.focusWidth);
      }
      if (states.contains(WidgetState.disabled)) return disabled ?? resting;
      return resting;
    });
  }

  static ButtonStyle _baseButton(Size minimumSize) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(minimumSize),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.x6,
          vertical: AppSpacing.x3,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(AppTypography.bodyStrong),
      elevation: const WidgetStatePropertyAll(0),
      animationDuration: AppMotion.transitionDuration,
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  static ButtonStyle _primaryButton(AppSemanticColors colors) {
    return _baseButton(const Size(64, AppSizes.buttonHeight)).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.surfaceInset;
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return colors.brandFillPressed;
        }
        return colors.brandFill;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.textSecondary
            : colors.onBrandFill,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      side: _focusRing(colors),
    );
  }

  static ButtonStyle _secondaryButton(AppSemanticColors colors) {
    return _baseButton(const Size(64, AppSizes.buttonHeight)).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? colors.surfaceInset
            : Colors.transparent,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.textSecondary
            : AppTextColors.primary,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      side: _focusRing(
        colors,
        resting: const BorderSide(color: AppColors.ink900),
        disabled: BorderSide(color: colors.line),
      ),
    );
  }

  static ButtonStyle _textButton(AppSemanticColors colors) {
    return _baseButton(
      const Size(AppSizes.touchTarget, AppSizes.touchTarget),
    ).copyWith(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x2,
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.textSecondary
            : colors.link,
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.pressed) ? colors.brandTint : null,
      ),
      side: _focusRing(colors),
    );
  }
}
