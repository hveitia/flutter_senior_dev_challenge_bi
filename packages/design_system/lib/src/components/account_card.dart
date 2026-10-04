import 'package:design_system/src/components/amount_text.dart';
import 'package:design_system/src/formatting/amount_formatter.dart';
import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// An account in a list: its name, the end of its number and its balance.
///
/// The whole card is one button. It takes plain values, so any domain
/// package can show an account without depending on another.
class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.name,
    required this.maskedNumber,
    required this.balanceCents,
    required this.onTap,
    this.balanceObscured = false,
    super.key,
  });

  final String name;

  /// The number with everything but its last digits hidden: `****4821`.
  final String maskedNumber;

  /// Balance in minor units.
  final int balanceCents;
  final VoidCallback onTap;

  /// Hides the balance, on screen and when read aloud.
  final bool balanceObscured;

  /// What hides the start of the number, dropped when reading it aloud.
  static final RegExp _mask = RegExp(r'^\D+');

  String get _spokenLabel {
    final ending = maskedNumber.replaceFirst(_mask, '');
    final balance = balanceObscured
        ? AmountText.obscuredLabel
        : amountSemanticLabel(balanceCents);
    return '$name, terminada en $ending, $balance';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(context.metrics.cardRadius);

    return Semantics(
      button: true,
      label: _spokenLabel,
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
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: AppSizes.icon,
                        color: colors.icon,
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: AppSizes.icon,
                        color: colors.icon,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  Wrap(
                    spacing: AppSpacing.x1,
                    children: [
                      Text(
                        name,
                        style: AppTypography.captionStrong.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        maskedNumber,
                        style: AppTypography.captionStrong.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  AmountText(cents: balanceCents, obscured: balanceObscured),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
