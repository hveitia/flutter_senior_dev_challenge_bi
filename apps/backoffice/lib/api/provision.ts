/**
 * The accounts a new customer starts with, as a pure plan: what to create,
 * with which balances and which opening movements. Amounts are whole cents.
 *
 * Field names and the ids of kinds, categories and channels are the ones the
 * mobile app reads in
 * packages/feature_accounts/lib/src/adapters/firestore_accounts_source.dart
 * and the seed tool writes in firebase/seed/seed-data.mjs; they change
 * together.
 */

/** Welcome balance of the savings account: $50.00. */
export const SAVINGS_OPENING_CENTS = 5_000;
/** Welcome balance of the checking account: $25.00. */
export const CHECKING_OPENING_CENTS = 2_500;

export const ACCOUNT_CURRENCY = "USD";

export interface ProvisionedAccount {
  /** Fixed per kind, so creating the same account twice writes one document. */
  id: "savings" | "checking";
  name: string;
  kind: "savings" | "checking";
  number: string;
  availableCents: number;
  ledgerCents: number;
  currency: string;
}

export interface OpeningMovement {
  id: string;
  accountId: string;
  description: string;
  category: "transfer";
  amountCents: number;
  postedAt: Date;
  reference: string;
  channel: "transfer";
  status: "completed";
}

export interface ProvisionPlan {
  accounts: ProvisionedAccount[];
  movements: OpeningMovement[];
}

const DEFAULT_ACCOUNTS = [
  { id: "savings", name: "Cuenta de ahorros", openingCents: SAVINGS_OPENING_CENTS },
  { id: "checking", name: "Cuenta corriente", openingCents: CHECKING_OPENING_CENTS },
] as const;

/**
 * The two accounts every customer starts with and the deposit that opens
 * each. Every balance is explained by a movement from the first day, so the
 * history of an account always adds up to what it holds.
 */
export function planDefaultAccounts(
  now: Date,
  newAccountNumber: () => string,
): ProvisionPlan {
  const accounts: ProvisionedAccount[] = DEFAULT_ACCOUNTS.map((account) => ({
    id: account.id,
    name: account.name,
    kind: account.id,
    number: newAccountNumber(),
    availableCents: account.openingCents,
    ledgerCents: account.openingCents,
    currency: ACCOUNT_CURRENCY,
  }));

  const movements: OpeningMovement[] = accounts.map((account) => ({
    id: `opening-${account.id}`,
    accountId: account.id,
    description: "Depósito inicial",
    category: "transfer",
    amountCents: account.availableCents,
    postedAt: now,
    reference: `APE-${account.number}`,
    channel: "transfer",
    status: "completed",
  }));

  return { accounts, movements };
}
