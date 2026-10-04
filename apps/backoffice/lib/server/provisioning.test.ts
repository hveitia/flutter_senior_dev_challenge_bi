import type { Firestore } from "firebase-admin/firestore";
import { beforeEach, describe, expect, it } from "vitest";
import { CHECKING_OPENING_CENTS, SAVINGS_OPENING_CENTS } from "@/lib/api/provision";
import { FakeFirestore } from "@/test/support/fake-firestore";
import { newAccountNumber, provisionAccounts } from "./provisioning";
import { firestoreAccountsStore } from "./provisioning-store";

const UID = "uid-valentina";
const now = new Date("2026-10-03T14:00:00Z");
const later = new Date("2026-10-04T09:00:00Z");

let db: FakeFirestore;

function store() {
  return firestoreAccountsStore(db as unknown as Firestore);
}

function numbers(...values: string[]): () => string {
  let next = 0;
  return () => values[next++] ?? "9999999999";
}

function registerProfile(uid = UID): void {
  db.documents.set(`users/${uid}`, { fullName: "Valentina Andrade", segment: "starting" });
}

beforeEach(() => {
  db = new FakeFirestore();
});

describe("newAccountNumber", () => {
  it("is ten digits and starts like the bank's account numbers", () => {
    for (let round = 0; round < 50; round += 1) {
      expect(newAccountNumber()).toMatch(/^22\d{8}$/);
    }
  });
});

describe("provisionAccounts", () => {
  it("opens the two default accounts for a customer who has none", async () => {
    registerProfile();

    const result = await provisionAccounts(
      store(),
      UID,
      now,
      numbers("2200000001", "2200000002"),
    );

    expect(result).toEqual({
      kind: "provisioned",
      created: true,
      accounts: [
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
      ],
    });
  });

  it("writes the accounts and their opening movements with the fields the app reads", async () => {
    registerProfile();

    await provisionAccounts(store(), UID, now, numbers("2200000001", "2200000002"));

    expect(db.writes).toEqual([
      {
        kind: "set",
        path: `users/${UID}/accounts/savings`,
        data: {
          name: "Cuenta de ahorros",
          kind: "savings",
          number: "2200000001",
          availableCents: SAVINGS_OPENING_CENTS,
          ledgerCents: SAVINGS_OPENING_CENTS,
          currency: "USD",
          updatedAt: now,
        },
      },
      {
        kind: "set",
        path: `users/${UID}/accounts/checking`,
        data: {
          name: "Cuenta corriente",
          kind: "checking",
          number: "2200000002",
          availableCents: CHECKING_OPENING_CENTS,
          ledgerCents: CHECKING_OPENING_CENTS,
          currency: "USD",
          updatedAt: now,
        },
      },
      {
        kind: "set",
        path: `users/${UID}/movements/opening-savings`,
        data: {
          accountId: "savings",
          description: "Depósito inicial",
          category: "transfer",
          amountCents: SAVINGS_OPENING_CENTS,
          postedAt: now,
          reference: "APE-2200000001",
          channel: "transfer",
          status: "completed",
        },
      },
      {
        kind: "set",
        path: `users/${UID}/movements/opening-checking`,
        data: {
          accountId: "checking",
          description: "Depósito inicial",
          category: "transfer",
          amountCents: CHECKING_OPENING_CENTS,
          postedAt: now,
          reference: "APE-2200000002",
          channel: "transfer",
          status: "completed",
        },
      },
    ]);
    expect(db.transactions).toBe(1);
  });

  it("changes nothing the second time and returns the accounts it opened", async () => {
    registerProfile();
    const first = await provisionAccounts(
      store(),
      UID,
      now,
      numbers("2200000001", "2200000002"),
    );
    const written = db.writes.length;

    const second = await provisionAccounts(
      store(),
      UID,
      later,
      numbers("2299999991", "2299999992"),
    );

    expect(second).toEqual({ ...first, created: false });
    expect(db.writes).toHaveLength(written);
  });

  it("does not ask for account numbers it will not use", async () => {
    registerProfile();
    await provisionAccounts(store(), UID, now, numbers("2200000001", "2200000002"));
    let asked = 0;

    await provisionAccounts(store(), UID, later, () => {
      asked += 1;
      return "2299999999";
    });

    expect(asked).toBe(0);
  });

  it("leaves a customer who already has accounts exactly as they are", async () => {
    registerProfile();
    db.documents.set(`users/${UID}/accounts/savings`, {
      name: "Cuenta de ahorros",
      kind: "savings",
      number: "22004821",
      availableCents: 357_035,
      ledgerCents: 357_035,
      currency: "USD",
    });

    const result = await provisionAccounts(store(), UID, now);

    expect(result).toEqual({
      kind: "provisioned",
      created: false,
      accounts: [
        {
          id: "savings",
          name: "Cuenta de ahorros",
          kind: "savings",
          number: "22004821",
          availableCents: 357_035,
          ledgerCents: 357_035,
          currency: "USD",
        },
      ],
    });
    expect(db.writes).toEqual([]);
  });

  it("does not open accounts over one it cannot read, and leaves it out of the answer", async () => {
    registerProfile();
    db.documents.set(`users/${UID}/accounts/savings`, {
      name: "Cuenta de ahorros",
      availableCents: "357035",
    });

    const result = await provisionAccounts(store(), UID, now);

    expect(result).toEqual({ kind: "provisioned", created: false, accounts: [] });
    expect(db.writes).toEqual([]);
  });

  it("refuses a customer without a profile and writes nothing", async () => {
    const result = await provisionAccounts(store(), UID, now);

    expect(result).toEqual({ kind: "profile-required" });
    expect(db.writes).toEqual([]);
  });

  it("reads and writes only under the customer it was called for", async () => {
    registerProfile();
    registerProfile("uid-other");
    db.documents.set("users/uid-other/accounts/savings", {
      name: "Cuenta de ahorros",
      kind: "savings",
      number: "22000001",
      availableCents: 1,
    });

    const result = await provisionAccounts(store(), UID, now);

    expect(result).toMatchObject({ created: true });
    const touched = [...db.reads, ...db.writes.map((write) => write.path)];
    expect(touched.every((path) => path === `users/${UID}` || path.startsWith(`users/${UID}/`))).toBe(
      true,
    );
  });
});
