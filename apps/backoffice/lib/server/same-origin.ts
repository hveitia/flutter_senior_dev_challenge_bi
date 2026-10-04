import "server-only";

/**
 * Cross-site request forgery guard for route handlers that change state.
 * Server Actions get the same comparison from the framework; route handlers
 * do not, so they call this. Unlike the framework, a request without an
 * `Origin` header is rejected: browsers always send it on a cross-site POST,
 * and nothing legitimate calls these routes without one.
 */
export function isSameOrigin(request: Request): boolean {
  const origin = request.headers.get("origin");
  const host =
    request.headers.get("x-forwarded-host") ?? request.headers.get("host");
  if (!origin || !host) return false;
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}
