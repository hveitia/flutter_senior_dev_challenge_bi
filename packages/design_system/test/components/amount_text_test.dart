import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  /// The span built by [AmountText]; `Text.rich` nests it under a span that
  /// carries the inherited default style.
  TextSpan amountSpan(WidgetTester tester) {
    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(AmountText),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains(r'$'),
        ),
      ),
    );
    return (richText.text as TextSpan).children!.single as TextSpan;
  }

  testWidgets('renders the amount in the product format', (tester) async {
    await pumpApp(tester, const AmountText(cents: 482035));

    expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);
  });

  testWidgets('formats the same way on any device locale', (tester) async {
    for (final locale in const [Locale('es', 'EC'), Locale('de', 'DE')]) {
      await pumpApp(
        tester,
        Localizations(
          locale: locale,
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: const AmountText(cents: 482035),
        ),
      );

      expect(find.text(r'$4,820.35', findRichText: true), findsOneWidget);
    }
  });

  testWidgets('draws cents smaller and uses tabular figures', (tester) async {
    await pumpApp(
      tester,
      const AmountText(cents: 482035, size: AmountTextSize.display),
    );

    final root = amountSpan(tester);
    final cents = root.children!.last as TextSpan;

    expect(root.style!.fontFeatures, AppTypography.amountFeatures);
    expect(cents.text, '.35');
    expect(
      cents.style!.fontSize,
      AppTypography.display.fontSize! * AppTypography.amountCentsScale,
    );
  });

  testWidgets('exposes one natural-language label to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const AmountText(cents: 482035));

    expect(
      find.bySemanticsLabel('4820 dólares con 35 centavos'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('income is signalled by sign and icon, not by color alone', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const AmountText(cents: 185000, signDisplay: AmountSignDisplay.always),
    );

    expect(find.text('+\u00A0\$1,850.00', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.south_east), findsOneWidget);
    expect(amountSpan(tester).style!.color, AppColors.success500);
  });

  testWidgets('expenses show a minus and no income icon', (tester) async {
    await pumpApp(
      tester,
      const AmountText(cents: -6480, signDisplay: AmountSignDisplay.always),
    );

    expect(
      find.text('\u2212\u00A0\$64.80', findRichText: true),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.south_east), findsNothing);
    expect(amountSpan(tester).style!.color, AppColors.ink900);
  });
}
