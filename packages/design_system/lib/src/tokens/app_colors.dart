import 'package:flutter/painting.dart';

/// Raw color palette. Mirrors `tokens/tokens.json`; see the drift test.
///
/// Components should not pick text colors from here directly: the allowed
/// text and background pairings live in `AppTextColors`, which is what the
/// contrast tests verify.
abstract final class AppColors {
  /// Fill for primary actions and key accents. Never a text color.
  static const Color brand500 = Color(0xFFEA8E29);

  /// Hover and pressed fill only.
  static const Color brand600 = Color(0xFFF2901E);

  /// Orange that is safe for text and links on light surfaces.
  static const Color brand700 = Color(0xFFA85A00);
  static const Color brand50 = Color(0xFFFDF3E7);

  static const Color ink900 = Color(0xFF36373A);

  /// Icons and decorative strokes. Below AA for body text on `surface1`.
  static const Color ink600 = Color(0xFF70767A);
  static const Color ink300 = Color(0xFFBABABA);

  /// Secondary text that reaches AA on every surface.
  static const Color textSecondary = Color(0xFF656B70);

  static const Color line = Color(0xFFE1E1E1);
  static const Color surface0 = Color(0xFFFFFFFF);
  static const Color surface1 = Color(0xFFF7F7F7);
  static const Color surface2 = Color(0xFFF1F1F1);

  static const Color success500 = Color(0xFF1E7B4A);
  static const Color successTint = Color(0xFFE6F4EC);
  static const Color danger500 = Color(0xFFB3261E);
  static const Color dangerTint = Color(0xFFFCEBEA);
  static const Color warning500 = Color(0xFF8A5A00);
  static const Color warningTint = Color(0xFFFFF4D6);
  static const Color info500 = Color(0xFF1D5FA8);
  static const Color infoTint = Color(0xFFE8F1FB);

  static const Color focusRing = ink900;
  static const Color scrim = Color.fromRGBO(54, 55, 58, 0.25);
}
