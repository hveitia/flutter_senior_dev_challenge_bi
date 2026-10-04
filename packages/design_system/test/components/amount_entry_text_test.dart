import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  group('AmountEntryText', () {
    Finder shows(String text) => find.text(text, findRichText: true);

    /// The text drawn in the color of what is still to be typed.
    Future<String> pending(WidgetTester tester) async {
      final context = tester.element(find.byType(AmountEntryText));
      final muted = context.colors.textSecondary;
      final buffer = StringBuffer();
      tester
          .renderObject<RenderParagraph>(
            find.descendant(
              of: find.byType(AmountEntryText),
              matching: find.byType(RichText),
            ),
          )
          .text
          .visitChildren((span) {
            if (span is TextSpan && span.style?.color == muted) {
              buffer.write(span.text ?? '');
            }
            return true;
          });
      return buffer.toString();
    }

    testWidgets('with nothing typed shows zero, all of it still to type', (
      tester,
    ) async {
      await pumpApp(tester, const AmountEntryText(typed: ''));

      expect(shows(r'$0.00'), findsOneWidget);
      expect(await pending(tester), r'$0.00');
    });

    testWidgets('a whole number is that many dollars', (tester) async {
      await pumpApp(tester, const AmountEntryText(typed: '1'));

      expect(shows(r'$1.00'), findsOneWidget);
      expect(await pending(tester), '.00');
    });

    testWidgets('the point shows as typed, the decimals still to type', (
      tester,
    ) async {
      await pumpApp(tester, const AmountEntryText(typed: '1.'));

      expect(shows(r'$1.00'), findsOneWidget);
      expect(await pending(tester), '00');
    });

    testWidgets('one decimal typed leaves one to type', (tester) async {
      await pumpApp(tester, const AmountEntryText(typed: '1.5'));

      expect(shows(r'$1.50'), findsOneWidget);
      expect(await pending(tester), '0');
    });

    testWidgets('a full amount has nothing left to type', (tester) async {
      await pumpApp(tester, const AmountEntryText(typed: '1.05'));

      expect(shows(r'$1.05'), findsOneWidget);
      expect(await pending(tester), isEmpty);
    });

    testWidgets('groups thousands', (tester) async {
      await pumpApp(tester, const AmountEntryText(typed: '1234567.8'));

      expect(shows(r'$1,234,567.80'), findsOneWidget);
    });

    testWidgets('is read aloud as an amount, and again when it changes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const AmountEntryText(typed: '150.1'));

      expect(
        tester.getSemantics(find.byType(AmountEntryText)),
        containsSemantics(
          label: '150 dólares con 10 centavos',
          isLiveRegion: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a long amount shrinks to fit a narrow screen', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        const AmountEntryText(typed: '1234567.89'),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AmountEntryText)).width,
        lessThanOrEqualTo(320 - 2 * AppSpacing.screenMargin),
      );
    });
  });
}
