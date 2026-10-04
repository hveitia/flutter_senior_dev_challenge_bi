import type { Firestore } from "firebase-admin/firestore";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { CHECKING_OPENING_CENTS, SAVINGS_OPENING_CENTS } from "@/lib/api/provision";
import { identityProvider, logLines, post, UID } from "@/test/support/customer-api";
import { FakeFirestore } from "@/test/support/fake-firestore";

const auth = identityProvider();
let db = new FakeFirestore();

vi.mock("@/lib/server/firebase", () => ({
  adminAuth: () => auth,
  adminDb: () => db as unknown as Firestore,
}));

const { POST } = await import("./route");

const PATH = "/api/accounts/provision";

let info: ReturnType<typeof vi.spyOn>;

beforeEach(() => {
  db = new FakeFirestore();
  info = vi.spyOn(console, "info").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
});

function registerProfile(): void {
  db.documents.set(`users/${UID}`, { fullName: "Valentina Andrade", segment: "starting" });
}

describe("POST /api/accounts/provision", () => {
  it.each([
    ["no credentials", {}],
    ["a token the provider does not recognise", { authorization: "Bearer forged" }],
    ["an administrator session cookie", { cookie: "__session=administrator-cookie" }],
  ])("answers 401 to %s and opens nothing", async (_name, headers) => {
    registerProfile();

    const response = await POST(post(PATH, {}, headers));

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
    expect(db.transactions).toBe(0);
  });

  it("opens the accounts of the customer of the token", async () => {
    registerProfile();

    const response = await POST(post(PATH, {}));

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      created: true,
      accounts: [
        {
          id: "savings",
          kind: "savings",
          name: "Cuenta de ahorros",
          availableCents: SAVINGS_OPENING_CENTS,
          currency: "USD",
        },
        {
          id: "checking",
          kind: "checking",
          name: "Cuenta corriente",
          availableCents: CHECKING_OPENING_CENTS,
          currency: "USD",
        },
      ],
    });
    expect(db.documents.has(`users/${UID}/accounts/savings`)).toBe(true);
    expect(db.documents.has(`users/${UID}/movements/opening-checking`)).toBe(true);
  });

  it("answers the second call with the same accounts and creates nothing", async () => {
    registerProfile();
    const first = (await (await POST(post(PATH, {}))).json()) as { accounts: unknown };
    const written = db.writes.length;

    const response = await POST(post(PATH, {}));

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ created: false, accounts: first.accounts });
    expect(db.writes).toHaveLength(written);
  });

  it("ignores whatever the body says about who or how much", async () => {
    registerProfile();
    db.documents.set("users/uid-other", { fullName: "Otra Persona" });

    const response = await POST(
      post(PATH, { uid: "uid-other", availableCents: 99_999_999 }),
    );

    expect(response.status).toBe(200);
    expect(db.documents.has("users/uid-other/accounts/savings")).toBe(false);
    expect(db.documents.get(`users/${UID}/accounts/savings`)).toMatchObject({
      availableCents: SAVINGS_OPENING_CENTS,
    });
  });

  it("answers 422 to a customer who has not completed their profile", async () => {
    const response = await POST(post(PATH, {}));

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "profile-required" });
    expect(db.writes).toEqual([]);
  });

  it("answers 503 when the database is unreachable", async () => {
    registerProfile();
    db.runTransaction = () => Promise.reject(Object.assign(new Error("down"), { code: 14 }));

    const response = await POST(post(PATH, {}));

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "unavailable" });
  });

  it("logs whether accounts were opened, and nothing about them", async () => {
    registerProfile();
    await POST(post(PATH, {}));
    await POST(post(PATH, {}));

    const lines = logLines(info);
    expect(lines).toMatchObject([
      { route: "accounts.provision", status: 200, outcome: "created" },
      { route: "accounts.provision", status: 200, outcome: "already-provisioned" },
    ]);
    const written = JSON.stringify(
      lines.map(({ level, route, status, outcome }) => ({ level, route, status, outcome })),
    );
    expect(written).not.toContain(UID);
    expect(written).not.toContain(String(SAVINGS_OPENING_CENTS));
  });
});
