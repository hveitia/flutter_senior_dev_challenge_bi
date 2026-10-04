/**
 * What the notification composer in the browser and the server agree on.
 * Nothing here touches a server API, so client components may import it.
 */

export const TITLE_MAX_LENGTH = 65;
export const BODY_MAX_LENGTH = 240;

export type PushAudience =
  | { kind: "segment"; segmentId: string }
  | { kind: "customer"; email: string };

export interface PushDraft {
  title: string;
  body: string;
  audience: PushAudience;
  destination: string;
}

export type PushField = keyof PushDraft;

/**
 * `validated` is a dry run the service accepted: nothing was delivered.
 * `partial` reached some of a customer's devices and not others.
 * `retrying` is a failed send that someone is sending again right now.
 */
export type PushStatus = "sent" | "partial" | "validated" | "failed" | "retrying";

/** What the history table shows. */
export interface PushRecord {
  id: string;
  createdAt: string;
  title: string;
  audienceLabel: string;
  status: PushStatus;
  error: string | null;
  /** Devices reached and not reached; null for a send to a segment. */
  deliveredCount: number | null;
  failedCount: number | null;
  /** Customers whose inbox received the notification; null when none was written. */
  inboxCount: number | null;
  /** The segment was larger than what one send files in inboxes. */
  inboxTruncated: boolean;
  /** The notification went out but its inbox items could not be stored. */
  inboxFailed: boolean;
  /** Whether the server would accept a retry of this send. */
  retryable: boolean;
}

/**
 * What the history says about the customers' inboxes for one send, or null
 * when the send never reached them (a dry run or a failed send).
 */
export function inboxNote(record: PushRecord): string | null {
  if (record.inboxFailed) return "Enviada. No se pudo guardar en la bandeja.";
  if (record.inboxCount === null) return null;
  if (record.inboxTruncated) {
    return `Enviada. Bandeja escrita para los primeros ${record.inboxCount} clientes.`;
  }
  return record.inboxCount === 1
    ? "En la bandeja de 1 cliente."
    : `En la bandeja de ${record.inboxCount} clientes.`;
}
