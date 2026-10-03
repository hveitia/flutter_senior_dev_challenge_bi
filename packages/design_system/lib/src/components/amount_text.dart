import 'package:design_system/src/formatting/amount_formatter.dart';
import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Visual weight of an [AmountText].
enum AmountTextSize {
  display(AppTypography.display),
  title(AppTypography.title),
  subtitle(AppTypography.subtitle),
  body(AppTypography.bodyStrong)
  ;

  const AmountTextSize(this.style);

  final TextStyle style;
}

/// A monetary amount in minor units, always rendered as `$4,820.35`.
///
/// Cents are drawn smaller, digits are tabular so amounts align in lists,
/// and assistive technology gets a single natural-language label.
class AmountText extends StatelessWidget {
  const AmountText({
    required this.cents,
    this.size = AmountTextSize.title,
    this.signDisplay = AmountSignDisplay.negativeOnly,
    super.key,
  });

  /// Amount in minor units: `482035` is `$4,820.35`.
  ///
  /// Never pass dollars here. `4820` would render as `$48.20`, and nothing
  /// can detect the mistake because both are valid integers.
  final int cents;
  final AmountTextSize size;
  final AmountSignDisplay signDisplay;

  @override
  Widget build(BuildContext context) {
    final amount = formatAmount(cents, signDisplay: signDisplay);
    final isIncome = signDisplay == AmountSignDisplay.always && cents > 0;
    final color = isIncome
        ? context.colors.success
        : Theme.of(context).colorScheme.onSurface;
    final style = size.style.copyWith(
      color: color,
      fontFeatures: AppTypography.amountFeatures,
    );

    final text = Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '${amount.sign}${amount.integer}'),
          TextSpan(
            text: amount.cents,
            style: TextStyle(
              fontSize: style.fontSize! * AppTypography.amountCentsScale,
            ),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      semanticsLabel: amountSemanticLabel(cents, signDisplay: signDisplay),
    );

    if (!isIncome) return text;

    // The arrow repeats what the plus sign says so that income is never
    // conveyed by the green color alone.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.south_east,
            size: style.fontSize,
            color: color,
          ),
        ),
        const SizedBox(width: AppSpacing.x1),
        Flexible(child: text),
      ],
    );
  }
}
