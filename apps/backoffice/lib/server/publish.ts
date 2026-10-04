import "server-only";
import { countChanges } from "@/lib/config/diff";
import {
  NO_FAULTS,
  resilienceOf,
  worsensFaults,
  type HomeConfig,
} from "@/lib/config/types";
import {
  configVersionOf,
  validateHomeConfig,
  type ConfigIssue,
} from "@/lib/config/validate";
import type { Admin } from "./session";
import type { ServerSettings } from "./settings";

/** One line of the publication history. */
export interface AuditEntry {
  version: number;
  publishedBy: string;
  publishedByUid: string;
  publishedAt: Date;
  /** Settings changed with respect to the version it replaced. */
  changes: number;
}

/**
 * Where the published document lives. `transact` reads the stored document,
 * as it is and unchecked (it may predate the contract or be damaged),
 * and, if `write` is called, replaces it and appends the audit entry, all or
 * nothing, retrying if the document changed underneath.
 */
export interface ConfigStore {
  transact<T>(
    run: (
      stored: unknown,
      write: (document: HomeConfig, entry: AuditEntry) => void,
    ) => T,
  ): Promise<T>;
}

export interface PublishRequest {
  draft: unknown;
  /** Version the editor loaded, or null if nothing was published then. */
  baseVersion: number | null;
}

export type PublishResult =
  | { ok: true; version: number; publishedAt: string }
  | { ok: false; kind: "invalid"; issues: ConfigIssue[] }
  | { ok: false; kind: "too-large"; limitBytes: number }
  | { ok: false; kind: "faults-not-allowed" }
  | { ok: false; kind: "conflict"; storedVersion: number | null };

const FIRST_VERSION = 1;

/**
 * Largest draft accepted, as serialized JSON. A quarter of what a Firestore
 * document can hold, and far above a real configuration (the contract's
 * example is about 5 KB). Every phone downloads this document on each change.
 */
export const MAX_DRAFT_BYTES = 256 * 1024;

/** Serialized size in bytes, or null when the value cannot be serialized. */
function serializedBytes(value: unknown): number | null {
  try {
    const json = JSON.stringify(value);
    return json === undefined ? null : new TextEncoder().encode(json).length;
  } catch {
    return null;
  }
}

/**
 * Publishes a draft: validated against the contract first, then written only
 * if nobody else published since the editor loaded it. The version number is
 * taken from what is stored, never from the browser.
 */
export async function publishConfig(
  store: ConfigStore,
  settings: ServerSettings,
  admin: Admin,
  now: Date,
  request: PublishRequest,
): Promise<PublishResult> {
  // Measured before anything walks the document: validation cost grows with
  // its size, and an oversized one is refused whatever it contains.
  const bytes = serializedBytes(request.draft);
  if (bytes === null) {
    return {
      ok: false,
      kind: "invalid",
      issues: [{ path: "", message: "cannot be serialized" }],
    };
  }
  if (bytes > MAX_DRAFT_BYTES) {
    return { ok: false, kind: "too-large", limitBytes: MAX_DRAFT_BYTES };
  }

  const validation = validateHomeConfig(request.draft);
  if (!validation.ok) {
    return { ok: false, kind: "invalid", issues: validation.issues };
  }
  const draft = validation.config;

  return store.transact((stored, write) => {
    const storedVersion = configVersionOf(stored);
    if (storedVersion !== request.baseVersion) {
      return { ok: false, kind: "conflict", storedVersion };
    }
    const previous = validateHomeConfig(stored);

    // Outside a demonstration nobody may add a simulated fault or make one
    // worse. Faults that are already live may stay or be reduced: refusing
    // them outright would block every publish until someone cleared them,
    // including the publish that clears them.
    const liveFaults = previous.ok ? resilienceOf(previous.config) : NO_FAULTS;
    if (!settings.isDemo && worsensFaults(liveFaults, resilienceOf(draft))) {
      return { ok: false, kind: "faults-not-allowed" };
    }

    const version = storedVersion === null ? FIRST_VERSION : storedVersion + 1;
    const document: HomeConfig = { ...draft, configVersion: version };
    write(document, {
      version,
      publishedBy: admin.email,
      publishedByUid: admin.uid,
      publishedAt: now,
      // Only a stored document that honours the contract can be compared;
      // over a broken one this publish is a repair, not a set of edits.
      changes: previous.ok ? countChanges(previous.config, document) : 0,
    });
    return { ok: true, version, publishedAt: now.toISOString() };
  });
}
