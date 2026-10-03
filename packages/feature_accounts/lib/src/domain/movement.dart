import 'package:equatable/equatable.dart';

/// What a movement was for.
enum MovementCategory {
  salary('salary'),
  transfer('transfer'),
  groceries('groceries'),
  dining('dining'),
  transport('transport'),
  services('services'),
  entertainment('entertainment'),
  health('health'),
  cash('cash'),
  other('other')
  ;

  const MovementCategory(this.id);

  final String id;

  /// Unknown ids become [other], so a category added by the backend later
  /// does not hide the movement.
  static MovementCategory fromId(Object? id) =>
      values.firstWhere((value) => value.id == id, orElse: () => other);
}

/// How the movement was made.
enum MovementChannel {
  debitCard('debit_card'),
  transfer('transfer'),
  payroll('payroll'),
  atm('atm'),
  app('app'),
  other('other')
  ;

  const MovementChannel(this.id);

  final String id;

  static MovementChannel fromId(Object? id) =>
      values.firstWhere((value) => value.id == id, orElse: () => other);
}

enum MovementStatus {
  completed('completed'),
  pending('pending')
  ;

  const MovementStatus(this.id);

  final String id;

  /// Anything that is not known to be completed is shown as pending: saying
  /// "completed" about a movement that is not would be the worse mistake.
  static MovementStatus fromId(Object? id) =>
      id == completed.id ? completed : pending;
}

/// Money that went into or out of an account.
final class Movement extends Equatable {
  const Movement({
    required this.id,
    required this.accountId,
    required this.description,
    required this.category,
    required this.amountCents,
    required this.postedAt,
    required this.reference,
    required this.channel,
    required this.status,
  });

  final String id;
  final String accountId;
  final String description;
  final MovementCategory category;

  /// Signed integer cents: positive is income.
  final int amountCents;
  final DateTime postedAt;
  final String reference;
  final MovementChannel channel;
  final MovementStatus status;

  bool get isIncome => amountCents > 0;

  @override
  List<Object?> get props => [
    id,
    accountId,
    description,
    category,
    amountCents,
    postedAt,
    reference,
    channel,
    status,
  ];
}
