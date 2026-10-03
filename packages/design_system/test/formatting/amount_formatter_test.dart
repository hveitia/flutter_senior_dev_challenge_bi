import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatAmount', () {
    test('groups thousands with commas and always shows two decimals', () {
      expect(formatAmount(482035).text, r'$4,820.35');
      expect(formatAmount(0).text, r'$0.00');
      expect(formatAmount(5).text, r'$0.05');
      expect(formatAmount(99999).text, r'$999.99');
      expect(formatAmount(100000).text, r'$1,000.00');
      expect(formatAmount(100000000).text, r'$1,000,000.00');
    });

    test('splits the integer part from the cents for rendering', () {
      final amount = formatAmount(482035);

      expect(amount.sign, isEmpty);
      expect(amount.integer, r'$4,820');
      expect(amount.cents, '.35');
    });

    test('marks negative amounts with a minus that cannot wrap away', () {
      final amount = formatAmount(-6480);

      expect(amount.sign, '\u2212\u00A0');
      expect(amount.text, '\u2212\u00A0\$64.80');
    });

    test('shows a plus on positive amounts only when asked to', () {
      expect(formatAmount(185000).sign, isEmpty);
      expect(
        formatAmount(185000, signDisplay: AmountSignDisplay.always).text,
        '+\u00A0\$1,850.00',
      );
    });

    test('never signs zero', () {
      expect(
        formatAmount(0, signDisplay: AmountSignDisplay.always).text,
        r'$0.00',
      );
    });
  });

  group('amountSemanticLabel', () {
    test('reads the amount as a screen reader should say it in Spanish', () {
      expect(amountSemanticLabel(482035), '4820 dólares con 35 centavos');
    });

    test('omits the cents when there are none', () {
      expect(amountSemanticLabel(20000), '200 dólares');
    });

    test('uses singular units', () {
      expect(amountSemanticLabel(101), '1 dólar con 1 centavo');
    });

    test('says the sign instead of reading a symbol', () {
      expect(amountSemanticLabel(-6480), 'menos 64 dólares con 80 centavos');
      expect(
        amountSemanticLabel(185000, signDisplay: AmountSignDisplay.always),
        'más 1850 dólares',
      );
    });
  });
}
