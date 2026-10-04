import 'dart:math';

import 'package:app_platform/app_platform.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/domain/account.dart';

/// The limits of one transfer. They are the server's
/// (`apps/backoffice/lib/api/transfer.ts`) and the Firestore rule's; the
/// three change together. The server has the last word either way.
abstract final class TransferLimits {
  /// Largest amount one transfer may move: $5,000.00.
  static const int maxCents = 500000;

  /// Longest note a customer may attach to a transfer.
  static const int maxConceptLength = 80;
}

/// An order to move money between two accounts of the same customer.
///
/// [id] is chosen once per order and sent with every attempt: the server
/// settles an id exactly once, so repeating an order can never move the
/// money twice.
final class TransferOrder extends Equatable {
  const TransferOrder({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    this.concept = '',
  });

  final String id;
  final String fromAccountId;
  final String toAccountId;

  /// Whole cents: money is never a fraction.
  final int amountCents;
  final String concept;

  @override
  List<Object?> get props => [
    id,
    fromAccountId,
    toAccountId,
    amountCents,
    concept,
  ];
}

/// Why the server did not carry out a transfer. The codes are the server's.
enum TransferRejection {
  insufficientFunds('insufficient-funds'),
  unknownAccount('unknown-account'),
  accountNotEligible('account-not-eligible'),
  currencyMismatch('currency-mismatch'),
  sameAccount('same-account'),
  invalidAmount('invalid-amount'),
  invalidRequest('invalid-request')
  ;

  const TransferRejection(this.code);

  final String code;

  /// The rejection with [code]. A code this version does not know is still
  /// a rejection, so it reads as the most general one.
  static TransferRejection fromCode(Object? code) {
    for (final rejection in values) {
      if (rejection.code == code) return rejection;
    }
    return invalidRequest;
  }
}

/// How sending an order ended.
sealed class TransferOutcome extends Equatable {
  const TransferOutcome();

  @override
  List<Object?> get props => [];
}

/// The money moved. [reference] is shared by the two movements.
final class TransferCompleted extends TransferOutcome {
  const TransferCompleted({required this.reference});

  final String reference;

  @override
  List<Object?> get props => [reference];
}

/// The server answered that it will not carry it out. Final for that id.
final class TransferRejected extends TransferOutcome {
  const TransferRejected(this.reason);

  final TransferRejection reason;

  @override
  List<Object?> get props => [reason];
}

/// There was no connection: the order is kept on the device and is sent
/// when the connection returns.
final class TransferQueued extends TransferOutcome {
  const TransferQueued();
}

/// The server could not be asked or did not answer in time. Nothing is
/// known about the order; sending the same order again is safe.
final class TransferNotSent extends TransferOutcome {
  const TransferNotSent(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => [failure.runtimeType];
}

/// An order left on the device, waiting to be sent.
final class QueuedTransfer extends Equatable {
  const QueuedTransfer({required this.id, required this.amountCents});

  final String id;
  final int amountCents;

  @override
  List<Object?> get props => [id, amountCents];
}

/// What is wrong with an order before it is sent.
enum TransferFormError {
  missingAccounts,
  sameAccount,
  missingAmount,
  overLimit,
  insufficientFunds,
  conceptTooLong,
}

/// Checks an order against the customer's accounts as the device knows
/// them, so the obvious mistakes are caught before asking the server. Null
/// when nothing is wrong.
TransferFormError? validateTransfer({
  required Account? from,
  required Account? to,
  required int amountCents,
  required String concept,
}) {
  if (from == null || to == null) return TransferFormError.missingAccounts;
  if (from.id == to.id) return TransferFormError.sameAccount;
  if (amountCents <= 0) return TransferFormError.missingAmount;
  if (amountCents > TransferLimits.maxCents) return TransferFormError.overLimit;
  if (amountCents > from.availableCents) {
    return TransferFormError.insufficientFunds;
  }
  if (concept.trim().length > TransferLimits.maxConceptLength) {
    return TransferFormError.conceptTooLong;
  }
  return null;
}

/// The accounts money can be moved between: the ones that hold spendable
/// money, in the order given.
List<Account> transferableAccounts(Iterable<Account> accounts) =>
    cashAccounts(accounts);

/// Reads an amount typed as digits, where the last two are the cents:
/// `1501` is $15.01. Anything that is not a digit is ignored. Bounded so a
/// long paste cannot overflow.
int amountCentsFromDigits(String input) {
  final digits = input.replaceAll(RegExp('[^0-9]'), '');
  if (digits.isEmpty) return 0;
  const maxDigits = 9;
  final kept = digits.length > maxDigits
      ? digits.substring(0, maxDigits)
      : digits;
  return int.parse(kept);
}

/// Produces the id of a new order: 32 characters the server accepts as a
/// document id, random enough not to be guessed or repeated.
String newTransferId([Random? random]) {
  const alphabet = '0123456789abcdef';
  const length = 32;
  final source = random ?? Random.secure();
  return List.generate(
    length,
    (_) => alphabet[source.nextInt(alphabet.length)],
  ).join();
}
