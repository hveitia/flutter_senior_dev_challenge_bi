import "server-only";
import type { Firestore } from "firebase-admin/firestore";
import { isWholeCents, type AccountBalance } from "@/lib/api/transfer";
import { LedgerCorruptionError, type TransferLedger } from "./transfers";

/** Where a customer's data lives: `users/{uid}/...`. */
export const USERS_COLLECTION = "users";
export const ACCOUNTS_SUBCOLLECTION = "accounts";
export const MOVEMENTS_SUBCOLLECTION = "movements";
/** One document per transfer, under the id the app chose. */
export const TRANSFERS_SUBCOLLECTION = "transfers";

/** The currency the app assumes for an account that does not state one. */
export const DEFAULT_CURRENCY = "USD";

/** Stored times come back as the client's timestamp type; the rest is plain. */
function withDates(data: FirebaseFirestore.DocumentData): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(data).map(([field, value]) => [
      field,
      typeof (value as { toDate?: unknown } | null)?.toDate === "function"
        ? (value as { toDate(): Date }).toDate()
        : value,
    ]),
  );
}

/**
 * An account as the transfer decision needs it. The mobile app skips an
 * account it cannot read and says so; the server cannot skip one it is about
 * to debit, so a balance that is not whole cents stops the transfer.
 */
export function accountBalanceFrom(
  id: string,
  data: FirebaseFirestore.DocumentData,
): AccountBalance {
  const { name, kind, availableCents, ledgerCents, currency } = data;
  if (typeof name !== "string" || !isWholeCents(availableCents)) {
    throw new LedgerCorruptionError("account without a name or a whole-cent balance");
  }
  if (ledgerCents !== undefined && !isWholeCents(ledgerCents)) {
    throw new LedgerCorruptionError("account with a ledger balance that is not whole cents");
  }
  return {
    id,
    name,
    // Unknown rather than assumed: the decision refuses a kind it does not list.
    kind: typeof kind === "string" ? kind : "",
    availableCents,
    // Same fallbacks as the app's reader, so both see the same account.
    ledgerCents: ledgerCents ?? availableCents,
    currency: typeof currency === "string" ? currency : DEFAULT_CURRENCY,
  };
}

/**
 * The ledger on the database. Every path is built from the customer id the
 * caller verified, so one customer's transaction cannot reach another's
 * documents. The database runs the function again if a document it read was
 * changed by another transaction before this one committed.
 */
export function firestoreTransferLedger(db: Firestore): TransferLedger {
  return {
    transact(uid, transferId, run) {
      const customer = db.collection(USERS_COLLECTION).doc(uid);
      const transfer = customer.collection(TRANSFERS_SUBCOLLECTION).doc(transferId);
      const accounts = customer.collection(ACCOUNTS_SUBCOLLECTION);
      const movements = customer.collection(MOVEMENTS_SUBCOLLECTION);

      return db.runTransaction((transaction) =>
        run({
          async readTransfer() {
            const data = (await transaction.get(transfer)).data();
            return data ? withDates(data) : null;
          },
          async readAccount(accountId) {
            const data = (await transaction.get(accounts.doc(accountId))).data();
            return data ? accountBalanceFrom(accountId, data) : null;
          },
          write({ record, newRequest, accounts: balances, movements: lines }) {
            const request = newRequest
              ? { ...newRequest.order, createdAt: newRequest.createdAt }
              : {};
            // Merged: a request written by the app keeps its own fields.
            transaction.set(transfer, { ...request, ...record }, { merge: true });

            for (const balance of balances) {
              // Only the balances: the rest of the account is not this write's.
              transaction.update(accounts.doc(balance.id), {
                availableCents: balance.availableCents,
                ledgerCents: balance.ledgerCents,
                updatedAt: record.processedAt,
              });
            }
            for (const { id, ...line } of lines) {
              transaction.set(movements.doc(id), line);
            }
          },
        }),
      );
    },
  };
}
