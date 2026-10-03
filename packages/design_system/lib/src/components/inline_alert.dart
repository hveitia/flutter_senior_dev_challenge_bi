import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_tone.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Message about the form or section it sits in: why a submission did not
/// go through, or a notice the customer should read before continuing.
///
/// Unlike `StatusBanner` it is a card within the page margins, and unlike a
/// field error it is not about one input. It is a live region, so it is
/// announced when it appears.
class InlineAlert extends StatelessWidget {
  const InlineAlert({
    required this.message,
    this.tone = AppTone.danger,
    this.icon = Icons.warning_amber_rounded,
    super.key,
  });

  final String message;
  final AppTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = colors.foreground(tone);

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tint(tone),
          borderRadius: BorderRadius.circular(context.metrics.inputRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: AppSizes.iconMedium, color: foreground),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.caption.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
