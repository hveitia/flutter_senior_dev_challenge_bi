import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// Emphasis of an [AppButton].
enum AppButtonVariant {
  /// Brand fill with ink label. One per screen.
  primary,

  /// Ink outline, for the alternative to the primary action.
  secondary,

  /// Text only, for low-emphasis actions and links.
  text,
}

/// The app's button. Colors, shape and focus ring come from the theme.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// Replaces the label with a progress indicator and blocks interaction
  /// while keeping the button's size, so the layout does not jump.
  final bool isLoading;
  final IconData? icon;

  /// Whether the button takes all the horizontal space it is offered.
  final bool expand;

  static void _ignoreTap() {}

  @override
  Widget build(BuildContext context) {
    // While loading the button keeps its enabled look; interaction is
    // blocked below so a second tap cannot submit twice.
    final callback = isLoading ? _ignoreTap : onPressed;
    final content = _Content(label: label, icon: icon, isLoading: isLoading);

    Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: callback,
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: callback,
        child: content,
      ),
    };

    if (expand) button = SizedBox(width: double.infinity, child: button);
    if (!isLoading) return button;

    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: '$label, cargando',
      child: ExcludeSemantics(child: IgnorePointer(child: button)),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.icon,
    required this.isLoading,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppSizes.icon),
          const SizedBox(width: AppSpacing.x2),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility.maintain(visible: !isLoading, child: labelRow),
        if (isLoading)
          SizedBox.square(
            dimension: AppSizes.icon,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: DefaultTextStyle.of(context).style.color,
            ),
          ),
      ],
    );
  }
}
