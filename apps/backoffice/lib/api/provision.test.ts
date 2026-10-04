import { describe, expect, it } from "vitest";
import {
  CHECKING_OPENING_CENTS,
  planDefaultAccounts,
  SAVINGS_OPENING_CENTS,
} from "./provision";

const now = new Date("2026-10-03T14:00:00Z");

function numbers(...values: string[]): () => string {
  let next = 0;
  return () => values[next++] ?? "0000000000";
}

describe("planDefaultAccounts", () => {
  it("opens a savings and a checking account with their welcome balances", () => {
    const plan = planDefaultAccounts(now, numbers("2200000001", "2200000002"));

    expect(plan.accounts).toEqual([
      {
        id: "savings",
        name: "Cuenta de ahorros",
        kind: "savings",
        number: "2200000001",
        availableCents: SAVINGS_OPENING_CENTS,
        ledgerCents: SAVINGS_OPENING_CENTS,
        currency: "USD",
      },
      {
        id: "checking",
        name: "Cuenta corriente",
        kind: "checking",
        number: "2200000002",
        availableCents: CHECKING_OPENING_CENTS,
        ledgerCents: CHECKING_OPENING_CENTS,
        currency: "USD",
      },
    ]);
  });

  it("gives each account one opening movement that explains its whole balance", () => {
    const plan = planDefaultAccounts(now, numbers("2200000001", "2200000002"));

    expect(plan.movements).toEqual([
      {
        id: "opening-savings",
        accountId: "savings",
        description: "Depósito inicial",
        category: "transfer",
        amountCents: SAVINGS_OPENING_CENTS,
        postedAt: now,
        reference: "APE-2200000001",
        channel: "transfer",
        status: "completed",
      },
      {
        id: "opening-checking",
        accountId: "checking",
        description: "Depósito inicial",
        category: "transfer",
        amountCents: CHECKING_OPENING_CENTS,
        postedAt: now,
        reference: "APE-2200000002",
        channel: "transfer",
        status: "completed",
      },
    ]);
    for (const account of plan.accounts) {
      const moved = plan.movements
        .filter((movement) => movement.accountId === account.id)
        .reduce((sum, movement) => sum + movement.amountCents, 0);
      expect(moved).toBe(account.availableCents);
    }
  });

  it("opens with whole cents", () => {
    for (const account of planDefaultAccounts(now, numbers("1", "2")).accounts) {
      expect(Number.isSafeInteger(account.availableCents)).toBe(true);
      expect(account.availableCents).toBeGreaterThan(0);
    }
  });

  it("asks for a new number once per account", () => {
    let asked = 0;

    planDefaultAccounts(now, () => {
      asked += 1;
      return String(asked);
    });

    expect(asked).toBe(2);
  });
});
