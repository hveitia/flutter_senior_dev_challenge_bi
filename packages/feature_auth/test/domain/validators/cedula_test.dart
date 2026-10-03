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
