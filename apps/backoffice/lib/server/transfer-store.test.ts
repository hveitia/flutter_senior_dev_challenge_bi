import type { Firestore } from "firebase-admin/firestore";
import { beforeEach, describe, expect, it } from "vitest";
import { FakeFirestore, timestamp } from "@/test/support/fake-firestore";
import { firestoreTransferLedger } from "./transfer-store";
import { LedgerCorruptionError, processTransfer, transferReference } from "./transfers";

const UID = "uid-valentina";
const TRANSFER_ID = "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f";
const TRANSFER_PATH = `users/${UID}/transfers/${TRANSFER_ID}`;
const now = new Date("2026-10-03T14:00:00Z");
const createdAt = new Date("2026-10-03T13:00:00Z");

const order = {
  fromAccountId: "savings",
  toAccountId: "checking",
  amountCents: 15_010,
  concept: "Arriendo",
};

let db: FakeFirestore;

function ledger() {
  return firestoreTransferLedger(db as unknown as Firestore);
}

beforeEach(() => {
  db = new FakeFirestore();
  db.documents.set(`users/${UID}/accounts/savings`, {
    name: "Cuenta de ahorros",
    kind: "savings",
    number: "22004821",
    availableCents: 357_035,
    ledgerCents: 357_035,
    currency: "USD",
    updatedAt: timestamp(createdAt),
  });
  db.documents.set(`users/${UID}/accounts/checking`, {
    name: "Cuenta corriente",
    kind: "checking",
    number: "22001093",
    availableCents: 125_000,
    ledgerCents: 125_000,
    currency: "USD",
    updatedAt: timestamp(createdAt),
  });
});

describe("firestoreTransferLedger", () => {
  it("reads the request and both accounts under the customer, in one transaction", async () => {
    db.documents.set(TRANSFER_PATH, {
      ...order,
      status: "pending",
      createdAt: timestamp(createdAt),
    });

    await processTransfer(ledger(), UID, TRANSFER_ID, now);

    expect(db.transactions).toBe(1);
    expect(db.reads).toEqual([
      TRANSFER_PATH,
      `users/${UID}/accounts/savings`,
      `users/${UID}/accounts/checking`,
    ]);
  });

  it("writes the outcome, both balances and both movements together", async () => {
    db.documents.set(TRANSFER_PATH, {
      ...order,
      status: "pending",
      createdAt: timestamp(createdAt),
    });

    await processTransfer(ledger(), UID, TRANSFER_ID, now);

    const reference = transferReference(UID, TRANSFER_ID, now);
    expect(db.writes).toEqual([
      {
        kind: "set",
        merge: true,
        path: TRANSFER_PATH,
        data: { status: "completed", processedAt: now, reference },
      },
      {
        kind: "update",
        path: `users/${UID}/accounts/savings`,
        data: { availableCents: 342_025, ledgerCents: 342_025, updatedAt: now },
      },
      {
        kind: "update",
        path: `users/${UID}/accounts/checking`,
        data: { availableCents: 140_010, ledgerCents: 140_010, updatedAt: now },
      },
      {
        kind: "set",
        path: `users/${UID}/movements/${TRANSFER_ID}-out`,
        data: {
          accountId: "savings",
          description: "Transferencia a Cuenta corriente",
          category: "transfer",
          amountCents: -15_010,
          postedAt: now,
          reference,
          channel: "app",
          status: "completed",
          transferId: TRANSFER_ID,
          concept: "Arriendo",
        },
      },
      {
        kind: "set",
        path: `users/${UID}/movements/${TRANSFER_ID}-in`,
        data: {
          accountId: "checking",
          description: "Transferencia desde Cuenta de ahorros",
          category: "transfer",
          amountCents: 15_010,
          postedAt: now,
          reference,
          channel: "app",
          status: "completed",
          transferId: TRANSFER_ID,
          concept: "Arriendo",
        },
      },
    ]);
  });

  it("leaves the rest of an account document as it was", async () => {
    await processTransfer(ledger(), UID, TRANSFER_ID, now, order);

    expect(db.documents.get(`users/${UID}/accounts/savings`)).toMatchObject({
      name: "Cuenta de ahorros",
      kind: "savings",
      number: "22004821",
      currency: "USD",
      availableCents: 342_025,
    });
  });

  it("creates the request with its order when it did not exist", async () => {
    await processTransfer(ledger(), UID, TRANSFER_ID, now, order);

    expect(db.documents.get(TRANSFER_PATH)).toEqual({
      ...order,
      createdAt: now,
      status: "completed",
      processedAt: now,
      reference: transferReference(UID, TRANSFER_ID, now),
    });
  });

  it("writes only the outcome of a rejection", async () => {
    await processTransfer(ledger(), UID, TRANSFER_ID, now, {
      ...order,
      amountCents: 400_000,
    });

    expect(db.writes.map((write) => write.path)).toEqual([TRANSFER_PATH]);
    expect(db.documents.get(TRANSFER_PATH)).toMatchObject({
      status: "rejected",
      reason: "insufficient-funds",
    });
  });

  it("reads back a settled request whose times are database timestamps", async () => {
    db.documents.set(TRANSFER_PATH, {
      ...order,
      status: "completed",
      createdAt: timestamp(createdAt),
      processedAt: timestamp(now),
      reference: "TRF-202610-ABCDEF0123",
    });

    const result = await processTransfer(ledger(), UID, TRANSFER_ID, new Date());

    expect(result).toEqual({
      kind: "settled",
      replayed: true,
      transfer: {
        id: TRANSFER_ID,
        status: "completed",
        processedAt: "2026-10-03T14:00:00.000Z",
        reference: "TRF-202610-ABCDEF0123",
      },
    });
    expect(db.writes).toEqual([]);
  });

  it("reads an account without a ledger balance or a currency as the app does", async () => {
    db.documents.set(`users/${UID}/accounts/checking`, {
      name: "Cuenta corriente",
      kind: "checking",
      availableCents: 125_000,
    });

    await processTransfer(ledger(), UID, TRANSFER_ID, now, order);

    expect(db.documents.get(`users/${UID}/accounts/checking`)).toMatchObject({
      availableCents: 140_010,
      ledgerCents: 140_010,
    });
  });

  it.each([
    ["a balance with a fraction of a cent", { availableCents: 1250.5 }],
    ["a balance stored as text", { availableCents: "125000" }],
    ["a ledger balance that is not a whole number", { ledgerCents: 0.1 }],
    ["no name", { name: undefined }],
  ])("refuses to move money through an account with %s", async (_name, change) => {
    db.documents.set(`users/${UID}/accounts/checking`, {
      name: "Cuenta corriente",
      availableCents: 125_000,
      ledgerCents: 125_000,
      currency: "USD",
      ...change,
    });

    await expect(processTransfer(ledger(), UID, TRANSFER_ID, now, order)).rejects.toThrow(
      LedgerCorruptionError,
    );
    expect(db.writes).toEqual([]);
  });

  it("never reads or writes outside the customer of the request", async () => {
    await processTransfer(ledger(), UID, TRANSFER_ID, now, order);

    const touched = [...db.reads, ...db.writes.map((write) => write.path)];
    expect(touched.every((path) => path.startsWith(`users/${UID}/`))).toBe(true);
  });
});
