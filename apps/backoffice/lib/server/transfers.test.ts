import { beforeEach, describe, expect, it } from "vitest";
import type { AccountBalance, TransferOrder } from "@/lib/api/transfer";
import { MemoryLedger } from "@/test/support/memory-ledger";
import { processTransfer, transferReference } from "./transfers";

const UID = "uid-valentina";
const TRANSFER_ID = "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f";
const now = new Date("2026-10-03T14:00:00Z");
const later = new Date("2026-10-03T14:05:00Z");

const savings: AccountBalance = {
  id: "savings",
  name: "Cuenta de ahorros",
  availableCents: 357_035,
  ledgerCents: 357_035,
  currency: "USD",
};
const checking: AccountBalance = {
  id: "checking",
  name: "Cuenta corriente",
  availableCents: 125_000,
  ledgerCents: 125_000,
  currency: "USD",
};

const order: TransferOrder = {
  fromAccountId: "savings",
  toAccountId: "checking",
  amountCents: 15_010,
  concept: "Arriendo",
};

function pending(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    ...order,
    status: "pending",
    createdAt: new Date("2026-10-03T13:00:00Z"),
    ...overrides,
  };
}

let ledger: MemoryLedger;

beforeEach(() => {
  ledger = new MemoryLedger();
  ledger.putAccount(UID, savings);
  ledger.putAccount(UID, checking);
});

function balances(): [number | undefined, number | undefined] {
  return [
    ledger.account(UID, "savings")?.availableCents,
    ledger.account(UID, "checking")?.availableCents,
  ];
}

describe("transferReference", () => {
  it("is the same for the same customer, transfer and month", () => {
    expect(transferReference(UID, TRANSFER_ID, now)).toBe(
      transferReference(UID, TRANSFER_ID, later),
    );
  });

  it("carries the month it was settled and ten characters that tell it apart", () => {
    expect(transferReference(UID, TRANSFER_ID, now)).toMatch(/^TRF-202610-[0-9A-F]{10}$/);
  });

  it("differs between transfers and between customers", () => {
    const reference = transferReference(UID, TRANSFER_ID, now);

    expect(transferReference(UID, `${TRANSFER_ID}x`, now)).not.toBe(reference);
    expect(transferReference("uid-other", TRANSFER_ID, now)).not.toBe(reference);
  });
});

describe("processTransfer, a request the app left pending", () => {
  it("moves the money and settles the request as completed", async () => {
    ledger.putTransfer(UID, TRANSFER_ID, pending());

    const result = await processTransfer(ledger, UID, TRANSFER_ID, now);

    expect(result).toEqual({
      kind: "settled",
      replayed: false,
      transfer: {
        id: TRANSFER_ID,
        status: "completed",
        processedAt: "2026-10-03T14:00:00.000Z",
        reference: transferReference(UID, TRANSFER_ID, now),
      },
    });
    // 3,570.35 - 150.10 and 1,250.00 + 150.10
    expect(ledger.account(UID, "savings")).toMatchObject({
      availableCents: 342_025,
      ledgerCents: 342_025,
    });
    expect(ledger.account(UID, "checking")).toMatchObject({
      availableCents: 140_010,
      ledgerCents: 140_010,
    });
    expect(ledger.transfer(UID, TRANSFER_ID)).toMatchObject({
      status: "completed",
      processedAt: now,
      reference: transferReference(UID, TRANSFER_ID, now),
      amountCents: 15_010,
    });
  });

  it("writes one movement on each account, with opposite signs and one reference", async () => {
    ledger.putTransfer(UID, TRANSFER_ID, pending());

    await processTransfer(ledger, UID, TRANSFER_ID, now);

    const reference = transferReference(UID, TRANSFER_ID, now);
    expect(ledger.movementsOf(UID)).toEqual([
      {
        id: `${TRANSFER_ID}-out`,
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
      {
        id: `${TRANSFER_ID}-in`,
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
    ]);
  });

  it.each([
    ["more than the available balance", { amountCents: 400_000 }, "insufficient-funds"],
    ["an account the customer does not have", { toAccountId: "vacation" }, "unknown-account"],
    ["the same account on both sides", { toAccountId: "savings" }, "same-account"],
    ["a negative amount", { amountCents: -100 }, "invalid-amount"],
    ["a fraction of a cent", { amountCents: 10.5 }, "invalid-amount"],
    ["an amount stored as text", { amountCents: "15010" }, "invalid-request"],
    ["a status the server never writes", { status: "approved" }, "invalid-request"],
  ])("rejects %s and leaves the balances alone", async (_name, change, reason) => {
    ledger.putTransfer(UID, TRANSFER_ID, pending(change));

    const result = await processTransfer(ledger, UID, TRANSFER_ID, now);

    expect(result).toEqual({
      kind: "settled",
      replayed: false,
      transfer: {
        id: TRANSFER_ID,
        status: "rejected",
        processedAt: "2026-10-03T14:00:00.000Z",
        reason,
      },
    });
    expect(balances()).toEqual([357_035, 125_000]);
    expect(ledger.movementsOf(UID)).toEqual([]);
    expect(ledger.transfer(UID, TRANSFER_ID)).toMatchObject({
      status: "rejected",
      reason,
      processedAt: now,
    });
  });

  it("rejects a transfer between accounts in different currencies", async () => {
    ledger.putAccount(UID, { ...checking, currency: "EUR" });
    ledger.putTransfer(UID, TRANSFER_ID, pending());

    const result = await processTransfer(ledger, UID, TRANSFER_ID, now);

    expect(result).toMatchObject({
      kind: "settled",
      transfer: { status: "rejected", reason: "currency-mismatch" },
    });
    expect(balances()).toEqual([357_035, 125_000]);
  });

  it("does not find a request that was never created", async () => {
    expect(await processTransfer(ledger, UID, TRANSFER_ID, now)).toEqual({
      kind: "not-found",
    });
    expect(ledger.commits).toBe(0);
  });

  it("does not see another customer's request or accounts", async () => {
    ledger.putTransfer("uid-other", TRANSFER_ID, pending());

    expect(await processTransfer(ledger, UID, TRANSFER_ID, now)).toEqual({
      kind: "not-found",
    });
    expect(ledger.transfer("uid-other", TRANSFER_ID)).toMatchObject({ status: "pending" });
  });

  it("treats a customer without those accounts as unknown accounts", async () => {
    ledger.putTransfer("uid-other", TRANSFER_ID, pending());

    const result = await processTransfer(ledger, "uid-other", TRANSFER_ID, now);

    expect(result).toMatchObject({
      kind: "settled",
      transfer: { status: "rejected", reason: "unknown-account" },
    });
    expect(balances()).toEqual([357_035, 125_000]);
  });
});

describe("processTransfer, the same request again", () => {
  it("returns the recorded outcome of a completed transfer and moves nothing", async () => {
    ledger.putTransfer(UID, TRANSFER_ID, pending());
    const first = await processTransfer(ledger, UID, TRANSFER_ID, now);

    const second = await processTransfer(ledger, UID, TRANSFER_ID, later);

    expect(second).toEqual({ ...first, replayed: true });
    expect(balances()).toEqual([342_025, 140_010]);
    expect(ledger.movementsOf(UID)).toHaveLength(2);
    expect(ledger.commits).toBe(1);
  });

  it("returns the recorded reason of a rejected transfer, even if funds arrived since", async () => {
    ledger.putTransfer(UID, TRANSFER_ID, pending({ amountCents: 400_000 }));
    const first = await processTransfer(ledger, UID, TRANSFER_ID, now);
    ledger.putAccount(UID, { ...savings, availableCents: 900_000, ledgerCents: 900_000 });

    const second = await processTransfer(ledger, UID, TRANSFER_ID, later);

    expect(second).toEqual({ ...first, replayed: true });
    expect(second).toMatchObject({
      transfer: { status: "rejected", reason: "insufficient-funds" },
    });
    expect(ledger.account(UID, "savings")?.availableCents).toBe(900_000);
    expect(ledger.commits).toBe(1);
  });

  it("debits once when the same request is processed twice at the same moment", async () => {
    ledger.putTransfer(UID, TRANSFER_ID, pending());
    // Both units of work read the pending request before either commits.
    let reading = 0;
    let release: () => void = () => {};
    const bothHaveRead = new Promise<void>((resolve) => {
      release = resolve;
    });
    ledger.beforeCommit = async () => {
      reading += 1;
      if (reading === 2) release();
      if (reading <= 2) await bothHaveRead;
    };

    const [one, two] = await Promise.all([
      processTransfer(ledger, UID, TRANSFER_ID, now),
      processTransfer(ledger, UID, TRANSFER_ID, now),
    ]);

    expect(balances()).toEqual([342_025, 140_010]);
    expect(ledger.movementsOf(UID)).toHaveLength(2);
    expect(ledger.commits).toBe(1);
    // The loser was run again against the settled request.
    expect(ledger.attempts).toBe(3);
    expect([one, two].map((result) => result.kind)).toEqual(["settled", "settled"]);
    expect(
      [one, two].map((result) => (result.kind === "settled" ? result.replayed : null)).sort(),
    ).toEqual([false, true]);
    expect(one.kind === "settled" && two.kind === "settled" && one.transfer).toEqual(
      two.kind === "settled" && two.transfer,
    );
  });

  it("debits each of two different requests that race for the same account", async () => {
    const other = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d";
    ledger.putTransfer(UID, TRANSFER_ID, pending({ amountCents: 300_000 }));
    ledger.putTransfer(UID, other, pending({ amountCents: 100_000 }));
    let reading = 0;
    let release: () => void = () => {};
    const bothHaveRead = new Promise<void>((resolve) => {
      release = resolve;
    });
    ledger.beforeCommit = async () => {
      reading += 1;
      if (reading === 2) release();
      if (reading <= 2) await bothHaveRead;
    };

    const results = await Promise.all([
      processTransfer(ledger, UID, TRANSFER_ID, now),
      processTransfer(ledger, UID, other, now),
    ]);

    // 3,570.35 cannot cover 3,000.00 and 1,000.00: exactly one goes through,
    // and the one redone was decided against the balance the other left.
    const statuses = results.map((result) =>
      result.kind === "settled" ? result.transfer.status : result.kind,
    );
    expect(statuses.sort()).toEqual(["completed", "rejected"]);
    const [savingsCents, checkingCents] = balances();
    expect((savingsCents ?? 0) + (checkingCents ?? 0)).toBe(357_035 + 125_000);
    expect(savingsCents).toBeGreaterThanOrEqual(0);
  });
});

describe("processTransfer, an order sent while online", () => {
  it("creates the request and settles it in the same unit of work", async () => {
    const result = await processTransfer(ledger, UID, TRANSFER_ID, now, order);

    expect(result).toMatchObject({
      kind: "settled",
      replayed: false,
      transfer: { id: TRANSFER_ID, status: "completed" },
    });
    expect(ledger.commits).toBe(1);
    expect(ledger.transfer(UID, TRANSFER_ID)).toEqual({
      ...order,
      createdAt: now,
      status: "completed",
      processedAt: now,
      reference: transferReference(UID, TRANSFER_ID, now),
    });
    expect(balances()).toEqual([342_025, 140_010]);
  });

  it("records a rejection too, so the same id cannot be tried again with other funds", async () => {
    const result = await processTransfer(ledger, UID, TRANSFER_ID, now, {
      ...order,
      amountCents: 400_000,
    });

    expect(result).toMatchObject({
      kind: "settled",
      transfer: { status: "rejected", reason: "insufficient-funds" },
    });
    expect(ledger.transfer(UID, TRANSFER_ID)).toMatchObject({
      status: "rejected",
      amountCents: 400_000,
      createdAt: now,
    });
  });

  it("returns the recorded outcome when the same order is sent again", async () => {
    const first = await processTransfer(ledger, UID, TRANSFER_ID, now, order);

    const second = await processTransfer(ledger, UID, TRANSFER_ID, later, order);

    expect(second).toEqual({ ...first, replayed: true });
    expect(balances()).toEqual([342_025, 140_010]);
    expect(ledger.commits).toBe(1);
  });

  it.each([
    ["another amount", { amountCents: 20_000 }],
    ["another destination", { toAccountId: "vacation" }],
    ["another source", { fromAccountId: "checking", toAccountId: "savings" }],
    ["another concept", { concept: "Otro" }],
  ])("refuses the same id with %s", async (_name, change) => {
    await processTransfer(ledger, UID, TRANSFER_ID, now, order);

    const result = await processTransfer(ledger, UID, TRANSFER_ID, later, {
      ...order,
      ...change,
    });

    expect(result).toEqual({ kind: "key-reused" });
    expect(balances()).toEqual([342_025, 140_010]);
    expect(ledger.commits).toBe(1);
  });

  it("settles a request the app had already left pending with the same order", async () => {
    ledger.putTransfer(UID, TRANSFER_ID, pending());

    const result = await processTransfer(ledger, UID, TRANSFER_ID, now, order);

    expect(result).toMatchObject({
      kind: "settled",
      replayed: false,
      transfer: { status: "completed" },
    });
    expect(ledger.transfer(UID, TRANSFER_ID)).toMatchObject({
      createdAt: new Date("2026-10-03T13:00:00Z"),
    });
  });

  it("leaves a pending request untouched when the order sent does not match it", async () => {
    ledger.putTransfer(UID, TRANSFER_ID, pending());

    const result = await processTransfer(ledger, UID, TRANSFER_ID, now, {
      ...order,
      amountCents: 1,
    });

    expect(result).toEqual({ kind: "key-reused" });
    expect(ledger.transfer(UID, TRANSFER_ID)).toMatchObject({ status: "pending" });
    expect(balances()).toEqual([357_035, 125_000]);
  });
});
