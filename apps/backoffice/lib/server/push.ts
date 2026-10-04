import type { Admin } from "./session";
import type { ServerSettings } from "./settings";

/** Push notifications sent from the console, and the record kept of each. */

export const TITLE_MAX_LENGTH = 65;
export const BODY_MAX_LENGTH = 240;

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

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

export type PushValidation =
  | { ok: true; draft: PushDraft }
  | { ok: false; fields: PushField[] };

/** `validated` is a dry run the service accepted: nothing was delivered. */
export type PushStatus = "sent" | "validated" | "failed";

export interface PushMessage {
  title: string;
  body: string;
  destination: string;
}

/** Who a stored send was for. A customer is kept by uid, never by address. */
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
  attempts: number;
  sentBy: string;
  dryRun: boolean;
}

/** What the history table shows. */
export interface PushRecord {
  id: string;
  createdAt: string;
  title: string;
  audienceLabel: string;
  status: PushStatus;
  error: string | null;
}

export interface PushPorts {
  gateway: {
    sendToTopic(topic: string, message: PushMessage, dryRun: boolean): Promise<void>;
    sendToTokens(
      tokens: string[],
      message: PushMessage,
      dryRun: boolean,
    ): Promise<{ delivered: number; failed: number }>;
  };
  customers: {
    uidByEmail(email: string): Promise<string | null>;
    deviceTokens(uid: string): Promise<string[]>;
  };
  history: {
    add(record: StoredPush): Promise<string>;
    get(id: string): Promise<StoredPush | null>;
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

function errorCode(error: unknown): string {
  const code = (error as { code?: unknown } | null)?.code;
  return typeof code === "string" ? code : "unknown";
}

interface Attempt {
  status: PushStatus;
  error: string | null;
}

async function deliver(
  ports: PushPorts,
  settings: PushSettings,
  audience: StoredAudience,
  message: PushMessage,
): Promise<Attempt> {
  const delivered: Attempt = {
    status: settings.pushDryRun ? "validated" : "sent",
    error: null,
  };
  const failed = (error: string): Attempt => ({ status: "failed", error });

  try {
    if (audience.kind === "segment") {
      await ports.gateway.sendToTopic(
        segmentTopic(audience.segmentId),
        message,
        settings.pushDryRun,
      );
      return delivered;
    }

    if (!audience.uid) return failed("customer-not-found");
    const tokens = await ports.customers.deviceTokens(audience.uid);
    if (tokens.length === 0) return failed("no-registered-device");
    const outcome = await ports.gateway.sendToTokens(
      tokens,
      message,
      settings.pushDryRun,
    );
    return outcome.delivered > 0 ? delivered : failed("no-device-accepted");
  } catch (error) {
    return failed(errorCode(error));
  }
}

function recordOf(id: string, stored: StoredPush): PushRecord {
  return {
    id,
    createdAt: stored.createdAt.toISOString(),
    title: stored.title,
    audienceLabel: stored.audienceLabel,
    status: stored.status,
    error: stored.error,
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
      : {
          kind: "customer",
          uid: await ports.customers.uidByEmail(draft.audience.email),
        };
  const message: PushMessage = {
    title: draft.title,
    body: draft.body,
    destination: draft.destination,
  };

  const attempt = await deliver(ports, settings, audience, message);
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
  return recordOf(await ports.history.add(stored), stored);
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
): Promise<PushRecord | null> {
  const stored = await ports.history.get(id);
  if (!stored || stored.status !== "failed") return null;

  const attempt = await deliver(ports, settings, stored.audience, {
    title: stored.title,
    body: stored.body,
    destination: stored.destination,
  });
  const patch = {
    ...attempt,
    attempts: stored.attempts + 1,
    dryRun: settings.pushDryRun,
  };
  await ports.history.update(id, patch);
  return recordOf(id, { ...stored, ...patch });
}
