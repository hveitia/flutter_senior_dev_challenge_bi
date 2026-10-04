import "server-only";
import type { Messaging } from "firebase-admin/messaging";

/**
 * The part of the messaging service the console uses, answered on the spot.
 *
 * A local stack has no credentials for the messaging service, and even a
 * validated send would need them. This stands in for it: every send is
 * accepted as a dry run and nothing leaves the machine. It refuses anything
 * that is not a dry run, so it can never pass for a delivery.
 */
type OfflineMessaging = Pick<Messaging, "send" | "sendEachForMulticast">;

const NOT_A_DRY_RUN = "A local stack only validates notifications (dry run); it delivers none.";

export function offlineMessaging(): OfflineMessaging {
  let sent = 0;
  const nextId = () => `local-${++sent}`;
  return {
    async send(_message, dryRun) {
      if (!dryRun) throw new Error(NOT_A_DRY_RUN);
      return nextId();
    },
    async sendEachForMulticast(message, dryRun) {
      if (!dryRun) throw new Error(NOT_A_DRY_RUN);
      const devices = "tokens" in message ? message.tokens : message.fids;
      const responses = devices.map(() => ({ success: true, messageId: nextId() }));
      return { responses, successCount: responses.length, failureCount: 0 };
    },
  };
}
