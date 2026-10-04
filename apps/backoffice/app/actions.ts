"use server";

import { firestoreConfigStore } from "@/lib/server/config-store";
import { currentAdmin } from "@/lib/server/current-admin";
import { adminDb, serverSettings } from "@/lib/server/firebase";
import {
  publishConfig,
  type PublishRequest,
  type PublishResult,
} from "@/lib/server/publish";

export type PublishOutcome =
  | PublishResult
  | { ok: false; kind: "unauthorized" }
  | { ok: false; kind: "unavailable" };

function isBaseVersion(value: unknown): value is number | null {
  return value === null || (typeof value === "number" && Number.isInteger(value));
}

/**
 * Publishes the editor's draft. Callable from the browser, so nothing the
 * caller sends is trusted: the session is checked here, and the request is
 * validated before it reaches the store.
 */
export async function publishConfigAction(
  request: PublishRequest,
): Promise<PublishOutcome> {
  const admin = await currentAdmin();
  if (!admin) return { ok: false, kind: "unauthorized" };

  if (!isBaseVersion(request.baseVersion)) {
    return {
      ok: false,
      kind: "invalid",
      issues: [{ path: "/baseVersion", message: "must be a whole number or null" }],
    };
  }

  try {
    return await publishConfig(
      firestoreConfigStore(adminDb()),
      serverSettings(),
      admin,
      new Date(),
      { draft: request.draft, baseVersion: request.baseVersion },
    );
  } catch {
    // The cause stays on the server; the editor only needs to know it can retry.
    return { ok: false, kind: "unavailable" };
  }
}
