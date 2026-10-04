import { beforeEach, describe, expect, it, vi } from "vitest";
import { exampleConfig } from "@/test/support/fixtures";

const currentAdmin = vi.fn();
const gateway = { sendToTopic: vi.fn(), sendToTokens: vi.fn() };
const history = { add: vi.fn(), get: vi.fn(), update: vi.fn() };
const customers = { uidByEmail: vi.fn(), deviceTokens: vi.fn() };

vi.mock("@/lib/server/current-admin", () => ({ currentAdmin }));
vi.mock("@/lib/server/firebase", () => ({
  adminDb: () => ({}),
  adminAuth: () => ({}),
  adminMessaging: () => ({}),
  serverSettings: () => ({ pushDryRun: false }),
}));
vi.mock("@/lib/server/push-store", () => ({
  firebasePushPorts: () => ({ gateway, history, customers }),
}));
vi.mock("@/lib/server/config-store", () => ({
  loadConsoleState: async () => ({
    config: exampleConfig(),
    baseVersion: 14,
    source: "published",
    lastPublishedAt: null,
  }),
}));

const { POST } = await import("./route");

const ORIGIN = "http://localhost:3000";
const valid = {
  title: "Una novedad para ti",
  body: "Ya puedes transferir entre tus cuentas.",
  audience: { kind: "segment", segmentId: "family" },
  destination: "transfer",
};

function request(body: unknown, origin: string | null = ORIGIN): Request {
  const headers: Record<string, string> = {
    host: "localhost:3000",
    "content-type": "application/json",
  };
  if (origin) headers.origin = origin;
  return new Request(`${ORIGIN}/api/push`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

beforeEach(() => {
  currentAdmin.mockReset().mockResolvedValue({
    uid: "uid-ana",
    email: "ana@example.com",
  });
  gateway.sendToTopic.mockReset().mockResolvedValue(undefined);
  history.add.mockReset().mockResolvedValue("push-1");
  history.get.mockReset();
  history.update.mockReset();
});

describe("POST /api/push", () => {
  it("refuses a request from another site before anything else", async () => {
    const response = await POST(request(valid, "https://evil.example.net"));

    expect(response.status).toBe(403);
    expect(currentAdmin).not.toHaveBeenCalled();
    expect(gateway.sendToTopic).not.toHaveBeenCalled();
  });

  it("refuses a caller without an administrator session and sends nothing", async () => {
    currentAdmin.mockResolvedValue(null);

    const response = await POST(request(valid));

    expect(response.status).toBe(401);
    expect(gateway.sendToTopic).not.toHaveBeenCalled();
    expect(history.add).not.toHaveBeenCalled();
  });

  it("names the wrong fields and sends nothing", async () => {
    const response = await POST(request({ ...valid, title: "", destination: "x" }));

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({
      error: "invalid",
      fields: ["title", "destination"],
    });
    expect(gateway.sendToTopic).not.toHaveBeenCalled();
  });

  it("sends to the segment and answers with the history row", async () => {
    const response = await POST(request(valid));

    expect(response.status).toBe(200);
    expect(gateway.sendToTopic).toHaveBeenCalledWith(
      "segment-family",
      expect.objectContaining({ destination: "transfer" }),
      false,
    );
    const { record } = (await response.json()) as { record: unknown };
    expect(record).toMatchObject({
      id: "push-1",
      title: "Una novedad para ti",
      audienceLabel: "Familia",
      status: "sent",
    });
  });

  it("answers with a failed row, not an error, when the service rejects the send", async () => {
    gateway.sendToTopic.mockRejectedValue(new Error("down"));

    const response = await POST(request(valid));

    expect(response.status).toBe(200);
    const { record } = (await response.json()) as { record: { status: string } };
    expect(record.status).toBe("failed");
  });

  it("retries a failed send by id", async () => {
    history.get.mockResolvedValue({
      createdAt: new Date("2026-10-03T13:30:00Z"),
      title: "Tu cuenta está protegida",
      body: "Activamos una nueva verificación.",
      destination: "inbox",
      audience: { kind: "segment", segmentId: "family" },
      audienceLabel: "Familia",
      status: "failed",
      error: "unknown",
      attempts: 1,
      sentBy: "ana@example.com",
      dryRun: false,
    });

    const response = await POST(request({ retryOf: "push-7" }));

    expect(response.status).toBe(200);
    expect(history.update).toHaveBeenCalledWith(
      "push-7",
      expect.objectContaining({ status: "sent", attempts: 2 }),
    );
  });

  it("answers a conflict when there is nothing to retry", async () => {
    history.get.mockResolvedValue(null);

    const response = await POST(request({ retryOf: "missing" }));

    expect(response.status).toBe(409);
    expect(gateway.sendToTopic).not.toHaveBeenCalled();
  });

  it("answers that the service is unavailable when the history cannot be written", async () => {
    history.add.mockRejectedValue(new Error("UNAVAILABLE"));

    const response = await POST(request(valid));

    expect(response.status).toBe(503);
  });
});
