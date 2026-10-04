// The demo data the seed tool writes, as a pure function of the current
// moment so it can be tested without a database.
//
// Amounts are integer cents. Field names and the ids of categories and
// channels are the ones the app reads in
// packages/feature_accounts/lib/src/adapters/firestore_accounts_source.dart;
// they change together.

const ACCOUNTS = [
  {
    id: 'savings',
    name: 'Cuenta de ahorros',
    kind: 'savings',
    number: '22004821',
    balanceCents: 357035,
  },
  {
    id: 'checking',
    name: 'Cuenta corriente',
    kind: 'checking',
    number: '22001093',
    balanceCents: 125000,
  },
];

/** How long ago the opening deposit of each account was made, in days. */
const OPENING_DAYS_AGO = 45;

// [days ago, time, description, cents, category, channel], newest first.
const MOVEMENTS = {
  savings: [
    [0, '09:12', 'Nómina de septiembre', 185000, 'salary', 'payroll'],
    [0, '08:45', 'Supermercado', -6480, 'groceries', 'debit_card'],
    [1, '10:28', 'Café de la mañana', -450, 'dining', 'debit_card'],
    [5, '16:04', 'Transferencia recibida', 12000, 'transfer', 'transfer'],
    [6, '18:20', 'Farmacia', -2315, 'health', 'debit_card'],
    [8, '07:30', 'Servicio de internet', -3500, 'services', 'app'],
    [9, '20:15', 'Restaurante', -2840, 'dining', 'debit_card'],
    [10, '08:05', 'Transporte', -625, 'transport', 'debit_card'],
    [12, '19:40', 'Cine', -1400, 'entertainment', 'debit_card'],
    [13, '11:10', 'Supermercado', -8235, 'groceries', 'debit_card'],
    [15, '13:25', 'Retiro en cajero', -10000, 'cash', 'atm'],
    [17, '09:00', 'Planilla de luz', -4270, 'services', 'app'],
    [19, '17:45', 'Gasolina', -3000, 'transport', 'debit_card'],
    [21, '12:30', 'Transferencia enviada', -15000, 'transfer', 'app'],
    [23, '06:00', 'Suscripción de música', -599, 'entertainment', 'debit_card'],
    [26, '15:10', 'Consulta médica', -4500, 'health', 'debit_card'],
    [31, '09:10', 'Nómina de agosto', 185000, 'salary', 'payroll'],
    [33, '12:20', 'Supermercado', -7150, 'groceries', 'debit_card'],
    [36, '09:05', 'Planilla de agua', -1860, 'services', 'app'],
  ],
  checking: [
    [2, '10:00', 'Pago de tarjeta de crédito', -18000, 'services', 'app'],
    [4, '14:35', 'Transferencia desde ahorros', 30000, 'transfer', 'transfer'],
    [7, '08:00', 'Arriendo', -45000, 'services', 'transfer'],
    [11, '18:55', 'Supermercado', -5320, 'groceries', 'debit_card'],
    [14, '09:30', 'Seguro del auto', -6200, 'services', 'app'],
    [18, '11:15', 'Transferencia recibida', 25000, 'transfer', 'transfer'],
    [20, '21:05', 'Restaurante', -3180, 'dining', 'debit_card'],
    [24, '12:40', 'Retiro en cajero', -6000, 'cash', 'atm'],
    [28, '10:10', 'Colegiatura', -22000, 'services', 'transfer'],
    [32, '16:20', 'Honorarios', 120000, 'salary', 'transfer'],
  ],
};

/**
 * The moment `daysAgo` days before `now` at the given `HH:MM`. When that
 * would be later than `now` (a "today" movement seeded early in the
 * morning) it moves one day back: nothing is ever dated in the future.
 */
function momentBefore(now, daysAgo, time) {
  const [hours, minutes] = time.split(':').map(Number);
  const moment = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate() - daysAgo,
    hours,
    minutes,
  );
  if (moment > now) moment.setDate(moment.getDate() - 1);
  return moment;
}

function twoDigits(value) {
  return String(value).padStart(2, '0');
}

/** `MOV-202610-0002`: the month it was posted and a running number. */
function reference(postedAt, number) {
  const month = `${postedAt.getFullYear()}${twoDigits(postedAt.getMonth() + 1)}`;
  return `MOV-${month}-${String(number).padStart(4, '0')}`;
}

/**
 * Two accounts and their movements, with dates relative to `now`.
 *
 * Each account opens with a deposit sized so that its movements add up
 * exactly to its balance. Ids depend only on the position of each movement,
 * so running the seed again rewrites the same documents.
 */
export function buildSeed(now) {
  const accounts = ACCOUNTS.map((account) => ({
    id: account.id,
    data: {
      name: account.name,
      kind: account.kind,
      number: account.number,
      availableCents: account.balanceCents,
      ledgerCents: account.balanceCents,
      currency: 'USD',
      updatedAt: now,
    },
  }));

  const movements = [];
  let running = 0;

  for (const account of ACCOUNTS) {
    const rows = MOVEMENTS[account.id];
    const moved = rows.reduce((sum, row) => sum + row[3], 0);
    const withOpening = [
      ...rows,
      [
        OPENING_DAYS_AGO,
        '10:00',
        'Depósito inicial',
        account.balanceCents - moved,
        'transfer',
        'transfer',
      ],
    ];

    withOpening.forEach((row, index) => {
      const [daysAgo, time, description, amountCents, category, channel] = row;
      const postedAt = momentBefore(now, daysAgo, time);
      running += 1;

      movements.push({
        id: `seed-${account.id}-${twoDigits(index + 1)}`,
        data: {
          accountId: account.id,
          description,
          category,
          amountCents,
          postedAt,
          reference: reference(postedAt, running),
          channel,
          status: 'completed',
        },
      });
    });
  }

  return { accounts, movements };
}
