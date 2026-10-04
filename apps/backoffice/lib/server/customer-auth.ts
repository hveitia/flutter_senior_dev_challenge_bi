import "server-only";

/**
 * Who a mobile request acts for. The app sends the identity token of the
 * signed-in customer on every call; the customer id is read from that token
 * once it verifies, and from nowhere else.
 */

export interface Customer {
  uid: string;
}

/** The part of the identity provider's admin API this module needs. */
export interface TokenVerifier {
  verifyIdToken(idToken: string, checkRevoked: boolean): Promise<{ uid?: unknown }>;
}

/** Identity tokens are a couple of kilobytes; anything longer is not one. */
export const MAX_BEARER_LENGTH = 4096;

const BEARER = /^Bearer (\S+)$/i;

/** The token of an `Authorization: Bearer <token>` header, or null. */
function bearerToken(request: Request): string | null {
  const token = BEARER.exec(request.headers.get("authorization") ?? "")?.[1];
  return token && token.length <= MAX_BEARER_LENGTH ? token : null;
}

/**
 * The customer a request acts for, or null. Every failure looks the same to
 * the caller, so the answer never says whether a token was missing, expired,
 * revoked or forged.
 *
 * Cookies are not read at all: an administrator's console session opens
 * nothing here, and a customer's token opens nothing in the console, which
 * only reads its cookie.
 */
export async function customerFromRequest(
  auth: TokenVerifier,
  request: Request,
): Promise<Customer | null> {
  const token = bearerToken(request);
  if (!token) return null;
  try {
    // Revocation is checked on every call: a customer signed out everywhere,
    // or disabled, stops being able to move money at once.
    const { uid } = await auth.verifyIdToken(token, true);
    return typeof uid === "string" && uid.length > 0 ? { uid } : null;
  } catch {
    return null;
  }
}
