import "server-only";
import { after } from "next/server";
import { adminAuth, adminDb, adminMessaging, serverSettings } from "./firebase";
import { firebasePushPorts } from "./push-store";
import { notifyTransferCompleted, shouldNotify, type NoticeStep } from "./transfer-notice";
import type { ProcessResult } from "./transfers";

/**
 * Tells the customer that a transfer was carried out, once the answer to the
 * app has been sent.
 *
 * `after` runs it when the response is done, so the notice can neither delay
 * the transfer's answer nor change it. A step that fails leaves one log line
 * naming the step and nothing about the customer or the transfer.
 */
export function announceSettled(
  result: ProcessResult,
  uid: string,
  transferId: string,
  now: Date,
): void {
  if (!shouldNotify(result)) return;

  // The money has moved and the answer is ready: failing to schedule the
  // notice must not turn that answer into an error.
  try {
    after(() =>
      notifyTransferCompleted(
        firebasePushPorts(adminDb(), adminAuth(), adminMessaging()),
        serverSettings(),
        uid,
        transferId,
        now,
        reportFailedStep,
      ),
    );
  } catch {
    reportFailedStep("schedule");
  }
}

function reportFailedStep(step: NoticeStep | "schedule"): void {
  console.error(JSON.stringify({ event: "transfer_notice_failed", step }));
}
