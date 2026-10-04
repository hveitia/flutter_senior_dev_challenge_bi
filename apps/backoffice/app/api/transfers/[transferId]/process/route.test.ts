import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  checking,
  identityProvider,
  logLines,
  order,
  post,
  savings,
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

function path(transferId: string): string {
  return `/api/transfers/${transferId}/process`;
}

function call(transferId: string, headers?: Record<string, string>): Promise<Response> {
  return POST(post(path(transferId), {}, headers), {
    params: Promise.resolve({ transferId }),
  });
}

function leavePending(overrides: Record<string, unknown> = {}): void {
  ledger.putTransfer(UID, TRANSFER_ID, {
    ...order,
    status: "pending",
    createdAt: new Date("2026-10-03T13:00:00Z"),
    ...overrides,
  });
}

function balances() {
  return [
    ledger.account(UID, "savings")?.availableCents,
    ledger.account(UID, "checking")?.availableCents,
  ];
}

let info: ReturnType<typeof vi.spyOn>;

beforeEach(() => {
  ledger = new MemoryLedger();
  ledger.putAccount(UID, savings);
  ledger.putAccount(UID, checking);
  info = vi.spyOn(console, "info").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
});

describe("POST /api/transfers/{transferId}/process", () => {
  it.each([
    ["no credentials", {}],
    ["a token the provider does not recognise", { authorization: "Bearer forged" }],
    ["an administrator session cookie", { cookie: "__session=administrator-cookie" }],
  ])("answers 401 to %s and leaves the request pending", async (_name, headers) => {
    leavePending();

    const response = await call(TRANSFER_ID, headers);

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
    expect(ledger.transfer(UID, TRANSFER_ID)).toMatchObject({ status: "pending" });
    expect(ledger.attempts).toBe(0);
  });

  it("settles the request the app left pending", async () => {
    leavePending();

    const response = await call(TRANSFER_ID);

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      transfer: { id: TRANSFER_ID, status: "completed" },
    });
    expect(balances()).toEqual([342_025, 140_010]);
  });

  it("answers 422 with the reason when the request cannot be carried out", async () => {
    leavePending({ amountCents: 400_000 });

    const response = await call(TRANSFER_ID);

    expect(response.status).toBe(422);
    expect(await response.json()).toMatchObject({
      error: "transfer-rejected",
      reason: "insufficient-funds",
      transfer: { id: TRANSFER_ID, status: "rejected", reason: "insufficient-funds" },
    });
    expect(balances()).toEqual([357_035, 125_000]);
  });

  it("answers again exactly as the first time and debits once", async () => {
    leavePending();
    const first = await call(TRANSFER_ID);

    const second = await call(TRANSFER_ID);

    expect(second.status).toBe(200);
    expect(await second.json()).toEqual(await first.json());
    expect(balances()).toEqual([342_025, 140_010]);
    expect(ledger.commits).toBe(1);
  });

  it("debits once when the phone and a retry process it at the same moment", async () => {
    leavePending();
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

    const [one, two] = await Promise.all([call(TRANSFER_ID), call(TRANSFER_ID)]);

    expect([one.status, two.status]).toEqual([200, 200]);
    expect(await one.json()).toEqual(await two.json());
    expect(balances()).toEqual([342_025, 140_010]);
    expect(ledger.movementsOf(UID)).toHaveLength(2);
  });

  it("answers 404 for a request that was never created", async () => {
    const response = await call(TRANSFER_ID);

    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "transfer-not-found" });
  });

  it("answers 404 for another customer's request and leaves it alone", async () => {
    ledger.putAccount("uid-other", savings);
    ledger.putAccount("uid-other", checking);
    ledger.putTransfer("uid-other", TRANSFER_ID, { ...order, status: "pending" });

    const response = await call(TRANSFER_ID);

    expect(response.status).toBe(404);
    expect(ledger.transfer("uid-other", TRANSFER_ID)).toMatchObject({ status: "pending" });
    expect(ledger.account("uid-other", "savings")?.availableCents).toBe(357_035);
  });

  it.each([
    ["too short to be an id", "abc"],
    ["a path into another document", "..%2F..%2Fconfig%2Fhome-aaaaaaaa"],
  ])("answers 400 to an id that is %s without reading anything", async (_name, id) => {
    const response = await call(decodeURIComponent(id));

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({
      error: "invalid-request",
      fields: ["transferId"],
    });
    expect(ledger.attempts).toBe(0);
  });

  it("does not need or read a body", async () => {
    leavePending();
    const request = new Request(`http://localhost:3000${path(TRANSFER_ID)}`, {
      method: "POST",
      headers: { authorization: "Bearer valentina-id-token" },
    });

    const response = await POST(request, {
      params: Promise.resolve({ transferId: TRANSFER_ID }),
    });

    expect(response.status).toBe(200);
  });

  it("logs the route and the outcome of each call", async () => {
    leavePending();
    await call(TRANSFER_ID);
    await call(TRANSFER_ID);

    expect(logLines(info)).toMatchObject([
      { route: "transfers.process", status: 200, outcome: "completed" },
      { route: "transfers.process", status: 200, outcome: "replayed:completed" },
    ]);
  });
});
