import 'package:feature_auth/src/domain/validators/cedula.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cedula.isValid', () {
    test('accepts numbers whose check digit matches', () {
      expect(Cedula.isValid('1710034065'), isTrue);
      expect(Cedula.isValid('0926687856'), isTrue);
    });

    test('accepts a check digit of zero', () {
      // The first nine digits add up to a multiple of ten.
      expect(Cedula.isValid('1700000050'), isTrue);
    });

    test('rejects a number whose check digit does not match', () {
      expect(Cedula.isValid('1710034064'), isFalse);
    });

    test('rejects two adjacent digits swapped', () {
      expect(Cedula.isValid('1710030465'), isFalse);
    });

    test('rejects anything that is not exactly ten digits', () {
      expect(Cedula.isValid('123456789'), isFalse);
      expect(Cedula.isValid('17100340650'), isFalse);
      expect(Cedula.isValid(''), isFalse);
      expect(Cedula.isValid('17100 4065'), isFalse);
      expect(Cedula.isValid('171003406a'), isFalse);
    });

    test('rejects province codes that do not exist', () {
      expect(Cedula.isValid('0010034064'), isFalse);
      expect(Cedula.isValid('2510034065'), isFalse);
      expect(Cedula.isValid('2910034061'), isFalse);
    });

    test('accepts the first and the last province', () {
      // Worked by hand: 01 → 0·2 + 1 = 1, check 9; 24 → 2·2 + 4 = 8, check 2.
      expect(Cedula.isValid('0100000009'), isTrue);
      expect(Cedula.isValid('2400000002'), isTrue);
    });

    test('accepts every check digit from 0 to 9', () {
      // 17 adds 2 + 7 = 9. The ninth digit is doubled, minus 9 above 9, so
      // each value of it moves the sum to a different final digit.
      const numbers = [
        '1700000050', // 9 + 1 = 10, check 0
        '1700000001', // 9 + 0 = 9, check 1
        '1700000092', // 9 + 9 = 18, check 2
        '1700000043', // 9 + 8 = 17, check 3
        '1700000084', // 9 + 7 = 16, check 4
        '1700000035', // 9 + 6 = 15, check 5
        '1700000076', // 9 + 5 = 14, check 6
        '1700000027', // 9 + 4 = 13, check 7
        '1700000068', // 9 + 3 = 12, check 8
        '1700000019', // 9 + 2 = 11, check 9
      ];

      expect({for (final number in numbers) number[9]}, hasLength(10));
      for (final number in numbers) {
        expect(Cedula.isValid(number), isTrue, reason: number);
      }
    });

    test('accepts 5 as the third digit and rejects 6', () {
      // 1·2 + 7 + (5·2 − 9) = 10, check 0.
      expect(Cedula.isValid('1750000000'), isTrue);
      // 1·2 + 7 + (6·2 − 9) = 12, check 8: right digit, wrong kind of holder.
      expect(Cedula.isValid('1760000008'), isFalse);
    });

    test('rejects surrounding whitespace instead of ignoring it', () {
      expect(Cedula.isValid(' 1710034065'), isFalse);
      expect(Cedula.isValid('1710034065 '), isFalse);
      expect(Cedula.isValid('1710034065\n'), isFalse);
    });

    test('accepts the code for citizens registered abroad', () {
      expect(Cedula.isValid('3010034068'), isTrue);
    });

    test('rejects a third digit reserved for companies', () {
      // Check digit is right for these nine digits; only the type is wrong.
      expect(Cedula.isValid('1760034064'), isFalse);
      expect(Cedula.isValid('1790034068'), isFalse);
    });
  });
}
