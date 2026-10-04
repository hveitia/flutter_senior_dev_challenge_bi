import { describe, expect, it, vi } from "vitest";
import type { PushPorts } from "./push";
import {
  TRANSFER_NOTICE,
  noticeIdOf,
  notifyTransferCompleted,
  shouldNotify,
  type NoticePorts,
} from "./transfer-notice";

const now = new Date("2026-10-04T15:00:00.000Z");
const TRANSFER_ID = "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f";

function ports(overrides: Partial<NoticePorts> = {}): NoticePorts {
  return {
    gateway: {
      sendToTopic: vi.fn().mockResolvedValue(undefined),
      sendToTokens: vi
        .fn()
        .mockResolvedValue({ delivered: 1, failed: 0, unregistered: [] }),
    },
    customers: {
      uidByEmail: vi.fn(),
      deviceTokens: vi.fn().mockResolvedValue(["token-1"]),
      flagUnregistered: vi.fn().mockResolvedValue(undefined),
      uidsInSegment: vi.fn(),
    } as PushPorts["customers"],
    inbox: { deliver: vi.fn().mockResolvedValue(undefined) },
    ...overrides,
  };
}

const live = { pushDryRun: false };
const dryRun = { pushDryRun: true };

describe("shouldNotify", () => {
  it("is true only for a transfer completed by this very call", () => {
    const completed = {
      id: TRANSFER_ID,
      status: "completed" as const,
      processedAt: now.toISOString(),
      reference: "TRF-202610-ABCDEF0123",
    };
    const rejected = {
      id: TRANSFER_ID,
      status: "rejected" as const,
      processedAt: now.toISOString(),
      reason: "insufficient-funds" as const,
    };

    expect(shouldNotify({ kind: "settled", transfer: completed, replayed: false })).toBe(true);
    // A replay already told the customer the first time.
    expect(shouldNotify({ kind: "settled", transfer: completed, replayed: true })).toBe(false);
    expect(shouldNotify({ kind: "settled", transfer: rejected, replayed: false })).toBe(false);
    expect(shouldNotify({ kind: "not-found" })).toBe(false);
    expect(shouldNotify({ kind: "key-reused" })).toBe(false);
  });
});

describe("notifyTransferCompleted", () => {
  it("files the notice in the customer's inbox under an id tied to the transfer", async () => {
    const p = ports();

    await notifyTransferCompleted(p, live, "uid-1", TRANSFER_ID, now, vi.fn());

    expect(p.inbox.deliver).toHaveBeenCalledWith(["uid-1"], noticeIdOf(TRANSFER_ID), {
      title: TRANSFER_NOTICE.title,
      body: TRANSFER_NOTICE.body,
      kind: "movement",
      destination: "accounts",
      createdAt: now,
      read: false,
    });
  });

  it("says nothing about amounts, accounts or references", () => {
    const text = `${TRANSFER_NOTICE.title} ${TRANSFER_NOTICE.body}`;

    expect(text).not.toMatch(/\d/);
    expect(text).not.toMatch(/\$/);
  });

  it("announces it on the customer's devices when delivery is live", async () => {
    const p = ports();

    await notifyTransferCompleted(p, live, "uid-1", TRANSFER_ID, now, vi.fn());

    expect(p.gateway.sendToTokens).toHaveBeenCalledWith(
      ["token-1"],
      { ...TRANSFER_NOTICE },
      false,
    );
  });

  it("files the notice but sends no push when delivery is not live", async () => {
    const p = ports();

    await notifyTransferCompleted(p, dryRun, "uid-1", TRANSFER_ID, now, vi.fn());

    expect(p.inbox.deliver).toHaveBeenCalledTimes(1);
    expect(p.gateway.sendToTokens).not.toHaveBeenCalled();
  });

  it("sends no push to a customer without a registered device", async () => {
    const p = ports();
    vi.mocked(p.customers.deviceTokens).mockResolvedValue([]);

    await notifyTransferCompleted(p, live, "uid-1", TRANSFER_ID, now, vi.fn());

    expect(p.gateway.sendToTokens).not.toHaveBeenCalled();
  });

  it("flags the devices the messaging service no longer knows", async () => {
    const p = ports();
    vi.mocked(p.gateway.sendToTokens).mockResolvedValue({
      delivered: 0,
      failed: 1,
      unregistered: ["token-1"],
    });

    await notifyTransferCompleted(p, live, "uid-1", TRANSFER_ID, now, vi.fn());

    expect(p.customers.flagUnregistered).toHaveBeenCalledWith("uid-1", ["token-1"], now);
  });

  it("never throws: a failing inbox is reported by step and the push still goes out", async () => {
    const p = ports();
    vi.mocked(p.inbox.deliver).mockRejectedValue(new Error("unavailable"));
    const report = vi.fn();

    await expect(
      notifyTransferCompleted(p, live, "uid-1", TRANSFER_ID, now, report),
    ).resolves.toBeUndefined();

    expect(report).toHaveBeenCalledWith("inbox");
    expect(p.gateway.sendToTokens).toHaveBeenCalledTimes(1);
  });

  it("never throws when the messaging service fails", async () => {
    const p = ports();
    vi.mocked(p.gateway.sendToTokens).mockRejectedValue(new Error("down"));
    const report = vi.fn();

    await expect(
      notifyTransferCompleted(p, live, "uid-1", TRANSFER_ID, now, report),
    ).resolves.toBeUndefined();

    expect(report).toHaveBeenCalledWith("push");
  });
});
