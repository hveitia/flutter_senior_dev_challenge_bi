import { beforeEach, describe, expect, it, vi } from "vitest";
import { MAX_BODY_BYTES } from "@/lib/server/api-http";
import { transferReference } from "@/lib/server/transfers";
import {
  checking,
  identityProvider,
  logLines,
  order,
  post,
  savings,
  TOKEN,
  TRANSFER_ID,
  UID,
} from "@/test/support/customer-api";
import { MemoryLedger } from "@/test/support/memory-ledger";

const auth = identityProvider();
let ledger = new MemoryLedger();

vi.mock("@/lib/server/firebase", () => ({
  adminAuth: () => auth,
  adminDb: () => ({}),
}));
vi.mock("@/lib/server/transfer-store", () => ({
  firestoreTransferLedger: () => ledger,
}));

const { POST } = await import("./route");

const PATH = "/api/transfers";
const body = { transferId: TRANSFER_ID, ...order };

let info: ReturnType<typeof vi.spyOn>;
let error: ReturnType<typeof vi.spyOn>;

beforeEach(() => {
  auth.verifyIdToken.mockClear();
  ledger = new MemoryLedger();
  ledger.putAccount(UID, savings);
  ledger.putAccount(UID, checking);
  info = vi.spyOn(console, "info").mockImplementation(() => {});
  error = vi.spyOn(console, "error").mockImplementation(() => {});
});

function balances() {
  return [
    ledger.account(UID, "savings")?.availableCents,
    ledger.account(UID, "checking")?.availableCents,
  ];
}

describe("POST /api/transfers, who may call it", () => {
  it.each([
    ["no credentials", {}],
    ["a token the provider does not recognise", { authorization: "Bearer forged" }],
    ["an administrator session cookie", { cookie: "__session=administrator-cookie" }],
  ])("answers 401 to %s and touches nothing", async (_name, headers) => {
    const response = await POST(post(PATH, body, headers));

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
    expect(ledger.attempts).toBe(0);
  });

  it("answers 401 before looking at the body", async () => {
    const response = await POST(post(PATH, "not json at all", {}));

    expect(response.status).toBe(401);
  });

  it("acts for the customer of the token and for nobody a body names", async () => {
    ledger.putAccount("uid-other", savings);
    ledger.putAccount("uid-other", checking);

    const response = await POST(post(PATH, { ...body, uid: "uid-other" }));

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid-request", fields: ["uid"] });
    expect(ledger.account("uid-other", "savings")?.availableCents).toBe(357_035);
    expect(ledger.attempts).toBe(0);
  });
});

describe("POST /api/transfers, what it accepts", () => {
  it("answers 415 to a body that is not declared as JSON", async () => {
    const response = await POST(
      post(PATH, body, { authorization: `Bearer ${TOKEN}`, "content-type": "text/plain" }),
    );

    expect(response.status).toBe(415);
    expect(await response.json()).toEqual({ error: "unsupported-media-type" });
  });

  it("answers 400 to a body that is not a JSON object", async () => {
    const response = await POST(post(PATH, "[1, 2, 3]"));

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid-json" });
  });

  it("answers 413 to a body over the size limit", async () => {
    const response = await POST(
      post(PATH, { ...body, concept: "a".repeat(MAX_BODY_BYTES) }),
    );

    expect(response.status).toBe(413);
    expect(await response.json()).toEqual({ error: "payload-too-large" });
    expect(ledger.attempts).toBe(0);
  });

  it("names the wrong fields and moves nothing", async () => {
    const response = await POST(
      post(PATH, { ...body, amountCents: 150.1, toAccountId: "savings" }),
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({
      error: "invalid-request",
      fields: ["toAccountId", "amountCents"],
    });
    expect(ledger.attempts).toBe(0);
  });
});

describe("POST /api/transfers, settling", () => {
  it("moves the money and answers with the settled transfer", async () => {
    const response = await POST(post(PATH, body));

    expect(response.status).toBe(200);
    const answer = (await response.json()) as { transfer: { processedAt: string } };
    expect(answer).toEqual({
      transfer: {
        id: TRANSFER_ID,
        status: "completed",
        processedAt: answer.transfer.processedAt,
        reference: transferReference(UID, TRANSFER_ID, new Date(answer.transfer.processedAt)),
      },
    });
    expect(balances()).toEqual([342_025, 140_010]);
  });

  it("names the request in the answer and forbids caching it", async () => {
    const response = await POST(post(PATH, body));

    expect(response.headers.get("x-request-id")).toMatch(/^[0-9a-f-]{36}$/);
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it.each([
    ["more than the balance", { amountCents: 400_000 }, "insufficient-funds"],
    ["an account the customer does not have", { toAccountId: "vacation" }, "unknown-account"],
  ])("answers 422 with the reason for %s", async (_name, change, reason) => {
    const response = await POST(post(PATH, { ...body, ...change }));

    expect(response.status).toBe(422);
    const answer = (await response.json()) as { transfer: { processedAt: string } };
    expect(answer).toEqual({
      error: "transfer-rejected",
      reason,
      transfer: {
        id: TRANSFER_ID,
        status: "rejected",
        processedAt: answer.transfer.processedAt,
        reason,
      },
    });
    expect(balances()).toEqual([357_035, 125_000]);
  });

  it("answers 422 for accounts in different currencies", async () => {
    ledger.putAccount(UID, { ...checking, currency: "EUR" });

    const response = await POST(post(PATH, body));

    expect(response.status).toBe(422);
    expect(await response.json()).toMatchObject({ reason: "currency-mismatch" });
  });

  it("answers the same order sent again exactly as the first time, and debits once", async () => {
    const first = await POST(post(PATH, body));
    const second = await POST(post(PATH, body));

    expect(second.status).toBe(200);
    expect(await second.json()).toEqual(await first.json());
    expect(balances()).toEqual([342_025, 140_010]);
    expect(ledger.commits).toBe(1);
  });

  it("answers a rejected order sent again with the same rejection", async () => {
    const rejected = { ...body, amountCents: 400_000 };
    const first = await POST(post(PATH, rejected));
    ledger.putAccount(UID, { ...savings, availableCents: 900_000, ledgerCents: 900_000 });

    const second = await POST(post(PATH, rejected));

    expect(second.status).toBe(422);
    expect(await second.json()).toEqual(await first.json());
    expect(ledger.account(UID, "savings")?.availableCents).toBe(900_000);
  });

  it("answers 409 when the same id arrives with a different order", async () => {
    await POST(post(PATH, body));

    const response = await POST(post(PATH, { ...body, amountCents: 99 }));

    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({ error: "idempotency-key-reused" });
    expect(balances()).toEqual([342_025, 140_010]);
  });

  it("debits once when the same order arrives twice at the same moment", async () => {
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

    const [one, two] = await Promise.all([POST(post(PATH, body)), POST(post(PATH, body))]);

    expect([one.status, two.status]).toEqual([200, 200]);
    expect(await one.json()).toEqual(await two.json());
    expect(balances()).toEqual([342_025, 140_010]);
    expect(ledger.movementsOf(UID)).toHaveLength(2);
  });
});

describe("POST /api/transfers, when something breaks", () => {
  it("answers 503 when the database is unreachable, so the app can send it again", async () => {
    ledger.transact = () => Promise.reject(Object.assign(new Error("unavailable"), { code: 14 }));

    const response = await POST(post(PATH, body));

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "unavailable" });
  });

  it("answers 500 with a generic code and says nothing about the cause", async () => {
    ledger.transact = () =>
      Promise.reject(new Error(`users/${UID}/accounts/savings holds 357035`));

    const response = await POST(post(PATH, body));

    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({ error: "internal" });
  });
});

describe("POST /api/transfers, what it logs", () => {
  it("leaves one line with the route, status and outcome", async () => {
    await POST(post(PATH, body));

    const [line] = logLines(info);
    expect(Object.keys(line ?? {}).sort()).toEqual([
      "durationMs",
      "level",
      "outcome",
      "requestId",
      "route",
      "status",
    ]);
    expect(line).toMatchObject({
      level: "info",
      route: "transfers.create",
      status: 200,
      outcome: "completed",
    });
  });

  it("marks a replay and a rejection in the outcome", async () => {
    await POST(post(PATH, body));
    await POST(post(PATH, body));
    await POST(post(PATH, { ...body, transferId: `${TRANSFER_ID}-2`, amountCents: 400_000 }));

    expect(logLines(info).map((line) => line.outcome)).toEqual([
      "completed",
      "replayed:completed",
      "rejected:insufficient-funds",
    ]);
  });

  it("never writes the customer, an account, an amount or an error message", async () => {
    await POST(post(PATH, body));
    await POST(post(PATH, { ...body, amountCents: 99 }));
    ledger.transact = () =>
      Promise.reject(new Error(`users/${UID}/accounts/savings holds 357035`));
    await POST(post(PATH, { ...body, transferId: `${TRANSFER_ID}-3` }));

    // The request id is random and the duration is a clock reading: neither
    // comes from the request, and either could contain these digits by chance.
    const written = JSON.stringify(
      [...logLines(info), ...logLines(error)].map(
        ({ requestId: _id, durationMs: _ms, ...rest }) => rest,
      ),
    );
    for (const secret of [UID, "savings", "checking", "15010", "357035", TRANSFER_ID, TOKEN]) {
      expect(written).not.toContain(secret);
    }
    expect(logLines(error)).toMatchObject([{ level: "error", outcome: "internal:Error" }]);
  });
});
