import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_motion.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Selectable pill for filters and multiple-choice answers.
///
/// Selection is shown with a check mark as well as with the tinted fill.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;

  /// Null disables the chip.
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      avatar: selected
          ? Icon(Icons.check, size: 18, color: scheme.onSurface)
          : null,
      labelStyle: AppTypography.body.copyWith(color: scheme.onSurface),
      backgroundColor: scheme.surface,
      selectedColor: colors.brandTint,
      disabledColor: colors.surfaceInset,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pressElevation: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: const StadiumBorder(),
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(
            color: colors.focusRing,
            width: AppSizes.focusWidth,
          );
        }
        if (states.contains(WidgetState.selected)) {
          return BorderSide(color: colors.link);
        }
        return BorderSide(color: colors.line);
      }),
      chipAnimationStyle: ChipAnimationStyle(
        selectAnimation: const AnimationStyle(
          duration: AppMotion.transitionDuration,
          curve: AppMotion.transitionCurve,
        ),
      ),
    );
  }
}
