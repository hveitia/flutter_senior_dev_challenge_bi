import { countChanges } from "@/lib/config/diff";
import { NO_FAULTS, resilienceOf, type HomeConfig } from "@/lib/config/types";
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
  | { ok: false; kind: "faults-not-allowed" }
  | { ok: false; kind: "conflict"; storedVersion: number | null };

const FIRST_VERSION = 1;

function hasFaults(config: HomeConfig): boolean {
  const faults = resilienceOf(config);
  return (
    faults.latencyMs !== NO_FAULTS.latencyMs ||
    faults.movementsUnavailable ||
    faults.partnerInsuranceUnavailable
  );
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
  const validation = validateHomeConfig(request.draft);
  if (!validation.ok) {
    return { ok: false, kind: "invalid", issues: validation.issues };
  }
  const draft = validation.config;

  if (!settings.isDemo && hasFaults(draft)) {
    return { ok: false, kind: "faults-not-allowed" };
  }

  return store.transact((stored, write) => {
    const storedVersion = configVersionOf(stored);
    if (storedVersion !== request.baseVersion) {
      return { ok: false, kind: "conflict", storedVersion };
    }

    const version = storedVersion === null ? FIRST_VERSION : storedVersion + 1;
    const previous = validateHomeConfig(stored);
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
