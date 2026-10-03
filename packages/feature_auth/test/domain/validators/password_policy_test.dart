import 'package:feature_auth/src/domain/validators/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy', () {
    test('reports no requirement met for an empty password', () {
      expect(PasswordPolicy.met(''), isEmpty);
    });

    test('reports each requirement independently', () {
      expect(PasswordPolicy.met('abcdefgh'), {PasswordRequirement.minLength});
      expect(PasswordPolicy.met('A'), {PasswordRequirement.uppercase});
      expect(PasswordPolicy.met('7'), {PasswordRequirement.number});
      expect(PasswordPolicy.met('#'), {PasswordRequirement.symbol});
    });

    test('counts an accented capital as an uppercase letter', () {
      expect(PasswordPolicy.met('Ñ'), {PasswordRequirement.uppercase});
    });

    test('does not count a space as a symbol', () {
      expect(PasswordPolicy.met(' '), isEmpty);
    });

    test('is satisfied only when every requirement is met', () {
      expect(PasswordPolicy.isSatisfiedBy('Segura#2026'), isTrue);
      expect(PasswordPolicy.isSatisfiedBy('segura#2026'), isFalse);
      expect(PasswordPolicy.isSatisfiedBy('Segura2026'), isFalse);
      expect(PasswordPolicy.isSatisfiedBy('Segura#abc'), isFalse);
      expect(PasswordPolicy.isSatisfiedBy('Se#2026'), isFalse);
    });

    test('lists requirements in the order they are shown', () {
      expect(PasswordRequirement.values, [
        PasswordRequirement.minLength,
        PasswordRequirement.uppercase,
        PasswordRequirement.number,
        PasswordRequirement.symbol,
      ]);
    });
  });
}
