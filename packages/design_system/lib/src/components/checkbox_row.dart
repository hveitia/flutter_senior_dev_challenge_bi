import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// A checkbox with a label that may contain links.
///
/// The label is a widget of its own rather than part of the checkbox, so
/// links in it stay reachable. [semanticLabel] is what the checkbox itself is
/// announced as.
class CheckboxRow extends StatelessWidget {
  const CheckboxRow({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    required this.label,
    super.key,
  });

  final bool value;

  /// Null disables the checkbox.
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final onChanged = this.onChanged;
    // Centers the first line of the label on the checkbox, whatever the
    // text size the customer chose.
    final lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale(AppTypography.body.fontSize! * AppTypography.body.height!);
    final labelInset = ((AppSizes.touchTarget - lineHeight) / 2).clamp(
      0.0,
      AppSizes.touchTarget,
    );

    final toggle = onChanged == null ? null : () => onChanged(!value);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Material centers the box in its touch target, which pushes it in
        // from the edge the rest of a form is aligned to. Here the target
        // starts at that edge and the box is drawn at its start.
        Semantics(
          container: true,
          label: semanticLabel,
          checked: value,
          enabled: toggle != null,
          onTap: toggle,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: toggle,
            child: SizedBox.square(
              dimension: AppSizes.touchTarget,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox.square(
                  dimension: Checkbox.width,
                  // The checkbox keeps its own size, larger than the box it
                  // draws, and overflows evenly around it.
                  child: OverflowBox(
                    minWidth: 0,
                    minHeight: 0,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: ExcludeSemantics(
                      child: Checkbox(
                        value: value,
                        onChanged: onChanged == null
                            ? null
                            : (checked) => onChanged(checked ?? false),
                        fillColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? colors.brandFill
                              : scheme.surface,
                        ),
                        checkColor: colors.onBrandFill,
                        side: BorderSide(
                          color: scheme.onSurface,
                          width: AppSizes.iconStroke,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: labelInset),
            child: label,
          ),
        ),
      ],
    );
  }
}
