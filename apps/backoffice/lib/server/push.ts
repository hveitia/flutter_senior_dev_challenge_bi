import "server-only";
import {
  BODY_MAX_LENGTH,
  TITLE_MAX_LENGTH,
  type PushAudience,
  type PushDraft,
  type PushField,
  type PushRecord,
  type PushStatus,
} from "@/lib/push/types";
import type { Admin } from "./session";
import type { ServerSettings } from "./settings";

/** Push notifications sent from the console, and the record kept of each. */

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export type PushValidation =
  | { ok: true; draft: PushDraft }
  | { ok: false; fields: PushField[] };

export interface PushMessage {
  title: string;
  body: string;
  destination: string;
}

/**
 * Who a stored send was for. A customer is kept by uid, never by address,
 * and with no uid at all when the send could not reach anyone.
 */
export type StoredAudience =
  | { kind: "segment"; segmentId: string }
  | { kind: "customer"; uid: string | null };

export interface StoredPush {
  createdAt: Date;
  title: string;
  body: string;
  destination: string;
  audience: StoredAudience;
  audienceLabel: string;
  status: PushStatus;
  error: string | null;
  /** Devices reached and not reached; null for a send to a segment. */
  deliveredCount?: number | null;
  failedCount?: number | null;
  attempts: number;
  sentBy: string;
  dryRun: boolean;
  /** When the retry in progress was claimed; set only while `retrying`. */
  retryClaimedAt?: Date;
}

/** Stored and shown when a send to one person could not reach anyone. */
const UNREACHABLE = "customer-unreachable";

/** Whether the record still says who to send to. */
function isAddressable(audience: StoredAudience): boolean {
  return audience.kind === "segment" || audience.uid !== null;
}

/**
 * How long a retry may stay claimed. A server that died between claiming and
 * recording the outcome would otherwise leave the record unretryable for good.
 */
export const RETRY_CLAIM_TTL_MS = 2 * 60 * 1000;

/** Whether a record can be claimed for a retry at `now`. */
export function canClaimRetry(stored: StoredPush, now: Date): boolean {
  if (!isAddressable(stored.audience)) return false;
  if (stored.status === "failed") return true;
  if (stored.status !== "retrying" || !stored.retryClaimedAt) return false;
  return now.getTime() - stored.retryClaimedAt.getTime() > RETRY_CLAIM_TTL_MS;
}

export interface PushPorts {
  gateway: {
    sendToTopic(topic: string, message: PushMessage, dryRun: boolean): Promise<void>;
    sendToTokens(
      tokens: string[],
      message: PushMessage,
      dryRun: boolean,
    ): Promise<{
      delivered: number;
      failed: number;
      /** Tokens the service says belong to no installed app any more. */
      unregistered: string[];
    }>;
  };
  customers: {
    uidByEmail(email: string): Promise<string | null>;
    /** Tokens of the customer's devices, leaving out the flagged ones. */
    deviceTokens(uid: string): Promise<string[]>;
    /** Marks devices as unregistered. It never deletes them. */
    flagUnregistered(uid: string, tokens: string[], now: Date): Promise<void>;
  };
  history: {
    add(record: StoredPush): Promise<string>;
    /**
     * Atomically marks a record as being retried and returns it, or returns
     * null when `canClaimRetry` says it cannot be retried now.
     */
    claimRetry(id: string, now: Date): Promise<StoredPush | null>;
    update(id: string, patch: Partial<StoredPush>): Promise<void>;
  };
}

type PushSettings = Pick<ServerSettings, "pushDryRun">;

/** Topic the mobile app subscribes to for its customer's segment. */
export function segmentTopic(segmentId: string): string {
  return `segment-${segmentId}`;
}

function textWithin(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function audienceFrom(value: unknown, segmentIds: string[]): PushAudience | null {
  if (typeof value !== "object" || value === null) return null;
  const { kind, segmentId, email } = value as Record<string, unknown>;
  if (kind === "segment" && typeof segmentId === "string") {
    return segmentIds.includes(segmentId) ? { kind, segmentId } : null;
  }
  if (kind === "customer" && typeof email === "string") {
    const address = email.trim().toLowerCase();
    return EMAIL.test(address) ? { kind, email: address } : null;
  }
  return null;
}

/** Checks what the composer sent, naming every field that is wrong. */
export function validatePushDraft(
  input: unknown,
  allowedDestinations: string[],
  segmentIds: string[],
): PushValidation {
  const raw = (typeof input === "object" && input !== null ? input : {}) as Record<
    string,
    unknown
  >;
  const title = textWithin(raw.title, TITLE_MAX_LENGTH);
  const body = textWithin(raw.body, BODY_MAX_LENGTH);
  const audience = audienceFrom(raw.audience, segmentIds);
  const destination =
    typeof raw.destination === "string" &&
    allowedDestinations.includes(raw.destination)
      ? raw.destination
      : null;

  if (title && body && audience && destination) {
    return { ok: true, draft: { title, body, audience, destination } };
  }
  const fields: PushField[] = [];
  if (!title) fields.push("title");
  if (!body) fields.push("body");
  if (!audience) fields.push("audience");
  if (!destination) fields.push("destination");
  return { ok: false, fields };
}

const TOKEN_NOT_REGISTERED = "messaging/registration-token-not-registered";

/**
 * The tokens whose send failed because the app is no longer installed, given
 * the per-token error codes in the order the tokens were sent.
 */
export function unregisteredAmong(
  tokens: string[],
  errorCodes: (string | undefined)[],
): string[] {
  return tokens.filter((_, index) => errorCodes[index] === TOKEN_NOT_REGISTERED);
}

function errorCode(error: unknown): string {
  const code = (error as { code?: unknown } | null)?.code;
  return typeof code === "string" ? code : "unknown";
}

interface Attempt {
  status: PushStatus;
  error: string | null;
  /** Devices reached and not reached; null when the send was not per device. */
  deliveredCount: number | null;
  failedCount: number | null;
}

async function deliver(
  ports: PushPorts,
  settings: PushSettings,
  audience: StoredAudience,
  message: PushMessage,
  now: Date,
): Promise<Attempt> {
  const accepted: PushStatus = settings.pushDryRun ? "validated" : "sent";
  const failed = (error: string): Attempt => ({
    status: "failed",
    error,
    deliveredCount: null,
    failedCount: null,
  });

  try {
    if (audience.kind === "segment") {
      await ports.gateway.sendToTopic(
        segmentTopic(audience.segmentId),
        message,
        settings.pushDryRun,
      );
      // A topic send says nothing about how many devices it reached.
      return { status: accepted, error: null, deliveredCount: null, failedCount: null };
    }

    if (!audience.uid) return failed(UNREACHABLE);
    const tokens = await ports.customers.deviceTokens(audience.uid);
    if (tokens.length === 0) return failed(UNREACHABLE);
    const outcome = await ports.gateway.sendToTokens(
      tokens,
      message,
      settings.pushDryRun,
    );
    await flagUnregistered(ports, audience.uid, outcome.unregistered, now);

    const counts = { deliveredCount: outcome.delivered, failedCount: outcome.failed };
    if (outcome.delivered === 0) {
      return { status: "failed", error: "no-device-accepted", ...counts };
    }
    // Reaching some devices is not the same as reaching the customer's
    // devices, and the history must not read as if it were. In a dry run
    // nothing was delivered either way, so the counts carry the detail.
    const partial = outcome.failed > 0 && !settings.pushDryRun;
    return { status: partial ? "partial" : accepted, error: null, ...counts };
  } catch (error) {
    return failed(errorCode(error));
  }
}

/**
 * Marks the devices the service no longer knows, so the app or a clean-up job
 * can remove them. Best effort: the send already happened, and failing to
 * flag a device must not turn it into a failed send.
 */
async function flagUnregistered(
  ports: PushPorts,
  uid: string,
  tokens: string[],
  now: Date,
): Promise<void> {
  if (tokens.length === 0) return;
  try {
    await ports.customers.flagUnregistered(uid, tokens, now);
  } catch {
    // The same tokens are reported again on the next send to this customer.
  }
}

/**
 * The customer behind an address, only if a notification can reach them.
 * An address that is not a customer and a customer without a device give the
 * same answer, and so the same record: the history must not tell an
 * administrator which addresses belong to customers.
 */
async function reachableUid(ports: PushPorts, email: string): Promise<string | null> {
  const uid = await ports.customers.uidByEmail(email);
  if (!uid) return null;
  const tokens = await ports.customers.deviceTokens(uid);
  return tokens.length > 0 ? uid : null;
}

export function pushRecordOf(id: string, stored: StoredPush): PushRecord {
  return {
    retryable: stored.status === "failed" && isAddressable(stored.audience),
    id,
    createdAt: stored.createdAt.toISOString(),
    title: stored.title,
    audienceLabel: stored.audienceLabel,
    status: stored.status,
    error: stored.error,
    deliveredCount: stored.deliveredCount ?? null,
    failedCount: stored.failedCount ?? null,
  };
}

/**
 * Sends a notification and records the outcome, whatever it is: a failed
 * send is a row in the history, not an exception.
 */
export async function sendPush(
  ports: PushPorts,
  settings: PushSettings,
  admin: Admin,
  now: Date,
  draft: PushDraft,
  audienceLabel: string,
): Promise<PushRecord> {
  const audience: StoredAudience =
    draft.audience.kind === "segment"
      ? draft.audience
      : { kind: "customer", uid: await reachableUid(ports, draft.audience.email) };
  const message: PushMessage = {
    title: draft.title,
    body: draft.body,
    destination: draft.destination,
  };

  const attempt = await deliver(ports, settings, audience, message, now);
  const stored: StoredPush = {
    createdAt: now,
    ...message,
    audience,
    audienceLabel,
    ...attempt,
    attempts: 1,
    sentBy: admin.email,
    dryRun: settings.pushDryRun,
  };
  return pushRecordOf(await ports.history.add(stored), stored);
}

/**
 * Sends a failed notification again, updating its record. Returns null when
 * there is nothing to retry, so a notification that went out is never
 * delivered twice.
 */
export async function retryPush(
  ports: PushPorts,
  settings: PushSettings,
  id: string,
  now: Date,
): Promise<PushRecord | null> {
  // Claimed before sending: of two clicks, or two administrators, only the
  // one whose claim lands goes on to deliver.
  const stored = await ports.history.claimRetry(id, now);
  if (!stored) return null;

  const attempt = await deliver(
    ports,
    settings,
    stored.audience,
    { title: stored.title, body: stored.body, destination: stored.destination },
    now,
  );
  const patch = {
    ...attempt,
    attempts: stored.attempts + 1,
    dryRun: settings.pushDryRun,
  };
  await ports.history.update(id, patch);
  return pushRecordOf(id, { ...stored, ...patch });
}
