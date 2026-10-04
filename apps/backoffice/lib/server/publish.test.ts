import { describe, expect, it } from "vitest";
import { setModuleVisible, setResilience } from "@/lib/config/editing";
import type { HomeConfig } from "@/lib/config/types";
import { exampleConfig } from "@/test/support/fixtures";
import {
  publishConfig,
  type AuditEntry,
  type ConfigStore,
} from "./publish";
import type { ServerSettings } from "./settings";

const admin = { uid: "uid-ana", email: "ana@example.com" };
const now = new Date("2026-10-03T14:00:00Z");

const demo: ServerSettings = {
  projectId: "flutter-challenge-bi",
  adminEmails: new Set([admin.email]),
  isDemo: true,
  pushDryRun: false,
  serviceAccount: null,
};
const production: ServerSettings = { ...demo, isDemo: false };

/** Keeps one document and its audit trail in memory, atomically. */
class MemoryStore implements ConfigStore {
  audit: AuditEntry[] = [];
  constructor(public stored: unknown) {}

  async transact<T>(
    run: (
      stored: unknown,
      write: (document: HomeConfig, entry: AuditEntry) => void,
    ) => T,
  ): Promise<T> {
    return run(this.stored, (document, entry) => {
      this.stored = document;
      this.audit.push(entry);
    });
  }
}

function live(store: MemoryStore): HomeConfig | null {
  return store.stored as HomeConfig | null;
}

function published(version = 14): HomeConfig {
  return { ...exampleConfig(), configVersion: version };
}

describe("publishConfig", () => {
  it("stores the draft with the next version number", async () => {
    const store = new MemoryStore(published(14));
    const draft = setModuleVisible(published(14), "starting", "promo", false);

    const result = await publishConfig(store, demo, admin, now, {
      draft,
      baseVersion: 14,
    });

    expect(result).toEqual({ ok: true, version: 15, publishedAt: now.toISOString() });
    expect(live(store)?.configVersion).toBe(15);
    expect(
      live(store)?.segments.starting?.modules.find((m) => m.id === "promo")?.visible,
    ).toBe(false);
  });

  it("repairs a stored document that has a version but no segments", async () => {
    const store = new MemoryStore({ schemaVersion: 1, configVersion: 7 });

    const result = await publishConfig(store, demo, admin, now, {
      draft: exampleConfig(),
      baseVersion: 7,
    });

    expect(result).toMatchObject({ ok: true, version: 8 });
    expect(live(store)?.segments.starting?.label).toBe("Estoy empezando");
    expect(store.audit[0]?.changes).toBe(0);
  });

  it("repairs a stored document whose segments are malformed", async () => {
    const store = new MemoryStore({
      schemaVersion: 1,
      configVersion: 7,
      destinations: [],
      segments: { starting: "broken" },
    });

    const result = await publishConfig(store, demo, admin, now, {
      draft: exampleConfig(),
      baseVersion: 7,
    });

    expect(result).toMatchObject({ ok: true, version: 8 });
  });

  it("takes the version from what is stored, not from the draft", async () => {
    const store = new MemoryStore(published(14));
    const draft = { ...published(14), configVersion: 900 };

    const result = await publishConfig(store, demo, admin, now, {
      draft,
      baseVersion: 14,
    });

    expect(result).toMatchObject({ ok: true, version: 15 });
  });

  it("records who published, when and how much changed", async () => {
    const store = new MemoryStore(published(14));
    const draft = setModuleVisible(published(14), "starting", "promo", false);

    await publishConfig(store, demo, admin, now, { draft, baseVersion: 14 });

    expect(store.audit).toEqual([
      {
        version: 15,
        publishedBy: "ana@example.com",
        publishedByUid: "uid-ana",
        publishedAt: now,
        changes: 1,
      },
    ]);
  });

  it("refuses when someone else published since the editor loaded", async () => {
    const store = new MemoryStore(published(15));
    const draft = setModuleVisible(published(14), "starting", "promo", false);

    const result = await publishConfig(store, demo, admin, now, {
      draft,
      baseVersion: 14,
    });

    expect(result).toEqual({ ok: false, kind: "conflict", storedVersion: 15 });
    expect(live(store)?.configVersion).toBe(15);
    expect(store.audit).toEqual([]);
  });

  it("creates the document as version 1 when nothing was published yet", async () => {
    const store = new MemoryStore(null);

    const result = await publishConfig(store, demo, admin, now, {
      draft: exampleConfig(),
      baseVersion: null,
    });

    expect(result).toMatchObject({ ok: true, version: 1 });
    expect(live(store)?.configVersion).toBe(1);
  });

  it("refuses a first publish when a document appeared in the meantime", async () => {
    const store = new MemoryStore(published(3));

    const result = await publishConfig(store, demo, admin, now, {
      draft: exampleConfig(),
      baseVersion: null,
    });

    expect(result).toEqual({ ok: false, kind: "conflict", storedVersion: 3 });
  });

  it("refuses a draft that breaks the contract and stores nothing", async () => {
    const store = new MemoryStore(published(14));
    const draft = published(14);
    draft.segments = {};

    const result = await publishConfig(store, demo, admin, now, {
      draft,
      baseVersion: 14,
    });

    expect(result).toMatchObject({ ok: false, kind: "invalid" });
    expect(live(store)?.configVersion).toBe(14);
    expect(store.audit).toEqual([]);
  });

  it("refuses a draft that is not even an object", async () => {
    const store = new MemoryStore(published(14));

    const result = await publishConfig(store, demo, admin, now, {
      draft: "not a document",
      baseVersion: 14,
    });

    expect(result).toMatchObject({ ok: false, kind: "invalid" });
  });

  it("refuses simulated faults outside a demonstration environment", async () => {
    const store = new MemoryStore(published(14));
    const draft = setResilience(published(14), { latencyMs: 2000 });

    const result = await publishConfig(store, production, admin, now, {
      draft,
      baseVersion: 14,
    });

    expect(result).toEqual({ ok: false, kind: "faults-not-allowed" });
    expect(live(store)?.configVersion).toBe(14);
  });

  it("publishes a draft without faults outside a demonstration environment", async () => {
    const store = new MemoryStore(published(14));
    const draft = setModuleVisible(published(14), "starting", "promo", false);

    const result = await publishConfig(store, production, admin, now, {
      draft,
      baseVersion: 14,
    });

    expect(result).toMatchObject({ ok: true, version: 15 });
  });

  it("publishes simulated faults in a demonstration environment", async () => {
    const store = new MemoryStore(published(14));
    const draft = setResilience(published(14), { movementsUnavailable: true });

    const result = await publishConfig(store, demo, admin, now, {
      draft,
      baseVersion: 14,
    });

    expect(result).toMatchObject({ ok: true });
    expect(live(store)?.resilience?.movementsUnavailable).toBe(true);
  });
});
