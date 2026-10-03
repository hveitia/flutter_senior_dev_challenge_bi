import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// One line of a checklist the customer satisfies as they type, such as the
/// rules of a password.
///
/// Met and pending differ by icon and by wording for screen readers, not
/// only by color.
class RequirementItem extends StatelessWidget {
  const RequirementItem({required this.label, required this.met, super.key});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = met ? colors.success : colors.textSecondary;

    return Semantics(
      container: true,
      label: '$label, ${met ? 'cumplido' : 'pendiente'}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              met ? Icons.check : Icons.radio_button_unchecked,
              size: AppSizes.iconSmall,
              color: color,
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
