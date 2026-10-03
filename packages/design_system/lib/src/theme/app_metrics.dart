import 'dart:ui' show lerpDouble;

import 'package:design_system/src/tokens/app_radii.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// Layout metrics Material's theme has no slot for: spacing and radii.
@immutable
class AppMetrics extends ThemeExtension<AppMetrics> {
  const AppMetrics({
    required this.screenMargin,
    required this.moduleGap,
    required this.componentGap,
    required this.cardRadius,
    required this.inputRadius,
    required this.buttonRadius,
    required this.chipRadius,
    required this.sheetRadius,
  });

  static const AppMetrics standard = AppMetrics(
    screenMargin: AppSpacing.screenMargin,
    moduleGap: AppSpacing.moduleGap,
    componentGap: AppSpacing.componentGap,
    cardRadius: AppRadii.card,
    inputRadius: AppRadii.input,
    buttonRadius: AppRadii.button,
    chipRadius: AppRadii.chip,
    sheetRadius: AppRadii.sheet,
  );

  final double screenMargin;
  final double moduleGap;
  final double componentGap;
  final double cardRadius;
  final double inputRadius;
  final double buttonRadius;
  final double chipRadius;
  final double sheetRadius;

  @override
  AppMetrics copyWith({
    double? screenMargin,
    double? moduleGap,
    double? componentGap,
    double? cardRadius,
    double? inputRadius,
    double? buttonRadius,
    double? chipRadius,
    double? sheetRadius,
  }) {
    return AppMetrics(
      screenMargin: screenMargin ?? this.screenMargin,
      moduleGap: moduleGap ?? this.moduleGap,
      componentGap: componentGap ?? this.componentGap,
      cardRadius: cardRadius ?? this.cardRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      chipRadius: chipRadius ?? this.chipRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
    );
  }

  @override
  AppMetrics lerp(AppMetrics? other, double t) {
    if (other == null) return this;
    double mix(double a, double b) => lerpDouble(a, b, t)!;
    return AppMetrics(
      screenMargin: mix(screenMargin, other.screenMargin),
      moduleGap: mix(moduleGap, other.moduleGap),
      componentGap: mix(componentGap, other.componentGap),
      cardRadius: mix(cardRadius, other.cardRadius),
      inputRadius: mix(inputRadius, other.inputRadius),
      buttonRadius: mix(buttonRadius, other.buttonRadius),
      chipRadius: mix(chipRadius, other.chipRadius),
      sheetRadius: mix(sheetRadius, other.sheetRadius),
    );
  }

  List<double> get _values => [
    screenMargin,
    moduleGap,
    componentGap,
    cardRadius,
    inputRadius,
    buttonRadius,
    chipRadius,
    sheetRadius,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppMetrics) return false;
    for (var i = 0; i < _values.length; i++) {
      if (other._values[i] != _values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_values);
}
