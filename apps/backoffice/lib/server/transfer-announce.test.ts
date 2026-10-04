import { afterEach, describe, expect, it, vi } from "vitest";
import type { ProcessResult } from "./transfers";

const after = vi.hoisted(() => vi.fn());
vi.mock("next/server", () => ({ after }));
vi.mock("./firebase", () => ({
  adminAuth: vi.fn(),
  adminDb: vi.fn(),
  adminMessaging: vi.fn(),
  serverSettings: vi.fn(),
}));
vi.mock("./push-store", () => ({ firebasePushPorts: vi.fn() }));

import { announceSettled } from "./transfer-announce";

const now = new Date("2026-10-04T15:00:00.000Z");
const UID = "uid-of-the-customer";
const TRANSFER_ID = "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f";

const completed: ProcessResult = {
  kind: "settled",
  replayed: false,
  transfer: {
    id: TRANSFER_ID,
    status: "completed",
    processedAt: now.toISOString(),
    reference: "TRF-202610-ABCDEF0123",
  },
};

afterEach(() => {
  after.mockReset();
  vi.restoreAllMocks();
});

describe("announceSettled", () => {
  it("leaves the notice for after the answer when this call completed the transfer", () => {
    announceSettled(completed, UID, TRANSFER_ID, now);

    expect(after).toHaveBeenCalledTimes(1);
  });

  it("schedules nothing for a replay", () => {
    announceSettled({ ...completed, replayed: true }, UID, TRANSFER_ID, now);

    expect(after).not.toHaveBeenCalled();
  });

  it("never throws when the notice cannot even be scheduled", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    after.mockImplementation(() => {
      throw new Error(`after is unavailable for ${UID}`);
    });

    expect(() => announceSettled(completed, UID, TRANSFER_ID, now)).not.toThrow();
  });

  it("logs the failed step and nothing about the customer or the transfer", () => {
    const logged = vi.spyOn(console, "error").mockImplementation(() => {});
    after.mockImplementation(() => {
      throw new Error(`after is unavailable for ${UID} ${TRANSFER_ID}`);
    });

    announceSettled(completed, UID, TRANSFER_ID, now);

    expect(logged).toHaveBeenCalledTimes(1);
    const line = String(logged.mock.calls[0]?.[0]);
    expect(JSON.parse(line)).toEqual({ event: "transfer_notice_failed", step: "schedule" });
    expect(line).not.toContain(UID);
    expect(line).not.toContain(TRANSFER_ID);
  });
});
