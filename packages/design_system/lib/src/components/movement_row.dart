import 'package:design_system/src/components/amount_text.dart';
import 'package:design_system/src/formatting/amount_formatter.dart';
import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// A movement in a list: what it was, when, and how much went in or out.
///
/// The amount always carries its sign, and income also gets an arrow, so the
/// direction never depends on color. It takes plain values, so any domain
/// package can show a movement without depending on another.
class MovementRow extends StatelessWidget {
  const MovementRow({
    required this.icon,
    required this.description,
    required this.detail,
    required this.amountCents,
    this.onTap,
    super.key,
  });

  /// Stands for the category of the movement.
  final IconData icon;
  final String description;

  /// Second line, usually the day and time: `Hoy · 08:45`.
  final String detail;

  /// Signed amount in minor units: positive is income.
  final int amountCents;

  /// Null draws a row that cannot be opened.
  final VoidCallback? onTap;

  static const double _badge = 40;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final spokenAmount = amountSemanticLabel(
      amountCents,
      signDisplay: AmountSignDisplay.always,
    );

    return Semantics(
      button: onTap != null,
      label: '$description, $detail, $spokenAmount',
      // The row below is excluded so it is read as one item; the action
      // has to be offered here or a screen reader could not open it.
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceInset,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: _badge,
                      child: Icon(
                        icon,
                        size: AppSizes.iconMedium,
                        color: colors.icon,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          description,
                          style: AppTypography.bodyStrong.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          detail,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  AmountText(
                    cents: amountCents,
                    size: AmountTextSize.body,
                    signDisplay: AmountSignDisplay.always,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
