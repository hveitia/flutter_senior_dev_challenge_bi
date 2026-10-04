import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  group('an obscured amount', () {
    testWidgets('shows no figure', (tester) async {
      await pumpApp(
        tester,
        const AmountText(cents: 482035, obscured: true),
      );

      expect(find.textContaining('4,820', findRichText: true), findsNothing);
      expect(find.textContaining('35', findRichText: true), findsNothing);
      expect(find.text(AmountText.obscuredText), findsOneWidget);
    });

    testWidgets('is announced as hidden, not as dots', (tester) async {
      await pumpApp(
        tester,
        const AmountText(cents: 482035, obscured: true),
      );

      expect(find.bySemanticsLabel(AmountText.obscuredLabel), findsOneWidget);
    });
  });

  group('an account card with its balance obscured', () {
    Future<void> pumpCard(WidgetTester tester) {
      return pumpApp(
        tester,
        AccountCard(
          name: 'Cuenta de ahorros',
          maskedNumber: '****4821',
          balanceCents: 357035,
          balanceObscured: true,
          onTap: () {},
        ),
      );
    }

    testWidgets('keeps the name and number and hides the figure', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(find.text('Cuenta de ahorros'), findsOneWidget);
      expect(find.text('****4821'), findsOneWidget);
      expect(find.textContaining('3,570', findRichText: true), findsNothing);
    });

    testWidgets('does not read the balance aloud', (tester) async {
      await pumpCard(tester);

      final label = tester.getSemantics(find.byType(AccountCard)).label;
      expect(label, contains('Cuenta de ahorros'));
      expect(label, contains(AmountText.obscuredLabel));
      expect(label, isNot(contains('dólares')));
    });
  });
}
