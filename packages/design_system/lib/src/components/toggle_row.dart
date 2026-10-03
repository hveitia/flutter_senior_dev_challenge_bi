import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// A setting that is on or off, with its label on the left.
///
/// Label and switch are announced as one control.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(color: scheme.onSurface),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.onBrandFill
                  : scheme.surface,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.brandFill
                  : colors.icon,
            ),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
        ],
      ),
    );
  }
}
