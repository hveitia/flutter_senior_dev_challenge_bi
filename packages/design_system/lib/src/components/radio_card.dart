import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_motion.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// One option of a single-choice question, as a full-width card.
///
/// The choice is shown by the radio mark as well as by the tinted fill, and
/// it is announced as one option of a mutually exclusive group.
class RadioCard extends StatefulWidget {
  const RadioCard({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;

  /// Null disables the card.
  final VoidCallback? onSelected;

  @override
  State<RadioCard> createState() => _RadioCardState();
}

class _RadioCardState extends State<RadioCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(context.metrics.inputRadius);
    final enabled = widget.onSelected != null;

    final border = _focused
        ? Border.all(color: colors.focusRing, width: AppSizes.focusWidth)
        : Border.all(color: widget.selected ? colors.link : colors.line);

    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: widget.selected,
      enabled: enabled,
      child: AnimatedContainer(
        duration: AppMotion.transitionDuration,
        curve: AppMotion.transitionCurve,
        constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
        decoration: BoxDecoration(
          color: widget.selected ? colors.brandTint : scheme.surface,
          borderRadius: radius,
          border: border,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onSelected,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: AppTypography.body.copyWith(
                        color: enabled
                            ? scheme.onSurface
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Icon(
                    widget.selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: AppSizes.icon,
                    color: widget.selected ? colors.link : colors.icon,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
