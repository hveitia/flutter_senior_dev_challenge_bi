import 'package:feature_accounts/feature_accounts.dart';

/// The moment every test treats as "now": Saturday 3 October 2026, 10:00.
final DateTime now = DateTime(2026, 10, 3, 10);

const Account savings = Account(
  id: 'savings',
  name: 'Cuenta de ahorros',
  kind: AccountKind.savings,
  number: '22004821',
  availableCents: 357035,
  ledgerCents: 357035,
  currency: 'USD',
);

const Account checking = Account(
  id: 'checking',
  name: 'Cuenta corriente',
  kind: AccountKind.checking,
  number: '22001093',
  availableCents: 125000,
  ledgerCents: 130000,
  currency: 'USD',
);

Movement movement({
  required String id,
  required String description,
  required int amountCents,
  required DateTime postedAt,
  String accountId = 'savings',
  MovementCategory category = MovementCategory.other,
  MovementChannel channel = MovementChannel.debitCard,
  MovementStatus status = MovementStatus.completed,
}) {
  return Movement(
    id: id,
    accountId: accountId,
    description: description,
    category: category,
    amountCents: amountCents,
    postedAt: postedAt,
    reference: 'MOV-$id',
    channel: channel,
    status: status,
  );
}

final Movement salary = movement(
  id: 'salary',
  description: 'Nómina de septiembre',
  amountCents: 185000,
  postedAt: DateTime(2026, 10, 3, 9, 12),
  category: MovementCategory.salary,
  channel: MovementChannel.payroll,
);

final Movement groceries = movement(
  id: 'groceries',
  description: 'Supermercado',
  amountCents: -6480,
  postedAt: DateTime(2026, 10, 3, 8, 45),
  category: MovementCategory.groceries,
);

final Movement coffee = movement(
  id: 'coffee',
  description: 'Café de la mañana',
  amountCents: -450,
  postedAt: DateTime(2026, 10, 2, 10, 28),
  category: MovementCategory.dining,
);

final Movement received = movement(
  id: 'received',
  description: 'Transferencia recibida',
  amountCents: 12000,
  postedAt: DateTime(2026, 9, 28, 16, 4),
  category: MovementCategory.transfer,
  channel: MovementChannel.transfer,
);

/// Newest first, as the backend returns them.
final List<Movement> movements = [salary, groceries, coffee, received];
