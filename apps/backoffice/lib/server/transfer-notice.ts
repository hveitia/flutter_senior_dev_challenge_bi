import "server-only";
import type { InboxItem, PushPorts } from "./push";
import type { ProcessResult } from "./transfers";

/**
 * What the customer is told when one of their transfers is carried out.
 *
 * It names no amount, account or reference: a push can be read on a locked
 * screen. The detail is in the movements the notice leads to.
 */
export const TRANSFER_NOTICE = {
  title: "Transferencia realizada",
  body: "Tu transferencia entre cuentas se completó. Revisa el detalle en tus movimientos.",
  destination: "accounts",
} as const;

/** The part of the notifications ports a transfer notice needs. */
export type NoticePorts = Pick<PushPorts, "gateway" | "customers" | "inbox">;

/** Which step of a notice failed. Reported without the error's content. */
export type NoticeStep = "inbox" | "push";

/**
 * The inbox id of a transfer's notice. Tied to the transfer, so telling the
 * customer twice about the same one writes the same document.
 */
export function noticeIdOf(transferId: string): string {
  return `transfer-${transferId}`;
}

/**
 * Whether settling a transfer calls for a notice: only when this call is the
 * one that completed it. A replay answers what was already said, and the
 * customer was told the first time.
 */
export function shouldNotify(result: ProcessResult): boolean {
  return (
    result.kind === "settled" && !result.replayed && result.transfer.status === "completed"
  );
}

/**
 * Files the notice in the customer's inbox and, when delivery is live,
 * announces it on their devices.
 *
 * It never throws and is not part of the transfer: the money has already
 * moved and the app has its answer. A step that fails is reported by name
 * through [report] and the other one is still tried.
 */
export async function notifyTransferCompleted(
  ports: NoticePorts,
  settings: { pushDryRun: boolean },
  uid: string,
  transferId: string,
  now: Date,
  report: (step: NoticeStep) => void,
): Promise<void> {
  const item: InboxItem = {
    title: TRANSFER_NOTICE.title,
    body: TRANSFER_NOTICE.body,
    kind: "movement",
    destination: TRANSFER_NOTICE.destination,
    createdAt: now,
    read: false,
  };

  try {
    await ports.inbox.deliver([uid], noticeIdOf(transferId), item);
  } catch {
    report("inbox");
  }

  // Without live delivery nothing is announced: the inbox item is the notice.
  if (settings.pushDryRun) return;

  try {
    const tokens = await ports.customers.deviceTokens(uid);
    if (tokens.length === 0) return;

    const sent = await ports.gateway.sendToTokens(tokens, { ...TRANSFER_NOTICE }, false);
    if (sent.unregistered.length > 0) {
      await ports.customers.flagUnregistered(uid, sent.unregistered, now);
    }
  } catch {
    report("push");
  }
}
