/**
 * A transfer between two accounts of the same customer, decided as a pure
 * function: given the order and the two accounts as they stand, either the
 * new balances or the reason it cannot happen. Amounts are whole cents.
 */

/** Largest amount one transfer may move: $5,000.00. */
export const MAX_TRANSFER_CENTS = 500_000;

/** Longest note a customer may attach to a transfer. */
export const MAX_CONCEPT_LENGTH = 80;

/**
 * Why a transfer was not carried out. Stable codes: the app shows its own
 * text. The list and the type are one thing, so a reason the decision can
 * give is always one the server can read back from a settled transfer.
 */
export const TRANSFER_REJECTIONS = [
  "invalid-request",
  "invalid-amount",
  "same-account",
  "unknown-account",
  "account-not-eligible",
  "currency-mismatch",
  "insufficient-funds",
] as const;

export type TransferRejection = (typeof TRANSFER_REJECTIONS)[number];

/**
 * The kinds of account money can be moved between. An investment is not
 * spendable money: it is bought and sold, not transferred.
 */
export const TRANSFERABLE_KINDS: readonly string[] = ["savings", "checking"];

export interface TransferOrder {
  fromAccountId: string;
  toAccountId: string;
  amountCents: number;
  concept: string;
}

/** What a decision needs to know about an account. */
export interface AccountBalance {
  id: string;
  name: string;
  /** As stored; an account without a kind cannot move money. */
  kind: string;
  availableCents: number;
  ledgerCents: number;
  currency: string;
}

export type TransferDecision =
  | { kind: "completed"; from: AccountBalance; to: AccountBalance }
  | { kind: "rejected"; reason: TransferRejection };

/**
 * A whole number of cents that JavaScript represents exactly. Money never
 * travels as a fraction: 10.5 cents does not exist.
 */
export function isWholeCents(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value);
}

/** An amount a single transfer may move. */
export function isTransferAmount(value: unknown): value is number {
  return isWholeCents(value) && value > 0 && value <= MAX_TRANSFER_CENTS;
}

function rejected(reason: TransferRejection): TransferDecision {
  return { kind: "rejected", reason };
}

function canMoveMoney(account: AccountBalance): boolean {
  return TRANSFERABLE_KINDS.includes(account.kind);
}

function moved(account: AccountBalance, cents: number): AccountBalance {
  return {
    ...account,
    availableCents: account.availableCents + cents,
    ledgerCents: account.ledgerCents + cents,
  };
}

/**
 * Decides a transfer against the two accounts as they stand. `from` and `to`
 * are null when the customer has no account with that id.
 *
 * The checks run from what is wrong with the order itself to what is wrong
 * with the accounts, so the same order always gets the same first reason.
 * Funds are judged on the available balance; both balances move together.
 */
export function decideTransfer(
  order: TransferOrder,
  from: AccountBalance | null,
  to: AccountBalance | null,
): TransferDecision {
  if (!isTransferAmount(order.amountCents)) return rejected("invalid-amount");
  if (order.fromAccountId === order.toAccountId) return rejected("same-account");
  if (!from || !to) return rejected("unknown-account");
  if (!canMoveMoney(from) || !canMoveMoney(to)) {
    return rejected("account-not-eligible");
  }
  if (from.currency !== to.currency) return rejected("currency-mismatch");
  // Both balances of the source must cover the amount: neither ends below zero.
  if (Math.min(from.availableCents, from.ledgerCents) < order.amountCents) {
    return rejected("insufficient-funds");
  }

  const debited = moved(from, -order.amountCents);
  const credited = moved(to, order.amountCents);
  // A sum past what a number holds exactly would store a wrong balance.
  const exact = [debited, credited].every(
    (account) => isWholeCents(account.availableCents) && isWholeCents(account.ledgerCents),
  );
  if (!exact) return rejected("invalid-amount");

  return { kind: "completed", from: debited, to: credited };
}
