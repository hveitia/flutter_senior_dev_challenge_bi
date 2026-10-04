import { describe, expect, it } from "vitest";
import {
  decideTransfer,
  MAX_TRANSFER_CENTS,
  type AccountBalance,
  type TransferOrder,
} from "./transfer";

// Balances worked by hand: savings holds $3,570.35 and checking $1,250.00.
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

function order(amountCents: number, overrides: Partial<TransferOrder> = {}): TransferOrder {
  return {
    fromAccountId: "savings",
    toAccountId: "checking",
    amountCents,
    concept: "",
    ...overrides,
  };
}

describe("decideTransfer", () => {
  it("moves the amount from one account to the other", () => {
    // 3,570.35 - 150.10 = 3,420.25 and 1,250.00 + 150.10 = 1,400.10
    expect(decideTransfer(order(15_010), savings, checking)).toEqual({
      kind: "completed",
      from: { ...savings, availableCents: 342_025, ledgerCents: 342_025 },
      to: { ...checking, availableCents: 140_010, ledgerCents: 140_010 },
    });
  });

  it("keeps the total of both accounts unchanged", () => {
    const decision = decideTransfer(order(99_999), savings, checking);

    expect(decision.kind).toBe("completed");
    if (decision.kind !== "completed") return;
    expect(decision.from.availableCents + decision.to.availableCents).toBe(
      357_035 + 125_000,
    );
  });

  it("allows emptying an account to exactly zero", () => {
    const decision = decideTransfer(
      order(125_000, { fromAccountId: "checking", toAccountId: "savings" }),
      checking,
      savings,
    );

    expect(decision).toMatchObject({
      kind: "completed",
      from: { availableCents: 0, ledgerCents: 0 },
      to: { availableCents: 482_035 },
    });
  });

  it("refuses one cent more than the available balance", () => {
    expect(
      decideTransfer(
        order(125_001, { fromAccountId: "checking", toAccountId: "savings" }),
        checking,
        savings,
      ),
    ).toEqual({ kind: "rejected", reason: "insufficient-funds" });
  });

  it("judges funds on the available balance, not the ledger one", () => {
    // $100.00 are held: the ledger says 1,250.00 but only 1,150.00 can move.
    const held = { ...checking, availableCents: 115_000 };

    expect(
      decideTransfer(
        order(120_000, { fromAccountId: "checking", toAccountId: "savings" }),
        held,
        savings,
      ),
    ).toEqual({ kind: "rejected", reason: "insufficient-funds" });
  });

  it("moves available and ledger balances by the same amount", () => {
    const held = { ...checking, availableCents: 115_000 };

    expect(
      decideTransfer(
        order(15_000, { fromAccountId: "checking", toAccountId: "savings" }),
        held,
        savings,
      ),
    ).toMatchObject({
      kind: "completed",
      from: { availableCents: 100_000, ledgerCents: 110_000 },
    });
  });

  it.each([
    ["zero", 0],
    ["a negative amount", -500],
    ["a fraction of a cent", 10.5],
    ["not a number", Number.NaN],
    ["infinity", Number.POSITIVE_INFINITY],
    ["a cent over the limit", MAX_TRANSFER_CENTS + 1],
    ["a number too large to be exact", Number.MAX_SAFE_INTEGER + 2],
  ])("refuses %s as the amount", (_name, amountCents) => {
    expect(decideTransfer(order(amountCents), savings, checking)).toEqual({
      kind: "rejected",
      reason: "invalid-amount",
    });
  });

  it("allows exactly the largest amount when the funds are there", () => {
    const rich = { ...savings, availableCents: 900_000, ledgerCents: 900_000 };

    expect(decideTransfer(order(MAX_TRANSFER_CENTS), rich, checking)).toMatchObject({
      kind: "completed",
      from: { availableCents: 400_000 },
      to: { availableCents: 625_000 },
    });
  });

  it("refuses a transfer from an account to itself", () => {
    expect(
      decideTransfer(order(1_000, { toAccountId: "savings" }), savings, savings),
    ).toEqual({ kind: "rejected", reason: "same-account" });
  });

  it("refuses when the source account does not exist", () => {
    expect(decideTransfer(order(1_000), null, checking)).toEqual({
      kind: "rejected",
      reason: "unknown-account",
    });
  });

  it("refuses when the destination account does not exist", () => {
    expect(decideTransfer(order(1_000), savings, null)).toEqual({
      kind: "rejected",
      reason: "unknown-account",
    });
  });

  it("refuses to move money between currencies", () => {
    const euros = { ...checking, currency: "EUR" };

    expect(decideTransfer(order(1_000), savings, euros)).toEqual({
      kind: "rejected",
      reason: "currency-mismatch",
    });
  });

  it("reports the amount before anything else is wrong", () => {
    expect(decideTransfer(order(0, { toAccountId: "savings" }), null, null)).toEqual({
      kind: "rejected",
      reason: "invalid-amount",
    });
  });

  it("does not change the accounts it was given", () => {
    const before = structuredClone(savings);

    decideTransfer(order(15_010), savings, checking);

    expect(savings).toEqual(before);
  });
});
