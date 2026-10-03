import 'package:equatable/equatable.dart';

/// What an account is for. It decides the order accounts are listed in.
enum AccountKind {
  savings('savings'),
  checking('checking')
  ;

  const AccountKind(this.id);

  /// The value stored with the account.
  final String id;

  /// The kind stored as [id], or null when this version does not know it.
  static AccountKind? fromId(Object? id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// A customer's account as the bank reports it. Amounts are integer cents:
/// money is never held in a floating point number.
final class Account extends Equatable {
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.number,
    required this.availableCents,
    required this.ledgerCents,
    required this.currency,
  });

  /// How many digits of the number are shown when it is masked.
  static const int visibleDigits = 4;
  static const String _mask = '****';

  final String id;
  final String name;
  final AccountKind kind;
  final String number;

  /// What the customer can spend right now.
  final int availableCents;

  /// The booked balance, which may include amounts still on hold.
  final int ledgerCents;
  final String currency;

  /// The number with everything but its last digits hidden: `****4821`.
  String get maskedNumber {
    final shown = number.length <= visibleDigits
        ? number
        : number.substring(number.length - visibleDigits);
    return '$_mask$shown';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    number,
    availableCents,
    ledgerCents,
    currency,
  ];
}

/// Sum of what is available across [accounts], in cents.
int totalAvailableCents(Iterable<Account> accounts) =>
    accounts.fold(0, (total, account) => total + account.availableCents);

/// [accounts] in the order they are listed: by kind, then by name.
List<Account> inListingOrder(Iterable<Account> accounts) {
  return accounts.toList()..sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    return byKind != 0 ? byKind : a.name.compareTo(b.name);
  });
}
