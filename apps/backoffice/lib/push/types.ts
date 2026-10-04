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
 * `retrying` is a failed send that someone is sending again right now.
 */
export type PushStatus = "sent" | "validated" | "failed" | "retrying";

/** What the history table shows. */
export interface PushRecord {
  id: string;
  createdAt: string;
  title: string;
  audienceLabel: string;
  status: PushStatus;
  error: string | null;
}
