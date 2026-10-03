import 'package:design_system/src/theme/app_metrics.dart';
import 'package:design_system/src/theme/app_semantic_colors.dart';
import 'package:flutter/material.dart';

/// Shorthand for the design system's theme extensions.
extension AppThemeContext on BuildContext {
  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>()!;

  AppMetrics get metrics => Theme.of(this).extension<AppMetrics>()!;
}
