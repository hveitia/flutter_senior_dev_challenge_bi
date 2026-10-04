// The document the publish tool writes to `config/home`, and its form for
// the Firestore REST API. Pure functions, so they are tested without a
// backend.
import { fileURLToPath } from 'node:url';

/** The contract example at the root of the repository. */
export const CONTRACT_EXAMPLE = fileURLToPath(
  new URL('../../contracts/home-config.example.json', import.meta.url),
);

/** The most latency the contract lets the resilience lab inject. */
export const MAX_LATENCY_MS = 10000;

function wholeNumberUpTo(value, max, name) {
  if (!Number.isInteger(value) || value < 0 || value > max) {
    throw new RangeError(
      `${name} must be a whole number between 0 and ${max}, got ${value}`,
    );
  }
  return value;
}

/**
 * The document to publish: [base] with the overrides that were asked for.
 * [base] is not changed. An override left undefined keeps what [base] has.
 */
export function buildConfigDocument(
  base,
  { latencyMs, movementsUnavailable, configVersion },
) {
  const document = structuredClone(base);

  if (configVersion !== undefined) {
    document.configVersion = wholeNumberUpTo(
      configVersion,
      Number.MAX_SAFE_INTEGER,
      'configVersion',
    );
  }
  if (latencyMs !== undefined) {
    document.resilience.latencyMs = wholeNumberUpTo(
      latencyMs,
      MAX_LATENCY_MS,
      'latencyMs',
    );
  }
  if (movementsUnavailable !== undefined) {
    document.resilience.movementsUnavailable = movementsUnavailable;
  }
  return document;
}

/** A JSON value as the Firestore REST API expects it. */
function firestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreValue) } };
  }
  if (Object.getPrototypeOf(value) === Object.prototype) {
    return { mapValue: { fields: toFirestoreFields(value) } };
  }
  throw new TypeError(`unsupported value: ${String(value)}`);
}

/** The fields of [document] as the Firestore REST API expects them. */
export function toFirestoreFields(document) {
  return Object.fromEntries(
    Object.entries(document).map(([field, value]) => [
      field,
      firestoreValue(value),
    ]),
  );
}
