import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_accounts/adapters.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeAccount', () {
    Map<String, Object?> document() => {
      AccountFields.name: 'Cuenta de ahorros',
      AccountFields.kind: 'savings',
      AccountFields.number: '22004821',
      AccountFields.availableCents: 357035,
      AccountFields.ledgerCents: 360000,
      AccountFields.currency: 'USD',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 3)),
    };

    test('reads an account as the server stores it', () {
      expect(
        FirestoreAccountsSource.decodeAccount('savings', document()),
        const Account(
          id: 'savings',
          name: 'Cuenta de ahorros',
          kind: AccountKind.savings,
          number: '22004821',
          availableCents: 357035,
          ledgerCents: 360000,
          currency: 'USD',
        ),
      );
    });

    test('ignores fields it does not know', () {
      final account = FirestoreAccountsSource.decodeAccount(
        'savings',
        document()..['nickname'] = 'Vacaciones',
      );

      expect(account, isNotNull);
    });

    test('leaves out an account whose balance is not whole cents, '
        'rather than rounding money', () {
      for (final balance in [3570.35, '357035', null]) {
        expect(
          FirestoreAccountsSource.decodeAccount(
            'savings',
            document()..[AccountFields.availableCents] = balance,
          ),
          isNull,
          reason: '$balance',
        );
      }
    });

    test('leaves out an account of a kind this version does not know', () {
      expect(
        FirestoreAccountsSource.decodeAccount(
          'savings',
          document()..[AccountFields.kind] = 'pension',
        ),
        isNull,
      );
    });

    test('leaves out an account without a name or a number', () {
      for (final field in [AccountFields.name, AccountFields.number]) {
        expect(
          FirestoreAccountsSource.decodeAccount(
            'savings',
            document()..remove(field),
          ),
          isNull,
          reason: field,
        );
      }
    });

    test('takes the booked balance from the available one when missing', () {
      final account = FirestoreAccountsSource.decodeAccount(
        'savings',
        document()..remove(AccountFields.ledgerCents),
      );

      expect(account?.ledgerCents, 357035);
    });
  });

  group('decodeMovement', () {
    final postedAt = DateTime(2026, 10, 3, 8, 45);

    Map<String, Object?> document() => {
      MovementFields.accountId: 'savings',
      MovementFields.description: 'Supermercado',
      MovementFields.category: 'groceries',
      MovementFields.amountCents: -6480,
      MovementFields.postedAt: Timestamp.fromDate(postedAt),
      MovementFields.reference: 'MOV-202610-0002',
      MovementFields.channel: 'debit_card',
      MovementFields.status: 'completed',
    };

    test('reads a movement as the server stores it', () {
      expect(
        FirestoreAccountsSource.decodeMovement('m2', document()),
        Movement(
          id: 'm2',
          accountId: 'savings',
          description: 'Supermercado',
          category: MovementCategory.groceries,
          amountCents: -6480,
          postedAt: postedAt,
          reference: 'MOV-202610-0002',
          channel: MovementChannel.debitCard,
          status: MovementStatus.completed,
        ),
      );
    });

    test('keeps a movement whose category or channel it does not know', () {
      final movement = FirestoreAccountsSource.decodeMovement(
        'm2',
        document()
          ..[MovementFields.category] = 'crypto'
          ..[MovementFields.channel] = 'smartwatch',
      );

      expect(movement?.category, MovementCategory.other);
      expect(movement?.channel, MovementChannel.other);
    });

    test(
      'does not call completed a movement whose status it does not know',
      () {
        final movement = FirestoreAccountsSource.decodeMovement(
          'm2',
          document()..[MovementFields.status] = 'reversed',
        );

        expect(movement?.status, MovementStatus.pending);
      },
    );

    test(
      'leaves out a movement without a whole amount, a date or an account',
      () {
        for (final (field, value) in [
          (MovementFields.amountCents, 64.8),
          (MovementFields.amountCents, null),
          (MovementFields.postedAt, '2026-10-03'),
          (MovementFields.accountId, null),
        ]) {
          expect(
            FirestoreAccountsSource.decodeMovement(
              'm2',
              document()..[field] = value,
            ),
            isNull,
            reason: '$field = $value',
          );
        }
      },
    );

    test('shows a movement without a description rather than hiding it', () {
      final movement = FirestoreAccountsSource.decodeMovement(
        'm2',
        document()..remove(MovementFields.description),
      );

      expect(movement?.description, isEmpty);
    });
  });
}
