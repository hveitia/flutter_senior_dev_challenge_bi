import "server-only";
import type { ServerSettings } from "./settings";

/**
 * Administrator sessions. The browser signs in with the identity provider and
 * hands its short-lived token to the server once; from then on the server
 * trusts only an HTTP-only cookie it issued and re-verifies on every request.
 */

export const SESSION_COOKIE = "__session";

const HOUR_MS = 60 * 60 * 1000;
export const SESSION_MAX_AGE_MS = 8 * HOUR_MS;

/** A stolen old token must not be enough to open a session. */
export const RECENT_SIGN_IN_SECONDS = 5 * 60;

export interface Admin {
  uid: string;
  email: string;
}

/** The claims this module reads from a verified token or cookie. */
export interface DecodedToken {
  uid: string;
  email?: string;
  email_verified?: boolean;
  auth_time: number;
}

/** The part of the identity provider's admin API that sessions need. */
export interface AuthPort {
  verifyIdToken(idToken: string, checkRevoked: boolean): Promise<DecodedToken>;
  createSessionCookie(
    idToken: string,
    options: { expiresIn: number },
  ): Promise<string>;
  verifySessionCookie(cookie: string, checkRevoked: boolean): Promise<DecodedToken>;
  revokeRefreshTokens(uid: string): Promise<void>;
}

/** The value of one cookie in a `Cookie` request header. */
export function cookieFrom(header: string | null, name: string): string | undefined {
  if (!header) return undefined;
  for (const pair of header.split(";")) {
    const separator = pair.indexOf("=");
    if (separator !== -1 && pair.slice(0, separator).trim() === name) {
      return pair.slice(separator + 1).trim();
    }
  }
  return undefined;
}

/**
 * Ends the administrator's sessions on the server, not only on this browser:
 * every cookie issued to them so far stops verifying, including one copied
 * before they signed out. Returns whether the revocation happened.
 */
export async function endSession(
  auth: AuthPort,
  cookie: string | undefined,
): Promise<boolean> {
  if (!cookie) return false;
  try {
    const decoded = await auth.verifySessionCookie(cookie, true);
    await auth.revokeRefreshTokens(decoded.uid);
    return true;
  } catch {
    return false;
  }
}

export type AdmissionFailure = "invalid" | "not-allowed" | "unverified" | "stale";

export type SessionResult =
  | { ok: true; cookie: string; admin: Admin }
  | { ok: false; reason: AdmissionFailure };

type Admission = { ok: true; admin: Admin } | { ok: false; reason: AdmissionFailure };

/**
 * Registration in the mobile app is open, so an address alone proves nothing:
 * anyone could register an administrator's address before its owner does.
 * Only a verified address on the allow-list is admitted.
 */
function admit(decoded: DecodedToken, settings: ServerSettings): Admission {
  const email = decoded.email?.toLowerCase();
  if (!email || !settings.adminEmails.has(email)) {
    return { ok: false, reason: "not-allowed" };
  }
  if (decoded.email_verified !== true) {
    return { ok: false, reason: "unverified" };
  }
  return { ok: true, admin: { uid: decoded.uid, email } };
}

/** Exchanges a fresh identity token for a session cookie. */
export async function createSession(
  auth: AuthPort,
  settings: ServerSettings,
  idToken: string,
  nowSeconds: number,
): Promise<SessionResult> {
  let decoded: DecodedToken;
  try {
    decoded = await auth.verifyIdToken(idToken, true);
  } catch {
    return { ok: false, reason: "invalid" };
  }

  const admission = admit(decoded, settings);
  if (!admission.ok) return admission;

  if (nowSeconds - decoded.auth_time > RECENT_SIGN_IN_SECONDS) {
    return { ok: false, reason: "stale" };
  }

  try {
    const cookie = await auth.createSessionCookie(idToken, {
      expiresIn: SESSION_MAX_AGE_MS,
    });
    return { ok: true, cookie, admin: admission.admin };
  } catch {
    return { ok: false, reason: "invalid" };
  }
}

/**
 * The administrator a cookie belongs to, or null. The allow-list is checked
 * again here, so removing an address takes effect on that person's next
 * request rather than when their cookie expires.
 */
export async function adminFromCookie(
  auth: AuthPort,
  settings: ServerSettings,
  cookie: string | undefined,
): Promise<Admin | null> {
  if (!cookie) return null;
  try {
    const decoded = await auth.verifySessionCookie(cookie, true);
    const admission = admit(decoded, settings);
    return admission.ok ? admission.admin : null;
  } catch {
    return null;
  }
}
