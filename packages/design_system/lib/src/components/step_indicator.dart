import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_radii.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Where the customer is in a flow of several steps: "Paso 2 de 3" over one
/// bar per step, filled up to the current one.
class StepIndicator extends StatelessWidget {
  const StepIndicator({required this.current, required this.total, super.key})
    : assert(total > 0, 'A flow has at least one step'),
      assert(current >= 1 && current <= total, 'current is 1-based');

  /// Step being answered, counting from one.
  final int current;
  final int total;

  String get _label => 'Paso $current de $total';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      container: true,
      label: _label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Row(
              spacing: AppSpacing.x2,
              children: [
                for (var step = 1; step <= total; step++)
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: step <= current ? colors.brandFill : colors.line,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: const SizedBox(height: AppSpacing.x1),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
