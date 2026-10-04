/**
 * How the partner mini apps answer over HTTP.
 *
 * These routes are public and have nothing to do with the console: no
 * administrator session, no cookie, no Firebase. They stand in for a third
 * party's own server, so they import nothing from the console's code.
 */

/** Largest request body a partner endpoint reads. */
export const MAX_BODY_BYTES = 2048;

const JSON_TYPE = "application/json";

/** Sent with every answer of a partner endpoint. */
const COMMON_HEADERS = {
  // An answer depends on what was asked and must never be reused.
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
  // The address of a partner page may carry nothing, and still is not
  // handed to any other site.
  "Referrer-Policy": "no-referrer",
} as const;

/**
 * The content security policy of a partner page.
 *
 * Everything is forbidden, then four things are allowed: the one inline
 * script and the one inline style that carry [nonce], requests to the
 * page's own origin, and nothing else. No frames in either direction, no
 * form posts, no plugins and no base address.
 */
export function pagePolicy(nonce: string): string {
  return [
    "default-src 'none'",
    `script-src 'nonce-${nonce}'`,
    `style-src 'nonce-${nonce}'`,
    "connect-src 'self'",
    "form-action 'none'",
    "base-uri 'none'",
    "frame-ancestors 'none'",
  ].join("; ");
}

/** A value used once per page, unguessable, safe inside an attribute. */
export function newNonce(): string {
  return crypto.randomUUID().replaceAll("-", "");
}

/** A short code a partner gives an operation: `SV-1A2B3C4D`. */
export function newReference(prefix: string): string {
  const code = crypto.randomUUID().replaceAll("-", "").slice(0, 8).toUpperCase();
  return `${prefix}-${code}`;
}

export function htmlResponse(html: string, nonce: string): Response {
  return new Response(html, {
    status: 200,
    headers: {
      ...COMMON_HEADERS,
      "Content-Type": "text/html; charset=utf-8",
      "Content-Security-Policy": pagePolicy(nonce),
    },
  });
}

export function jsonResponse(status: number, body: object): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...COMMON_HEADERS, "Content-Type": `${JSON_TYPE}; charset=utf-8` },
  });
}

export type BodyRead =
  | { ok: true; body: unknown }
  | { ok: false; status: 400 | 413 | 415; error: string };

/**
 * Reads a small JSON body. Anything that is not JSON, is declared as
 * something else or is larger than [MAX_BODY_BYTES] is refused before it is
 * parsed.
 */
export async function readJsonBody(request: Request): Promise<BodyRead> {
  const type = request.headers.get("content-type") ?? "";
  if (!type.toLowerCase().startsWith(JSON_TYPE)) {
    return { ok: false, status: 415, error: "unsupported-media-type" };
  }

  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) {
    return { ok: false, status: 413, error: "too-large" };
  }

  try {
    return { ok: true, body: JSON.parse(text) as unknown };
  } catch {
    return { ok: false, status: 400, error: "not-json" };
  }
}
