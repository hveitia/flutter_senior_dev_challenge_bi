import "server-only";

/**
 * What every route of the customer API shares: reading a small JSON body
 * without trusting its size or shape, answering with a stable code, and
 * leaving one log line per request that says what happened and nothing about
 * whose money it was.
 */

/** Largest body a route reads. A transfer order is a few hundred bytes. */
export const MAX_BODY_BYTES = 2048;

/** Codes the app can switch on. The text a customer sees is the app's. */
export type ApiErrorCode =
  | "unauthorized"
  | "invalid-request"
  | "invalid-json"
  | "unsupported-media-type"
  | "payload-too-large"
  | "transfer-not-found"
  | "idempotency-key-reused"
  | "transfer-rejected"
  | "profile-required"
  | "unavailable"
  | "internal";

export interface ApiAnswer {
  status: number;
  body: object;
  /** Goes to the log: a code, never data. */
  outcome: string;
}

export type JsonBody =
  | { ok: true; body: Record<string, unknown> }
  | { ok: false; error: "unsupported-media-type" | "payload-too-large" | "invalid-json" };

export interface ApiLogEntry {
  level: "info" | "error";
  requestId: string;
  route: string;
  status: number;
  outcome: string;
  durationMs: number;
}

export interface ApiRuntime {
  log(entry: ApiLogEntry): void;
  now(): number;
  newRequestId(): string;
}

const STATUS: Record<ApiErrorCode, number> = {
  "invalid-request": 400,
  "invalid-json": 400,
  unauthorized: 401,
  "transfer-not-found": 404,
  "idempotency-key-reused": 409,
  "payload-too-large": 413,
  "unsupported-media-type": 415,
  "transfer-rejected": 422,
  "profile-required": 422,
  internal: 500,
  unavailable: 503,
};

/** An error answer: the code, plus whatever the app needs to act on it. */
export function failure(code: ApiErrorCode, extra: object = {}): ApiAnswer {
  return { status: STATUS[code], body: { error: code, ...extra }, outcome: code };
}

const JSON_CONTENT_TYPE = /^application\/json\s*(;|$)/i;

/**
 * The bytes of a body, or null once it passes the limit. The body is read as
 * it arrives and abandoned at the limit: a length the client announces is
 * only a hint, and a body that announces none can be of any size.
 */
async function readBytes(request: Request, maxBytes: number): Promise<Uint8Array | null> {
  const announced = Number(request.headers.get("content-length"));
  if (Number.isFinite(announced) && announced > maxBytes) return null;
  if (!request.body) return new Uint8Array();

  const reader = request.body.getReader();
  const bytes = new Uint8Array(maxBytes);
  let length = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) return bytes.subarray(0, length);
    if (length + value.length > maxBytes) {
      await reader.cancel();
      return null;
    }
    bytes.set(value, length);
    length += value.length;
  }
}

/**
 * Reads the body of a request as a JSON object, and as nothing else: not a
 * list, not a bare value, not text in another encoding or under another
 * content type.
 */
export async function readJsonObject(
  request: Request,
  maxBytes: number = MAX_BODY_BYTES,
): Promise<JsonBody> {
  if (!JSON_CONTENT_TYPE.test(request.headers.get("content-type") ?? "")) {
    return { ok: false, error: "unsupported-media-type" };
  }
  const bytes = await readBytes(request, maxBytes);
  if (!bytes) return { ok: false, error: "payload-too-large" };

  try {
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    const body: unknown = JSON.parse(text);
    if (typeof body === "object" && body !== null && !Array.isArray(body)) {
      return { ok: true, body: body as Record<string, unknown> };
    }
  } catch {
    // Not UTF-8, or not JSON: the same answer either way.
  }
  return { ok: false, error: "invalid-json" };
}

/**
 * Status codes of the database client for trouble that passes: unreachable,
 * too slow, or a transaction that kept losing to others. The app may send
 * the same request again; everything here is idempotent.
 */
const TRANSIENT_DATABASE_CODES: readonly unknown[] = [4, 10, 14];

/**
 * What an unexpected error becomes. The log gets its kind and nothing from
 * its message, which can name a document path and with it a customer.
 */
function unexpected(error: unknown): ApiAnswer {
  const code = (error as { code?: unknown } | null)?.code;
  if (TRANSIENT_DATABASE_CODES.includes(code)) {
    return { ...failure("unavailable"), outcome: `unavailable:${String(code)}` };
  }
  const kind = error instanceof Error ? error.name : typeof error;
  return { ...failure("internal"), outcome: `internal:${kind}` };
}

const SERVER_ERROR = 500;

const defaultRuntime: ApiRuntime = {
  log(entry) {
    const line = JSON.stringify(entry);
    if (entry.level === "error") console.error(line);
    else console.info(line);
  },
  now: () => Date.now(),
  newRequestId: () => crypto.randomUUID(),
};

/**
 * Runs one route: gives it a request id, turns whatever it returns or throws
 * into a response that is never cached, and writes the single log line of the
 * request. The line holds the route, the status, an outcome code and the time
 * taken; no customer, account or amount ever reaches it.
 */
export async function handleApi(
  route: string,
  run: (requestId: string) => Promise<ApiAnswer>,
  runtime: ApiRuntime = defaultRuntime,
): Promise<Response> {
  const requestId = runtime.newRequestId();
  const startedAt = runtime.now();

  let answer: ApiAnswer;
  try {
    answer = await run(requestId);
  } catch (error) {
    answer = unexpected(error);
  }

  runtime.log({
    level: answer.status >= SERVER_ERROR ? "error" : "info",
    requestId,
    route,
    status: answer.status,
    outcome: answer.outcome,
    durationMs: runtime.now() - startedAt,
  });

  return Response.json(answer.body, {
    status: answer.status,
    headers: { "x-request-id": requestId, "cache-control": "no-store" },
  });
}
