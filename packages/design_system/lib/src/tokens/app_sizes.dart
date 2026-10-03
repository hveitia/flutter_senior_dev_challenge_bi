/// Fixed dimensions. Mirrors `tokens/tokens.json`.
abstract final class AppSizes {
  static const double buttonHeight = 52;

  /// Minimum interactive area, regardless of the visual size of a control.
  static const double touchTarget = 48;
  static const double icon = 24;

  /// Icon set next to body text, as in banners and selected chips.
  static const double iconMedium = 20;

  /// Icon set next to caption text, as in status chips and field errors.
  static const double iconSmall = 16;

  /// Thickness of progress lines and spinners.
  static const double progressStroke = 2;
  static const double iconStroke = 1.5;
  static const double border = 1;
  static const double bottomNavigation = 82;
  static const double focusWidth = 2;
  static const double focusOffset = 2;
}
