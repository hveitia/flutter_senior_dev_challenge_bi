import { beforeEach, describe, expect, it, vi } from "vitest";
import type { HomeConfig } from "@/lib/config/types";
import type { AuditEntry } from "@/lib/server/publish";
import { exampleConfig } from "@/test/support/fixtures";

const currentAdmin = vi.fn();
const transact = vi.fn();

vi.mock("@/lib/server/current-admin", () => ({ currentAdmin }));
vi.mock("@/lib/server/firebase", () => ({
  adminDb: () => ({}),
  serverSettings: () => ({
    projectId: "flutter-challenge-bi",
    adminEmails: new Set(["ana@example.com"]),
    isDemo: true,
    pushDryRun: false,
    serviceAccount: null,
  }),
}));
vi.mock("@/lib/server/config-store", () => ({
  firestoreConfigStore: () => ({ transact }),
}));

const { publishConfigAction } = await import("./actions");

function storing(stored: HomeConfig | null) {
  const written: { document?: HomeConfig; entry?: AuditEntry } = {};
  transact.mockImplementation(async (run) =>
    run(stored, (document: HomeConfig, entry: AuditEntry) => {
      written.document = document;
      written.entry = entry;
    }),
  );
  return written;
}

beforeEach(() => {
  currentAdmin.mockReset();
  transact.mockReset();
});

describe("publishConfigAction", () => {
  it("refuses a caller without an administrator session and touches nothing", async () => {
    currentAdmin.mockResolvedValue(null);

    const outcome = await publishConfigAction({
      draft: exampleConfig(),
      baseVersion: 14,
    });

    expect(outcome).toEqual({ ok: false, kind: "unauthorized" });
    expect(transact).not.toHaveBeenCalled();
  });

  it("publishes for an administrator and records them as the author", async () => {
    currentAdmin.mockResolvedValue({ uid: "uid-ana", email: "ana@example.com" });
    const written = storing({ ...exampleConfig(), configVersion: 14 });

    const outcome = await publishConfigAction({
      draft: exampleConfig(),
      baseVersion: 14,
    });

    expect(outcome).toMatchObject({ ok: true, version: 15 });
    expect(written.document?.configVersion).toBe(15);
    expect(written.entry?.publishedBy).toBe("ana@example.com");
  });

  it("reports a version conflict without writing", async () => {
    currentAdmin.mockResolvedValue({ uid: "uid-ana", email: "ana@example.com" });
    const written = storing({ ...exampleConfig(), configVersion: 16 });

    const outcome = await publishConfigAction({
      draft: exampleConfig(),
      baseVersion: 14,
    });

    expect(outcome).toEqual({ ok: false, kind: "conflict", storedVersion: 16 });
    expect(written.document).toBeUndefined();
  });

  it("reports a draft that breaks the contract", async () => {
    currentAdmin.mockResolvedValue({ uid: "uid-ana", email: "ana@example.com" });
    storing({ ...exampleConfig(), configVersion: 14 });

    const outcome = await publishConfigAction({
      draft: { ...exampleConfig(), segments: {} },
      baseVersion: 14,
    });

    expect(outcome).toMatchObject({ ok: false, kind: "invalid" });
  });

  it("treats a base version that is not a whole number as an invalid request", async () => {
    currentAdmin.mockResolvedValue({ uid: "uid-ana", email: "ana@example.com" });

    const outcome = await publishConfigAction({
      draft: exampleConfig(),
      baseVersion: "14" as unknown as number,
    });

    expect(outcome).toMatchObject({ ok: false, kind: "invalid" });
    expect(transact).not.toHaveBeenCalled();
  });

  it("reports the store being unreachable instead of throwing", async () => {
    currentAdmin.mockResolvedValue({ uid: "uid-ana", email: "ana@example.com" });
    transact.mockRejectedValue(new Error("UNAVAILABLE: connection reset"));

    const outcome = await publishConfigAction({
      draft: exampleConfig(),
      baseVersion: 14,
    });

    expect(outcome).toEqual({ ok: false, kind: "unavailable" });
  });
});
