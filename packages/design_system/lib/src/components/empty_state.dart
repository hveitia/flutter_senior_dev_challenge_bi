import 'package:design_system/src/components/app_button.dart';
import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Full-area message for when there is nothing to show: no data yet, or a
/// failure that left the screen without content.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.footnote,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Small print under the actions, for example the retry count.
  final String? footnote;

  static const double _badge = 64;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceInset,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: _badge,
              child: Icon(icon, size: AppSizes.icon, color: scheme.onSurface),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(color: scheme.onSurface),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ],
        if (primaryActionLabel != null) ...[
          const SizedBox(height: AppSpacing.x6),
          AppButton(label: primaryActionLabel!, onPressed: onPrimaryAction),
        ],
        if (secondaryActionLabel != null) ...[
          const SizedBox(height: AppSpacing.x2),
          AppButton(
            label: secondaryActionLabel!,
            variant: AppButtonVariant.text,
            onPressed: onSecondaryAction,
          ),
        ],
        if (footnote != null) ...[
          const SizedBox(height: AppSpacing.x3),
          Text(
            footnote!,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}
