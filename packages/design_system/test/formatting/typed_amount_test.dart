import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

/// Presses [keys] one by one on an empty entry: a digit, or `.` for the
/// decimal point.
String typed(String keys, {String from = ''}) {
  var text = from;
  for (final key in keys.split('')) {
    text = key == '.'
        ? TypedAmount.withDecimalPoint(text)
        : TypedAmount.withDigit(text, int.parse(key));
  }
  return text;
}

void main() {
  group('TypedAmount.cents', () {
    test('nothing typed is zero', () {
      expect(TypedAmount.cents(''), 0);
    });

    test('a whole number is that many dollars', () {
      expect(TypedAmount.cents('1'), 100);
      expect(TypedAmount.cents('0'), 0);
      expect(TypedAmount.cents('25'), 2500);
      expect(TypedAmount.cents('5000'), 500000);
    });

    test('a decimal point with nothing after it adds no cents', () {
      expect(TypedAmount.cents('1.'), 100);
      expect(TypedAmount.cents('0.'), 0);
      expect(TypedAmount.cents('.'), 0);
    });

    test('one decimal is tens of cents, two are cents', () {
      expect(TypedAmount.cents('1.5'), 150);
      expect(TypedAmount.cents('1.50'), 150);
      expect(TypedAmount.cents('1.05'), 105);
      expect(TypedAmount.cents('0.01'), 1);
      expect(TypedAmount.cents('.5'), 50);
      expect(TypedAmount.cents('5000.00'), 500000);
    });

    test('one cent over a round amount is read exactly', () {
      expect(TypedAmount.cents('5000.01'), 500001);
    });

    test('is exact where a fraction in binary would not be', () {
      // 0.29 * 100 is 28.999999999999996 as a double.
      expect(TypedAmount.cents('0.29'), 29);
      expect(TypedAmount.cents('1.15'), 115);
      expect(TypedAmount.cents('4820.35'), 482035);
    });

    test('decimals beyond the second are not part of the amount', () {
      expect(TypedAmount.cents('1.505'), 150);
      expect(TypedAmount.cents('1.999'), 199);
    });

    test('leading zeros do not change the amount', () {
      expect(TypedAmount.cents('007'), 700);
      expect(TypedAmount.cents('000.5'), 50);
    });

    test('anything that is not a digit or the first point is ignored', () {
      expect(TypedAmount.cents(r'$15.01'), 1501);
      expect(TypedAmount.cents('1.2.3'), 123);
      expect(TypedAmount.cents('abc'), 0);
    });

    test('a run of digits too long to be real is held at the largest '
        'amount shown, never cut to its first digits', () {
      expect(TypedAmount.cents('9' * 40), TypedAmount.maxCents);
      expect(TypedAmount.cents('12345678'), TypedAmount.maxCents);
      expect(TypedAmount.cents('${'0' * 30}1'), 100);
    });
  });

  group('typing', () {
    test('one is one dollar, not one cent', () {
      expect(typed('1'), '1');
      expect(TypedAmount.cents(typed('1')), 100);
    });

    test('one, point, five is one fifty', () {
      expect(typed('1.5'), '1.5');
      expect(TypedAmount.cents(typed('1.5')), 150);
    });

    test('a point first starts at zero', () {
      expect(typed('.'), '0.');
      expect(typed('.5'), '0.5');
    });

    test('a second point is ignored', () {
      expect(typed('1..5'), '1.5');
      expect(typed('1.5.'), '1.5');
    });

    test('a third decimal is refused', () {
      expect(typed('1.505'), '1.50');
      expect(typed('0.999'), '0.99');
    });

    test('leading zeros collapse', () {
      expect(typed('007'), '7');
      expect(typed('000'), '0');
      expect(typed('0.07'), '0.07');
    });

    test(
      'the whole part stops growing at seven digits, decimals still fit',
      () {
        expect(typed('123456789'), '1234567');
        expect(typed('12345678.91'), '1234567.91');
      },
    );

    test('a digit that is not one digit changes nothing', () {
      expect(TypedAmount.withDigit('1', 10), '1');
      expect(TypedAmount.withDigit('1', -1), '1');
    });
  });

  group('TypedAmount.withoutLast', () {
    test('removes the last character typed', () {
      expect(TypedAmount.withoutLast('1.5'), '1.');
      expect(TypedAmount.withoutLast('1.'), '1');
      expect(TypedAmount.withoutLast('1'), '');
    });

    test('nothing typed stays empty', () {
      expect(TypedAmount.withoutLast(''), '');
    });
  });

  group('TypedAmount.fromCents', () {
    test('writes an amount as it would have been typed', () {
      expect(TypedAmount.fromCents(0), '');
      expect(TypedAmount.fromCents(100), '1');
      expect(TypedAmount.fromCents(150), '1.50');
      expect(TypedAmount.fromCents(105), '1.05');
      expect(TypedAmount.fromCents(5), '0.05');
      expect(TypedAmount.fromCents(482035), '4820.35');
    });

    test('reads back as the same amount', () {
      for (final cents in [1, 99, 100, 101, 2500, 15010, 500000]) {
        expect(TypedAmount.cents(TypedAmount.fromCents(cents)), cents);
      }
    });
  });
}
