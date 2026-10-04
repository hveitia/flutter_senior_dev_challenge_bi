import { describe, expect, it, vi } from "vitest";
import { BODY_MAX_LENGTH, TITLE_MAX_LENGTH } from "@/lib/push/types";
import {
  canClaimRetry,
  RETRY_CLAIM_TTL_MS,
  retryPush,
  segmentTopic,
  sendPush,
  validatePushDraft,
  type PushPorts,
  type StoredPush,
} from "./push";

const admin = { uid: "uid-ana", email: "ana@example.com" };
const now = new Date("2026-10-03T14:09:00Z");
const later = new Date("2026-10-03T14:10:00Z");
const destinations = ["inbox", "transfer", "partner:travelInsurance"];
const segments = ["starting", "family", "wealth"];

const toSegment = {
  title: "Una novedad para ti",
  body: "Ya puedes transferir entre tus cuentas.",
  audience: { kind: "segment", segmentId: "family" },
  destination: "transfer",
};

function draftOf(input: unknown) {
  const result = validatePushDraft(input, destinations, segments);
  if (!result.ok) throw new Error(`invalid draft: ${result.fields.join(",")}`);
  return result.draft;
}

/** In-memory ports. `records` is the history collection. */
function ports(overrides: Partial<PushPorts> = {}): PushPorts & {
  records: Map<string, StoredPush>;
} {
  const records = new Map<string, StoredPush>();
  return {
    records,
    gateway: {
      sendToTopic: vi.fn().mockResolvedValue(undefined),
      sendToTokens: vi.fn().mockResolvedValue({ delivered: 1, failed: 0 }),
    },
    customers: {
      uidByEmail: vi.fn().mockResolvedValue("uid-customer"),
      deviceTokens: vi.fn().mockResolvedValue(["token-1"]),
    },
    history: {
      add: vi.fn(async (record: StoredPush) => {
        const id = `push-${records.size + 1}`;
        records.set(id, record);
        return id;
      }),
      // Atomic, as the real store's transaction is: check and mark in one step.
      claimRetry: vi.fn(async (id: string, at: Date) => {
        const current = records.get(id);
        if (!current || !canClaimRetry(current, at)) return null;
        const claimed = { ...current, status: "retrying" as const, retryClaimedAt: at };
        records.set(id, claimed);
        return claimed;
      }),
      update: vi.fn(async (id: string, patch: Partial<StoredPush>) => {
        const current = records.get(id);
        if (current) records.set(id, { ...current, ...patch });
      }),
    },
    ...overrides,
  };
}

describe("validatePushDraft", () => {
  it("accepts a notification for a segment", () => {
    expect(validatePushDraft(toSegment, destinations, segments)).toEqual({
      ok: true,
      draft: toSegment,
    });
  });

  it("accepts a notification for one customer and normalizes the address", () => {
    const result = validatePushDraft(
      { ...toSegment, audience: { kind: "customer", email: " Cliente@Example.com " } },
      destinations,
      segments,
    );

    expect(result).toMatchObject({
      ok: true,
      draft: { audience: { kind: "customer", email: "cliente@example.com" } },
    });
  });

  it("trims the title and the message", () => {
    const result = validatePushDraft(
      { ...toSegment, title: "  Hola  ", body: "  Mensaje  " },
      destinations,
      segments,
    );

    expect(result).toMatchObject({ ok: true, draft: { title: "Hola", body: "Mensaje" } });
  });

  it("names each field that is wrong", () => {
    const result = validatePushDraft(
      {
        title: " ",
        body: "x".repeat(BODY_MAX_LENGTH + 1),
        audience: { kind: "segment", segmentId: "vip" },
        destination: "https://example.com",
      },
      destinations,
      segments,
    );

    expect(result).toEqual({
      ok: false,
      fields: ["title", "body", "audience", "destination"],
    });
  });

  it("rejects a title longer than a notification can show", () => {
    const result = validatePushDraft(
      { ...toSegment, title: "x".repeat(TITLE_MAX_LENGTH + 1) },
      destinations,
      segments,
    );

    expect(result).toEqual({ ok: false, fields: ["title"] });
  });

  it("rejects a customer audience without a plausible address", () => {
    const result = validatePushDraft(
      { ...toSegment, audience: { kind: "customer", email: "not-an-address" } },
      destinations,
      segments,
    );

    expect(result).toEqual({ ok: false, fields: ["audience"] });
  });

  it("rejects input that is not an object", () => {
    expect(validatePushDraft(null, destinations, segments).ok).toBe(false);
    expect(validatePushDraft("push", destinations, segments).ok).toBe(false);
  });
});

describe("sendPush", () => {
  it("sends to the topic of the segment with the destination as data", async () => {
    const p = ports();

    await sendPush(p, { pushDryRun: false }, admin, now, draftOf(toSegment), "Familia");

    expect(p.gateway.sendToTopic).toHaveBeenCalledWith(
      segmentTopic("family"),
      {
        title: "Una novedad para ti",
        body: "Ya puedes transferir entre tus cuentas.",
        destination: "transfer",
      },
      false,
    );
  });

  it("records a delivered send in the history", async () => {
    const p = ports();

    const record = await sendPush(
      p,
      { pushDryRun: false },
      admin,
      now,
      draftOf(toSegment),
      "Familia",
    );

    expect(record).toEqual({
      id: "push-1",
      createdAt: now.toISOString(),
      title: "Una novedad para ti",
      audienceLabel: "Familia",
      status: "sent",
      error: null,
      retryable: false,
    });
    expect(p.records.get("push-1")).toMatchObject({
      status: "sent",
      attempts: 1,
      sentBy: "ana@example.com",
      dryRun: false,
      audience: { kind: "segment", segmentId: "family" },
    });
  });

  it("marks a dry run as validated, not as sent", async () => {
    const p = ports();

    const record = await sendPush(
      p,
      { pushDryRun: true },
      admin,
      now,
      draftOf(toSegment),
      "Familia",
    );

    expect(record.status).toBe("validated");
    expect(p.gateway.sendToTopic).toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
      true,
    );
  });

  it("records a failed send with the service's error code and keeps going", async () => {
    const p = ports();
    vi.mocked(p.gateway.sendToTopic).mockRejectedValue(
      Object.assign(new Error("quota"), { code: "messaging/quota-exceeded" }),
    );

    const record = await sendPush(
      p,
      { pushDryRun: false },
      admin,
      now,
      draftOf(toSegment),
      "Familia",
    );

    expect(record.status).toBe("failed");
    expect(record.error).toBe("messaging/quota-exceeded");
    expect(p.records.get("push-1")?.status).toBe("failed");
  });

  it("sends to every device of one customer and stores the uid, not the address", async () => {
    const p = ports();
    vi.mocked(p.customers.deviceTokens).mockResolvedValue(["t1", "t2"]);
    const draft = draftOf({
      ...toSegment,
      audience: { kind: "customer", email: "cliente@example.com" },
    });

    const record = await sendPush(p, { pushDryRun: false }, admin, now, draft, "Un cliente");

    expect(p.gateway.sendToTokens).toHaveBeenCalledWith(
      ["t1", "t2"],
      expect.objectContaining({ destination: "transfer" }),
      false,
    );
    expect(record.status).toBe("sent");
    expect(p.records.get("push-1")?.audience).toEqual({
      kind: "customer",
      uid: "uid-customer",
    });
    expect(JSON.stringify(p.records.get("push-1"))).not.toContain("cliente@example.com");
  });

  describe("to an address that cannot be reached", () => {
    const toCustomer = (email: string) =>
      draftOf({ ...toSegment, audience: { kind: "customer", email } });

    async function unknownAddress() {
      const p = ports();
      vi.mocked(p.customers.uidByEmail).mockResolvedValue(null);
      const record = await sendPush(
        p,
        { pushDryRun: false },
        admin,
        now,
        toCustomer("nadie@example.com"),
        "Un cliente",
      );
      return { p, record };
    }

    async function customerWithoutDevice() {
      const p = ports();
      vi.mocked(p.customers.deviceTokens).mockResolvedValue([]);
      const record = await sendPush(
        p,
        { pushDryRun: false },
        admin,
        now,
        toCustomer("cliente@example.com"),
        "Un cliente",
      );
      return { p, record };
    }

    it("fails without calling the service", async () => {
      const unknown = await unknownAddress();
      const withoutDevice = await customerWithoutDevice();

      expect(unknown.record).toMatchObject({ status: "failed", retryable: false });
      expect(unknown.p.gateway.sendToTokens).not.toHaveBeenCalled();
      expect(withoutDevice.p.gateway.sendToTokens).not.toHaveBeenCalled();
    });

    it("shows and stores the same outcome whether or not the address is a customer", async () => {
      const unknown = await unknownAddress();
      const withoutDevice = await customerWithoutDevice();

      expect(unknown.record).toEqual(withoutDevice.record);
      expect(unknown.p.records.get("push-1")).toEqual(
        withoutDevice.p.records.get("push-1"),
      );
      expect(unknown.record.error).toBe("customer-unreachable");
    });

    it("cannot be retried, since the record does not say who it was for", async () => {
      const { p, record } = await customerWithoutDevice();

      expect(await retryPush(p, { pushDryRun: false }, record.id, later)).toBeNull();
    });
  });

  it("fails when no device of the customer accepted the notification", async () => {
    const p = ports();
    vi.mocked(p.gateway.sendToTokens).mockResolvedValue({ delivered: 0, failed: 1 });
    const draft = draftOf({
      ...toSegment,
      audience: { kind: "customer", email: "cliente@example.com" },
    });

    const record = await sendPush(p, { pushDryRun: false }, admin, now, draft, "Un cliente");

    expect(record).toMatchObject({ status: "failed", error: "no-device-accepted" });
  });
});

describe("retryPush", () => {
  async function failedSend(p: ReturnType<typeof ports>) {
    vi.mocked(p.gateway.sendToTopic).mockRejectedValueOnce(new Error("down"));
    return sendPush(p, { pushDryRun: false }, admin, now, draftOf(toSegment), "Familia");
  }

  it("sends a failed notification again and updates the same record", async () => {
    const p = ports();
    const failed = await failedSend(p);

    const retried = await retryPush(p, { pushDryRun: false }, failed.id, later);

    expect(retried).toMatchObject({ id: failed.id, status: "sent", error: null });
    expect(p.records.size).toBe(1);
    expect(p.records.get(failed.id)).toMatchObject({ status: "sent", attempts: 2 });
    expect(p.gateway.sendToTopic).toHaveBeenCalledTimes(2);
  });

  it("keeps the record failed when the retry fails too", async () => {
    const p = ports();
    const failed = await failedSend(p);
    vi.mocked(p.gateway.sendToTopic).mockRejectedValueOnce(new Error("still down"));

    const retried = await retryPush(p, { pushDryRun: false }, failed.id, later);

    expect(retried).toMatchObject({ status: "failed" });
    expect(p.records.get(failed.id)?.attempts).toBe(2);
  });

  it("does not send again a notification that already went out", async () => {
    const p = ports();
    const sent = await sendPush(
      p,
      { pushDryRun: false },
      admin,
      now,
      draftOf(toSegment),
      "Familia",
    );

    const retried = await retryPush(p, { pushDryRun: false }, sent.id, later);

    expect(retried).toBeNull();
    expect(p.gateway.sendToTopic).toHaveBeenCalledTimes(1);
  });

  it("answers nothing for a record that does not exist", async () => {
    expect(await retryPush(ports(), { pushDryRun: false }, "missing", later)).toBeNull();
  });

  it("sends once when two retries of the same notification race", async () => {
    const p = ports();
    const failed = await failedSend(p);

    const outcomes = await Promise.all([
      retryPush(p, { pushDryRun: false }, failed.id, later),
      retryPush(p, { pushDryRun: false }, failed.id, later),
    ]);

    expect(outcomes.filter((outcome) => outcome !== null)).toHaveLength(1);
    expect(p.gateway.sendToTopic).toHaveBeenCalledTimes(2);
    expect(p.records.get(failed.id)).toMatchObject({ status: "sent", attempts: 2 });
  });

  it("can be retried again after a retry that failed", async () => {
    const p = ports();
    const failed = await failedSend(p);
    vi.mocked(p.gateway.sendToTopic).mockRejectedValueOnce(new Error("still down"));
    await retryPush(p, { pushDryRun: false }, failed.id, later);

    const retried = await retryPush(p, { pushDryRun: false }, failed.id, later);

    expect(retried).toMatchObject({ status: "sent" });
    expect(p.records.get(failed.id)?.attempts).toBe(3);
  });
});

describe("canClaimRetry", () => {
  const record = (overrides: Partial<StoredPush>): StoredPush => ({
    createdAt: now,
    title: "t",
    body: "b",
    destination: "inbox",
    audience: { kind: "segment", segmentId: "family" },
    audienceLabel: "Familia",
    status: "failed",
    error: "unknown",
    attempts: 1,
    sentBy: "ana@example.com",
    dryRun: false,
    ...overrides,
  });

  it("allows a failed send", () => {
    expect(canClaimRetry(record({}), later)).toBe(true);
  });

  it("does not allow a send that went out, was validated or is being retried", () => {
    expect(canClaimRetry(record({ status: "sent" }), later)).toBe(false);
    expect(canClaimRetry(record({ status: "validated" }), later)).toBe(false);
    expect(
      canClaimRetry(record({ status: "retrying", retryClaimedAt: later }), later),
    ).toBe(false);
  });

  it("allows a retry whose claim was abandoned long enough ago", () => {
    const abandoned = record({ status: "retrying", retryClaimedAt: now });
    const justBefore = new Date(now.getTime() + RETRY_CLAIM_TTL_MS - 1);
    const justAfter = new Date(now.getTime() + RETRY_CLAIM_TTL_MS + 1);

    expect(canClaimRetry(abandoned, justBefore)).toBe(false);
    expect(canClaimRetry(abandoned, justAfter)).toBe(true);
  });
});
