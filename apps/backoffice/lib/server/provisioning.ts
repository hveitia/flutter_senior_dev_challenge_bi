import "server-only";
import { randomInt } from "node:crypto";
import {
  ACCOUNT_CURRENCY,
  planDefaultAccounts,
  type ProvisionPlan,
} from "@/lib/api/provision";
import { isWholeCents } from "@/lib/api/transfer";

/**
 * Giving a new customer their first accounts. Registration in the app only
 * creates the profile, because a client never writes an account or a balance;
 * the app then asks this server to open the accounts.
 */

/** An account as the app is told about it. */
export interface AccountView {
  id: string;
  name: string;
  kind: string;
  number: string;
  availableCents: number;
  ledgerCents: number;
  currency: string;
}

export type ProvisionResult =
  | { kind: "provisioned"; created: boolean; accounts: AccountView[] }
  | { kind: "profile-required" };

/** One atomic unit of work on a customer's profile and accounts. */
export interface ProvisionTransaction {
  hasProfile(): Promise<boolean>;
  /** Every account document the customer has, as stored. */
  accounts(): Promise<{ id: string; data: Record<string, unknown> }[]>;
  create(plan: ProvisionPlan, now: Date): void;
}

export interface AccountsStore {
  transact<T>(
    uid: string,
    run: (transaction: ProvisionTransaction) => Promise<T>,
  ): Promise<T>;
}

const ACCOUNT_NUMBER_PREFIX = "22";
const ACCOUNT_NUMBER_RANDOM_DIGITS = 8;

/**
 * A new account number: the bank's prefix and eight random digits. Nothing
 * here checks that no other customer holds the same number; a core banking
 * system would assign them. The app identifies accounts by id, not by number.
 */
export function newAccountNumber(): string {
  const random = randomInt(0, 10 ** ACCOUNT_NUMBER_RANDOM_DIGITS);
  return ACCOUNT_NUMBER_PREFIX + String(random).padStart(ACCOUNT_NUMBER_RANDOM_DIGITS, "0");
}

/**
 * An account as stored, for the answer. Read as leniently as the app reads
 * it, and left out when it cannot be stated truthfully.
 */
function accountViewFrom(id: string, data: Record<string, unknown>): AccountView | null {
  const { name, kind, number, availableCents, ledgerCents, currency } = data;
  if (typeof name !== "string" || typeof kind !== "string") return null;
  if (typeof number !== "string" || !isWholeCents(availableCents)) return null;
  return {
    id,
    name,
    kind,
    number,
    availableCents,
    ledgerCents: isWholeCents(ledgerCents) ? ledgerCents : availableCents,
    currency: typeof currency === "string" ? currency : ACCOUNT_CURRENCY,
  };
}

/** The kinds this server opens, in the order it opens and lists them. */
const KIND_ORDER: readonly string[] = ["savings", "checking"];

/**
 * The answer lists accounts the same way whether they were just opened or
 * read back: known kinds first, in opening order, then anything else by id.
 * The database returns them by id, which would put checking before savings.
 */
function byOpeningOrder(one: AccountView, other: AccountView): number {
  const rank = (account: AccountView) => {
    const position = KIND_ORDER.indexOf(account.kind);
    return position === -1 ? KIND_ORDER.length : position;
  };
  return rank(one) - rank(other) || one.id.localeCompare(other.id);
}

/**
 * Opens the default accounts of a customer who has none. A customer who has
 * any account, whatever it holds, is left exactly as they are and gets back
 * what they have, so the app can call this after every sign-up, retry it
 * after a timeout, or call it twice at once.
 */
export async function provisionAccounts(
  store: AccountsStore,
  uid: string,
  now: Date,
  newNumber: () => string = newAccountNumber,
): Promise<ProvisionResult> {
  return store.transact(uid, async (transaction) => {
    if (!(await transaction.hasProfile())) return { kind: "profile-required" };

    const existing = await transaction.accounts();
    if (existing.length > 0) {
      return {
        kind: "provisioned",
        created: false,
        accounts: existing
          .flatMap(({ id, data }) => accountViewFrom(id, data) ?? [])
          .sort(byOpeningOrder),
      };
    }

    const plan = planDefaultAccounts(now, newNumber);
    transaction.create(plan, now);
    return { kind: "provisioned", created: true, accounts: plan.accounts };
  });
}
