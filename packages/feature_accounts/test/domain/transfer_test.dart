import 'dart:math';

import 'package:design_system/design_system.dart' show TypedAmount;
import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  group('validateTransfer', () {
    // Savings holds $3,570.35 available; checking $1,250.00.
    TransferFormError? check({
      Account? from = savings,
      Account? to = checking,
      int amountCents = 15010,
      String concept = '',
    }) => validateTransfer(
      from: from,
      to: to,
      amountCents: amountCents,
      concept: concept,
    );

    test('accepts an amount the source account can cover', () {
      expect(check(), isNull);
    });

    test('accepts exactly what is available', () {
      expect(check(from: checking, to: savings, amountCents: 125000), isNull);
    });

    test('refuses one cent more than what is available', () {
      expect(
        check(from: checking, to: savings, amountCents: 125001),
        TransferFormError.insufficientFunds,
      );
    });

    test('refuses an order without both accounts', () {
      expect(check(from: null), TransferFormError.missingAccounts);
      expect(check(to: null), TransferFormError.missingAccounts);
    });

    test('refuses the same account on both sides', () {
      expect(check(to: savings), TransferFormError.sameAccount);
    });

    test('refuses no amount', () {
      expect(check(amountCents: 0), TransferFormError.missingAmount);
    });

    test('refuses one cent over the limit of a transfer, before looking at '
        'the balance', () {
      const rich = Account(
        id: 'rich',
        name: 'Cuenta',
        kind: AccountKind.savings,
        number: '22000001',
        availableCents: 900000,
        ledgerCents: 900000,
        currency: 'USD',
      );

      expect(
        check(from: rich, amountCents: TransferLimits.maxCents),
        isNull,
      );
      expect(
        check(from: rich, amountCents: TransferLimits.maxCents + 1),
        TransferFormError.overLimit,
      );
    });

    test('measures the concept without the spaces around it', () {
      final longest = 'a' * TransferLimits.maxConceptLength;

      expect(check(concept: '  $longest  '), isNull);
      expect(check(concept: '${longest}a'), TransferFormError.conceptTooLong);
    });
  });

  group('transferableAccounts', () {
    test('leaves out what is invested', () {
      expect(transferableAccounts(const [savings, fund, checking]), const [
        savings,
        checking,
      ]);
    });
  });

  test('the amount entry holds more than any transfer allowed, so the limit '
      'is what stops a large amount, not the keys', () {
    expect(TypedAmount.maxCents, greaterThan(TransferLimits.maxCents));
  });

  group('newTransferId', () {
    final accepted = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

    test('has the shape the server and the rules accept as an order id', () {
      expect(newTransferId(), matches(accepted));
    });

    test('differs from one order to the next', () {
      final ids = {for (var i = 0; i < 50; i++) newTransferId()};

      expect(ids, hasLength(50));
    });

    test('depends only on the random source', () {
      expect(newTransferId(Random(7)), newTransferId(Random(7)));
    });
  });

  group('TransferRejection.fromCode', () {
    test('reads every code the server sends', () {
      expect(
        TransferRejection.fromCode('insufficient-funds'),
        TransferRejection.insufficientFunds,
      );
      expect(
        TransferRejection.fromCode('account-not-eligible'),
        TransferRejection.accountNotEligible,
      );
    });

    test('reads a code it does not know as a rejection all the same', () {
      expect(
        TransferRejection.fromCode('something-new'),
        TransferRejection.invalidRequest,
      );
      expect(
        TransferRejection.fromCode(null),
        TransferRejection.invalidRequest,
      );
    });
  });
}
