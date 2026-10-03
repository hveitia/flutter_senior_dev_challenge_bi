import 'package:flutter/animation.dart';

/// Motion. Mirrors `tokens/tokens.json`.
///
/// Both transitions and the skeleton shimmer are disabled when the platform
/// requests reduced motion; components check `MediaQuery.disableAnimations`.
abstract final class AppMotion {
  static const Duration transitionDuration = Duration(milliseconds: 200);
  static const Curve transitionCurve = Curves.easeOut;
  static const Duration shimmerDuration = Duration(milliseconds: 1200);
  static const Curve shimmerCurve = Curves.linear;
}
