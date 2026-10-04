import "server-only";
import type { Firestore, Timestamp } from "firebase-admin/firestore";
import type { HomeConfig } from "@/lib/config/types";
import { consoleStateFrom, type ConsoleState } from "./console-state";
import type { ConfigStore } from "./publish";

/** The document the mobile app listens to. */
export const CONFIG_COLLECTION = "config";
export const CONFIG_DOCUMENT_ID = "home";
/** One entry per publication, keyed by version. Clients cannot read it. */
export const AUDIT_COLLECTION = "configAudit";

function auditId(version: number): string {
  return `v${version}`;
}

export function firestoreConfigStore(db: Firestore): ConfigStore {
  const home = db.collection(CONFIG_COLLECTION).doc(CONFIG_DOCUMENT_ID);
  return {
    transact(run) {
      return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(home);
        const stored = snapshot.exists ? (snapshot.data() as HomeConfig) : null;
        return run(stored, (document, entry) => {
          transaction.set(home, document);
          transaction.set(
            db.collection(AUDIT_COLLECTION).doc(auditId(entry.version)),
            entry,
          );
        });
      });
    },
  };
}

/** Reads what is live and when it was published. */
export async function loadConsoleState(db: Firestore): Promise<ConsoleState> {
  const snapshot = await db
    .collection(CONFIG_COLLECTION)
    .doc(CONFIG_DOCUMENT_ID)
    .get();
  const stored: unknown = snapshot.exists ? snapshot.data() : null;

  const version = (stored as { configVersion?: unknown } | null)?.configVersion;
  let lastPublishedAt: string | null = null;
  if (typeof version === "number") {
    const entry = await db.collection(AUDIT_COLLECTION).doc(auditId(version)).get();
    const publishedAt = entry.get("publishedAt") as Timestamp | undefined;
    lastPublishedAt = publishedAt?.toDate().toISOString() ?? null;
  }

  return consoleStateFrom(stored, lastPublishedAt);
}
