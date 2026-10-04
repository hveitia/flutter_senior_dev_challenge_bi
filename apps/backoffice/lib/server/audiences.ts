import "server-only";
import type { Firestore } from "firebase-admin/firestore";

const CUSTOMERS_COLLECTION = "users";
const SEGMENT_FIELD = "segment";

/**
 * Registered customers per segment, counted by the database without reading
 * their profiles. A segment whose count fails is left out rather than shown
 * as zero.
 */
export async function countCustomers(
  db: Firestore,
  segmentIds: string[],
): Promise<Record<string, number>> {
  const counts = await Promise.all(
    segmentIds.map(async (segmentId) => {
      try {
        const snapshot = await db
          .collection(CUSTOMERS_COLLECTION)
          .where(SEGMENT_FIELD, "==", segmentId)
          .count()
          .get();
        return [segmentId, snapshot.data().count] as const;
      } catch {
        return null;
      }
    }),
  );
  return Object.fromEntries(counts.filter((entry) => entry !== null));
}
