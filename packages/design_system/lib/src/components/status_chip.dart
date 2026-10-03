import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_tone.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Read-only pill that states the status of something: "En cola",
/// "Completado", "Fallido". Always an icon plus a label.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final String label;
  final AppTone tone;

  /// Defaults to the icon of the [tone].
  final IconData? icon;

  static IconData _defaultIcon(AppTone tone) => switch (tone) {
    AppTone.success => Icons.check_circle_outline,
    AppTone.danger => Icons.error_outline,
    AppTone.warning => Icons.schedule,
    AppTone.info => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = colors.foreground(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tint(tone),
        borderRadius: BorderRadius.circular(context.metrics.chipRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon ?? _defaultIcon(tone),
                size: AppSizes.iconSmall,
                color: foreground,
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Flexible(
              child: Text(
                label,
                style: AppTypography.captionStrong.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
