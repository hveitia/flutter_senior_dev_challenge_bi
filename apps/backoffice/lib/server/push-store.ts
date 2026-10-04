import "server-only";
import type { Auth } from "firebase-admin/auth";
import type { Firestore, Timestamp } from "firebase-admin/firestore";
import type { Messaging } from "firebase-admin/messaging";
import type { PushRecord } from "@/lib/push/types";
import {
  canClaimRetry,
  pushRecordOf,
  type PushMessage,
  type PushPorts,
  type StoredPush,
} from "./push";

/** One document per send. Clients cannot read or write it. */
export const PUSH_HISTORY_COLLECTION = "pushHistory";
/** `users/{uid}/devices/{id}` with a `token` field, written by the mobile app. */
export const DEVICES_SUBCOLLECTION = "devices";

const USER_NOT_FOUND = "auth/user-not-found";

function payload(message: PushMessage) {
  return {
    notification: { title: message.title, body: message.body },
    // The app resolves this through the same destination allow-list it uses
    // for banners and quick actions.
    data: { destination: message.destination },
  };
}

type StoredDocument = Omit<StoredPush, "createdAt" | "retryClaimedAt"> & {
  createdAt: Timestamp;
  retryClaimedAt?: Timestamp;
};

function storedFrom(data: FirebaseFirestore.DocumentData): StoredPush {
  const { retryClaimedAt, ...document } = data as StoredDocument;
  return {
    ...document,
    createdAt: document.createdAt.toDate(),
    ...(retryClaimedAt ? { retryClaimedAt: retryClaimedAt.toDate() } : {}),
  };
}

export function firebasePushPorts(
  db: Firestore,
  auth: Auth,
  messaging: Messaging,
): PushPorts {
  const history = db.collection(PUSH_HISTORY_COLLECTION);
  return {
    gateway: {
      async sendToTopic(topic, message, dryRun) {
        await messaging.send({ topic, ...payload(message) }, dryRun);
      },
      async sendToTokens(tokens, message, dryRun) {
        const response = await messaging.sendEachForMulticast(
          { tokens, ...payload(message) },
          dryRun,
        );
        return { delivered: response.successCount, failed: response.failureCount };
      },
    },
    customers: {
      async uidByEmail(email) {
        try {
          return (await auth.getUserByEmail(email)).uid;
        } catch (error) {
          if ((error as { code?: string }).code === USER_NOT_FOUND) return null;
          throw error;
        }
      },
      async deviceTokens(uid) {
        const devices = await db
          .collection("users")
          .doc(uid)
          .collection(DEVICES_SUBCOLLECTION)
          .get();
        return devices.docs
          .map((device) => device.get("token") as unknown)
          .filter((token): token is string => typeof token === "string");
      },
    },
    history: {
      async add(record) {
        return (await history.add(record)).id;
      },
      claimRetry(id, now) {
        const reference = history.doc(id);
        return db.runTransaction(async (transaction) => {
          const data = (await transaction.get(reference)).data();
          if (!data) return null;
          const stored = storedFrom(data);
          if (!canClaimRetry(stored, now)) return null;
          const claim = { status: "retrying" as const, retryClaimedAt: now };
          transaction.update(reference, claim);
          return { ...stored, ...claim };
        });
      },
      async update(id, patch) {
        await history.doc(id).update(patch);
      },
    },
  };
}

/** The most recent sends, newest first, for the history table. */
export async function latestPushes(
  db: Firestore,
  limit: number,
): Promise<PushRecord[]> {
  const snapshot = await db
    .collection(PUSH_HISTORY_COLLECTION)
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();
  return snapshot.docs.map((document) =>
    pushRecordOf(document.id, storedFrom(document.data())),
  );
}
