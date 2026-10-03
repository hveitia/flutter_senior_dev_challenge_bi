import 'package:design_system/src/components/app_button.dart';
import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Failure of one part of a screen, with a way to retry it.
///
/// It replaces only the content that failed, so the rest of the screen keeps
/// working: this is the building block of partial degradation.
class InlineError extends StatelessWidget {
  const InlineError({
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Reintentar',
    this.isRetrying = false,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  /// Shows progress on the retry action and blocks repeated taps.
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.metrics.cardRadius),
        border: Border.all(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: AppSizes.icon,
                color: colors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: scheme.onSurface),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            AppButton(
              label: retryLabel,
              variant: AppButtonVariant.text,
              expand: false,
              isLoading: isRetrying,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
