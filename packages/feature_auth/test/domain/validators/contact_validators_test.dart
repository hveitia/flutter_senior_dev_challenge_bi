import 'package:feature_auth/src/domain/validators/contact_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmailAddress', () {
    test('accepts ordinary addresses', () {
      expect(EmailAddress.isValid('valentina.andrade@example.com'), isTrue);
      expect(EmailAddress.isValid('demo+tag@sub.example.ec'), isTrue);
    });

    test('rejects addresses without a local part, domain or dot', () {
      expect(EmailAddress.isValid(''), isFalse);
      expect(EmailAddress.isValid('@example.com'), isFalse);
      expect(EmailAddress.isValid('valentina@'), isFalse);
      expect(EmailAddress.isValid('valentina@example'), isFalse);
      expect(EmailAddress.isValid('valentina example@example.com'), isFalse);
      expect(EmailAddress.isValid('a@b@example.com'), isFalse);
    });

    test('accepts a domain with several labels', () {
      expect(EmailAddress.isValid('ana@correo.banco.com.ec'), isTrue);
    });

    test('rejects a domain with an empty label', () {
      expect(EmailAddress.isValid('a@b..c'), isFalse);
      expect(EmailAddress.isValid('ana@.example.com'), isFalse);
      expect(EmailAddress.isValid('ana@example.com.'), isFalse);
    });

    test('rejects addresses longer than the limit of the standard', () {
      final local = 'a' * 250;

      expect(EmailAddress.isValid('$local@example.com'), isFalse);
    });

    test('normalizes by trimming and lowercasing', () {
      expect(
        EmailAddress.normalize('  Valentina.Andrade@Example.COM '),
        'valentina.andrade@example.com',
      );
    });

    test('validates the normalized form', () {
      expect(EmailAddress.isValid('  Valentina@Example.com '), isTrue);
    });
  });

  group('EcuadorMobile', () {
    test('normalizes the local format to ten digits', () {
      expect(EcuadorMobile.normalize('0991234567'), '0991234567');
      expect(EcuadorMobile.normalize('099 123 4567'), '0991234567');
      expect(EcuadorMobile.normalize('099-123-4567'), '0991234567');
    });

    test('normalizes the international format to the local one', () {
      expect(EcuadorMobile.normalize('+593991234567'), '0991234567');
      expect(EcuadorMobile.normalize('+593 99 123 4567'), '0991234567');
      expect(EcuadorMobile.normalize('593991234567'), '0991234567');
    });

    test('rejects landlines, short and long numbers', () {
      expect(EcuadorMobile.normalize('022345678'), isNull);
      expect(EcuadorMobile.normalize('0891234567'), isNull);
      expect(EcuadorMobile.normalize('099123456'), isNull);
      expect(EcuadorMobile.normalize('09912345678'), isNull);
      expect(EcuadorMobile.normalize(''), isNull);
    });

    test('rejects letters instead of dropping them', () {
      expect(EcuadorMobile.normalize('09912345a7'), isNull);
    });

    test('is valid exactly when it can be normalized', () {
      expect(EcuadorMobile.isValid('099 123 4567'), isTrue);
      expect(EcuadorMobile.isValid('022345678'), isFalse);
    });
  });

  group('FullName', () {
    test('accepts a given name and a family name', () {
      expect(FullName.isValid('Valentina Andrade'), isTrue);
      expect(FullName.isValid('María José Ñáñez-O’Brien'), isTrue);
    });

    test('accepts ñ, accents and diaeresis in any position', () {
      expect(FullName.isValid('Íñigo Muñoz'), isTrue);
      expect(FullName.isValid('Ángela Peñafiel Güiracocha'), isTrue);
      expect(FullName.isValid('ÓSCAR NÚÑEZ'), isTrue);
    });

    group('typed with separate accent marks, as some keyboards send them', () {
      // "María Peña Güiracocha" with each mark as its own character, built
      // from code points so the marks are visible in this file.
      final acute = String.fromCharCode(0x0301);
      final tilde = String.fromCharCode(0x0303);
      final diaeresis = String.fromCharCode(0x0308);
      final decomposed = 'Mari${acute}a Pen${tilde}a Gu${diaeresis}iracocha';

      test('is accepted', () {
        expect(FullName.isValid(decomposed), isTrue);
      });

      test('is normalized to single accented letters', () {
        expect(FullName.normalize(decomposed), 'María Peña Güiracocha');
        expect(
          FullName.normalize('A${acute}NGEL NU${acute}N${tilde}EZ'),
          'ÁNGEL NÚÑEZ',
        );
      });

      test('keeps a mark it cannot attach to a letter, so it is rejected', () {
        expect(FullName.isValid('Ana$acute ${acute}Mora'), isFalse);
      });
    });

    test('rejects a single word', () {
      expect(FullName.isValid('Valentina'), isFalse);
    });

    test('rejects digits and symbols', () {
      expect(FullName.isValid('Valentina 4ndrade'), isFalse);
      expect(FullName.isValid('Valentina <Andrade>'), isFalse);
    });

    test('rejects names longer than the stored limit', () {
      expect(FullName.isValid('${'a' * 80} ${'b' * 80}'), isFalse);
    });

    test('normalizes by trimming and collapsing spaces', () {
      expect(
        FullName.normalize('  Valentina   Andrade  '),
        'Valentina Andrade',
      );
    });
  });
}
