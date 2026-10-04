import 'package:design_system/src/components/status_chip.dart';
import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_tone.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// A card that opens something: a pictogram, what it is, one line about it
/// and, when it applies, a badge that says whose it is.
///
/// The whole card is one button. It takes plain values, so any domain
/// package can list what it offers.
class LinkCard extends StatelessWidget {
  const LinkCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  /// A short qualifier shown under the description: "Aliado".
  final String? badge;

  String get _spokenLabel => [title, description, ?badge].join(', ');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(context.metrics.cardRadius);
    final badge = this.badge;

    return Semantics(
      button: true,
      label: _spokenLabel,
      // The card below is excluded so it is read as one item; the action
      // has to be offered here or a screen reader could not open it.
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.line),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.touchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Row(
                  children: [
                    Icon(icon, size: AppSizes.icon, color: colors.icon),
                    const SizedBox(width: AppSpacing.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppTypography.bodyStrong.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x1),
                          Text(
                            description,
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(height: AppSpacing.x2),
                            StatusChip(label: badge, tone: AppTone.info),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Icon(
                      Icons.arrow_forward,
                      size: AppSizes.icon,
                      color: colors.icon,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
