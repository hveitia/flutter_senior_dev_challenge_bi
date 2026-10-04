/**
 * Reading a transfer order from places the server does not trust: the body of
 * a request, and the pending document a phone wrote while offline.
 */
import {
  isTransferAmount,
  MAX_CONCEPT_LENGTH,
  type TransferOrder,
} from "./transfer";

/**
 * Chosen by the app and used as the idempotency key. Long enough not to be
 * guessed or to collide (a UUID fits), and safe as a document id.
 */
export const TRANSFER_ID_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;

/** An account id as the server writes them; never a path. */
export const ACCOUNT_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

export type ParsedTransferBody =
  | { ok: true; transferId: string; order: TransferOrder }
  | { ok: false; fields: string[] };

/** Line breaks and other control characters have no place in a one-line note. */
const CONTROL_CHARACTERS = /[\u0000-\u001f\u007f]/;

/** Everything a request body may carry, in the order errors are reported. */
const BODY_FIELDS = [
  "transferId",
  "fromAccountId",
  "toAccountId",
  "amountCents",
  "concept",
] as const;

export function isTransferId(value: unknown): value is string {
  return typeof value === "string" && TRANSFER_ID_PATTERN.test(value);
}

function isAccountId(value: unknown): value is string {
  return typeof value === "string" && ACCOUNT_ID_PATTERN.test(value);
}

/** The note as it will be stored, or null when it cannot be accepted. */
function conceptFrom(value: unknown): string | null {
  if (value === undefined) return "";
  if (typeof value !== "string") return null;
  const concept = value.trim();
  if (concept.length > MAX_CONCEPT_LENGTH) return null;
  return CONTROL_CHARACTERS.test(concept) ? null : concept;
}

/**
 * Reads the body of `POST /api/transfers`. Strict on purpose: every wrong
 * field is named, and a field the server does not know is an error rather
 * than something silently dropped, so a client that believes it sent a
 * customer id or a status finds out it cannot.
 */
export function parseTransferBody(
  body: Record<string, unknown>,
): ParsedTransferBody {
  // Each value is either accepted or null; a null names its field below.
  const transferId = isTransferId(body.transferId) ? body.transferId : null;
  const fromAccountId = isAccountId(body.fromAccountId)
    ? body.fromAccountId
    : null;
  const toAccountId =
    isAccountId(body.toAccountId) && body.toAccountId !== body.fromAccountId
      ? body.toAccountId
      : null;
  const amountCents = isTransferAmount(body.amountCents)
    ? body.amountCents
    : null;
  const concept = conceptFrom(body.concept);

  const known: readonly string[] = BODY_FIELDS;
  const unknown = Object.keys(body).filter((key) => !known.includes(key));

  if (
    transferId === null ||
    fromAccountId === null ||
    toAccountId === null ||
    amountCents === null ||
    concept === null ||
    unknown.length > 0
  ) {
    const read = { transferId, fromAccountId, toAccountId, amountCents, concept };
    return {
      ok: false,
      fields: [...BODY_FIELDS.filter((field) => read[field] === null), ...unknown],
    };
  }
  return {
    ok: true,
    transferId,
    order: { fromAccountId, toAccountId, amountCents, concept },
  };
}

/**
 * Reads the order out of a pending document written by a phone. Only its
 * shape is checked here: whether the amount or the accounts make sense is
 * for the decision, which records the reason. Null means the document is
 * not an order at all.
 */
export function orderFromStored(data: unknown): TransferOrder | null {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    return null;
  }
  const { fromAccountId, toAccountId, amountCents, concept } = data as Record<
    string,
    unknown
  >;
  if (!isAccountId(fromAccountId) || !isAccountId(toAccountId)) return null;
  if (typeof amountCents !== "number") return null;
  // The same reading as a request body, so an order queued on the phone and
  // the same order sent online are one order, and what reaches a movement
  // has no control characters.
  const note = conceptFrom(concept);
  if (note === null) return null;

  return { fromAccountId, toAccountId, amountCents, concept: note };
}
