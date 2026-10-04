import 'package:design_system/src/formatting/amount_formatter.dart';
import 'package:design_system/src/formatting/typed_amount.dart';
import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// An amount while it is being typed, as [TypedAmount] writes it.
///
/// It always reads as a full amount, `$1.50`, and tells apart what was
/// typed from what is still to type: after `1` and the point, the two
/// decimals are drawn dimmed. That is what shows the customer that the
/// point was taken, and where the next digit goes.
class AmountEntryText extends StatelessWidget {
  const AmountEntryText({required this.typed, super.key});

  /// Whole dollars, then optionally a point and up to two decimals.
  final String typed;

  @override
  Widget build(BuildContext context) {
    final point = typed.indexOf(TypedAmount.decimalPoint);
    final whole = point < 0 ? typed : typed.substring(0, point);
    final decimals = point < 0 ? '' : typed.substring(point + 1);
    final cents = TypedAmount.cents(typed);

    final style = AppTypography.display.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontFeatures: AppTypography.amountFeatures,
    );
    final pending = TextStyle(color: context.colors.textSecondary);
    final small = TextStyle(
      fontSize: style.fontSize! * AppTypography.amountCentsScale,
    );
    final missing = '0' * (TypedAmount.maxDecimals - decimals.length);

    return Semantics(
      liveRegion: true,
      label: amountSemanticLabel(cents),
      child: ExcludeSemantics(
        // The longest amount at the largest text still fits a narrow phone.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(
                  // Grouped as every other amount in the app.
                  text: formatAmount(cents - cents % 100).integer,
                  style: whole.isEmpty ? pending : null,
                ),
                TextSpan(
                  text: TypedAmount.decimalPoint,
                  style: point < 0 ? small.merge(pending) : small,
                ),
                if (decimals.isNotEmpty) TextSpan(text: decimals, style: small),
                if (missing.isNotEmpty)
                  TextSpan(text: missing, style: small.merge(pending)),
              ],
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
