import "server-only";
import { createHash } from "node:crypto";
import {
  decideTransfer,
  TRANSFER_REJECTIONS,
  type AccountBalance,
  type TransferOrder,
  type TransferRejection,
} from "@/lib/api/transfer";
import { orderFromStored } from "@/lib/api/transfer-request";

/**
 * Carrying out a transfer. A transfer is a document the customer's app (or
 * this server, for an online request) creates as pending, under an id the app
 * chose; that id is the idempotency key. Processing settles it exactly once:
 * whatever happens afterwards with the same id returns what was recorded.
 */

export type TransferStatus = "pending" | "completed" | "rejected";

/** What the app is told about a settled transfer, first time or replayed. */
export interface TransferOutcome {
  id: string;
  status: "completed" | "rejected";
  /** ISO 8601, when the server settled it. */
  processedAt: string;
  /** Shared by the two movements of a completed transfer. */
  reference?: string;
  /** Why a rejected transfer was not carried out. */
  reason?: TransferRejection;
}

/** One line of an account's history, as the mobile app reads it. */
export interface MovementRecord {
  id: string;
  accountId: string;
  description: string;
  category: "transfer";
  amountCents: number;
  postedAt: Date;
  reference: string;
  channel: "app";
  status: "completed";
  transferId: string;
  concept: string;
}

/** Everything one settlement changes, applied together or not at all. */
export interface Settlement {
  record: {
    status: "completed" | "rejected";
    processedAt: Date;
    reference?: string;
    reason?: TransferRejection;
  };
  /**
   * The request as it is kept: the order the server read and when the request
   * was created. Nothing else of a document written by a phone survives the
   * settlement. `order` is null for a document that is not an order at all.
   */
  request: { order: TransferOrder | null; createdAt: Date };
  /** The accounts with their new balances; empty for a rejection. */
  accounts: AccountBalance[];
  movements: MovementRecord[];
}

/**
 * One atomic unit of work on a customer's transfer and accounts. Reads come
 * first; `write` records the settlement, which takes effect only if nothing
 * that was read changed in the meantime.
 */
export interface LedgerTransaction {
  /** The transfer document as stored, unchecked, or null. */
  readTransfer(): Promise<Record<string, unknown> | null>;
  readAccount(accountId: string): Promise<AccountBalance | null>;
  write(settlement: Settlement): void;
}

/**
 * Runs `run` as one transaction scoped to a customer and a transfer id. The
 * function may run more than once when another transaction got there first,
 * so it must depend only on what it reads through `transaction`.
 */
export interface TransferLedger {
  transact<T>(
    uid: string,
    transferId: string,
    run: (transaction: LedgerTransaction) => Promise<T>,
  ): Promise<T>;
}

export type ProcessResult =
  | { kind: "settled"; transfer: TransferOutcome; replayed: boolean }
  | { kind: "not-found" }
  | { kind: "key-reused" };

/**
 * A settled transfer the server cannot read back. Only this server writes
 * settlements, so this means the data was altered by hand; nothing is
 * guessed and the request fails.
 */
export class LedgerCorruptionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "LedgerCorruptionError";
  }
}

const REFERENCE_DIGEST_LENGTH = 10;

/**
 * The reference both movements of a transfer share: `TRF-202610-3FA91C07B2`.
 * Derived from the customer and the transfer id, so settling the same
 * transfer again in the same month could only ever produce the same one.
 */
export function transferReference(uid: string, transferId: string, now: Date): string {
  const month = `${now.getUTCFullYear()}${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
  const digest = createHash("sha256")
    .update(`${uid}/${transferId}`)
    .digest("hex")
    .slice(0, REFERENCE_DIGEST_LENGTH)
    .toUpperCase();
  return `TRF-${month}-${digest}`;
}

function sameOrder(one: TransferOrder | null, other: TransferOrder): boolean {
  return (
    one !== null &&
    one.fromAccountId === other.fromAccountId &&
    one.toAccountId === other.toAccountId &&
    one.amountCents === other.amountCents &&
    one.concept === other.concept
  );
}

/** What was recorded when a transfer was settled, as the app is told it. */
function recordedOutcome(id: string, stored: Record<string, unknown>): TransferOutcome {
  const { processedAt, reference, reason } = stored;
  if (!(processedAt instanceof Date)) {
    throw new LedgerCorruptionError("settled transfer without a settlement time");
  }
  if (stored.status === "completed") {
    if (typeof reference !== "string") {
      throw new LedgerCorruptionError("completed transfer without a reference");
    }
    return { id, status: "completed", processedAt: processedAt.toISOString(), reference };
  }
  return {
    id,
    status: "rejected",
    processedAt: processedAt.toISOString(),
    reason: TRANSFER_REJECTIONS.find((known) => known === reason) ?? "invalid-request",
  };
}

function movementsOf(
  transferId: string,
  order: TransferOrder,
  from: AccountBalance,
  to: AccountBalance,
  reference: string,
  now: Date,
): MovementRecord[] {
  const shared = {
    category: "transfer",
    postedAt: now,
    reference,
    channel: "app",
    status: "completed",
    transferId,
    concept: order.concept,
  } as const;
  return [
    {
      // Ids derived from the transfer: writing them twice writes the same
      // two documents, never four.
      id: `${transferId}-out`,
      accountId: from.id,
      description: `Transferencia a ${to.name}`,
      amountCents: -order.amountCents,
      ...shared,
    },
    {
      id: `${transferId}-in`,
      accountId: to.id,
      description: `Transferencia desde ${from.name}`,
      amountCents: order.amountCents,
      ...shared,
    },
  ];
}

/**
 * Settles a transfer exactly once.
 *
 * Without `submitted`, the request must already exist: it is the pending
 * document the app wrote, possibly while offline. With `submitted`, the
 * request is created if it is not there (the online path) and must match what
 * is stored if it is: the same id with a different order is refused rather
 * than answered with someone else's outcome.
 *
 * A request already settled returns what was recorded and writes nothing,
 * whatever the balances are now. Reading the request, reading both accounts
 * and writing balances, movements and the outcome happen in one transaction,
 * so two calls at the same moment cannot both find it pending.
 */
export async function processTransfer(
  ledger: TransferLedger,
  uid: string,
  transferId: string,
  now: Date,
  submitted?: TransferOrder,
): Promise<ProcessResult> {
  return ledger.transact(uid, transferId, async (transaction) => {
    const stored = await transaction.readTransfer();
    if (!stored && !submitted) return { kind: "not-found" };

    const storedOrder = stored ? orderFromStored(stored) : null;
    if (stored && submitted && !sameOrder(storedOrder, submitted)) {
      return { kind: "key-reused" };
    }
    if (stored && (stored.status === "completed" || stored.status === "rejected")) {
      return {
        kind: "settled",
        transfer: recordedOutcome(transferId, stored),
        replayed: true,
      };
    }

    const order = stored ? storedOrder : (submitted ?? null);
    // The document is rewritten from what the server read, never merged into
    // what a phone stored: a field a client added cannot outlive this.
    const createdAt = stored?.createdAt instanceof Date ? stored.createdAt : now;
    const request = { order, createdAt };
    const settle = (settlement: Omit<Settlement, "request">): ProcessResult => {
      transaction.write({ ...settlement, request });
      return {
        kind: "settled",
        // Read back from what is being recorded, the way a replay will read
        // it, so the first answer and every later one are the same bytes.
        transfer: recordedOutcome(transferId, settlement.record),
        replayed: false,
      };
    };
    const reject = (reason: TransferRejection) =>
      settle({
        record: { status: "rejected", processedAt: now, reason },
        accounts: [],
        movements: [],
      });

    // A document that is not an order, or in a state this server never
    // writes, is closed for good instead of being left to be retried forever.
    if (!order || (stored && stored.status !== "pending")) {
      return reject("invalid-request");
    }

    const [from, to] = await Promise.all([
      transaction.readAccount(order.fromAccountId),
      transaction.readAccount(order.toAccountId),
    ]);
    const decision = decideTransfer(order, from, to);
    if (decision.kind === "rejected") return reject(decision.reason);

    const reference = transferReference(uid, transferId, now);
    return settle({
      record: { status: "completed", processedAt: now, reference },
      accounts: [decision.from, decision.to],
      movements: movementsOf(transferId, order, decision.from, decision.to, reference, now),
    });
  });
}
