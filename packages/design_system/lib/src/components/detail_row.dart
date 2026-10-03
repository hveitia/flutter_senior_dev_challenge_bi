import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// One fact about something: its name on the left and its value on the
/// right, as in the details of a movement.
///
/// Label and value are read as one phrase. A [trailing] action, such as a
/// copy button, stays a control of its own.
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: '$label: $value',
              child: ExcludeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.x4,
                  runSpacing: AppSpacing.x1,
                  children: [
                    Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    Text(
                      value,
                      style: AppTypography.bodyStrong.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.x2),
            trailing!,
          ],
        ],
      ),
    );
  }
}
