import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  group('maskedNumber', () {
    test('shows only the last four digits', () {
      expect(savings.maskedNumber, '****4821');
    });

    test('shows a short number whole rather than failing', () {
      const short = Account(
        id: 'short',
        name: 'Cuenta',
        kind: AccountKind.savings,
        number: '821',
        availableCents: 0,
        ledgerCents: 0,
        currency: 'USD',
      );

      expect(short.maskedNumber, '****821');
    });
  });

  test('the total adds what is available, not the booked balance', () {
    expect(totalAvailableCents([savings, checking]), 482035);
    expect(totalAvailableCents(const []), 0);
  });

  test('accounts are listed by kind and then by name', () {
    const secondSavings = Account(
      id: 'goal',
      name: 'Ahorro programado',
      kind: AccountKind.savings,
      number: '22007777',
      availableCents: 1000,
      ledgerCents: 1000,
      currency: 'USD',
    );

    expect(
      inListingOrder([checking, savings, secondSavings]).map((a) => a.id),
      ['goal', 'savings', 'checking'],
    );
  });

  test('an account kind this version does not know is not guessed', () {
    expect(AccountKind.fromId('savings'), AccountKind.savings);
    expect(AccountKind.fromId('investment'), isNull);
    expect(AccountKind.fromId(7), isNull);
  });
}
