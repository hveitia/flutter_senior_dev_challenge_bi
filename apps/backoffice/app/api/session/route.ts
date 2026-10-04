import { NextResponse } from "next/server";
import { adminAuth, serverSettings } from "@/lib/server/firebase";
import { isSameOrigin } from "@/lib/server/same-origin";
import {
  createSession,
  SESSION_COOKIE,
  SESSION_MAX_AGE_MS,
} from "@/lib/server/session";

const MS_PER_SECOND = 1000;

const cookieOptions = {
  httpOnly: true,
  // Browsers treat localhost as secure; a plain-HTTP development server on
  // another host would otherwise never get its cookie back.
  secure: process.env.NODE_ENV === "production",
  sameSite: "strict",
  path: "/",
} as const;

function refused(status: 400 | 403): NextResponse {
  // One answer for every refusal: the caller learns nothing about which
  // addresses are administrators.
  return NextResponse.json({ error: "refused" }, { status });
}

async function readIdToken(request: Request): Promise<string | null> {
  try {
    const body: unknown = await request.json();
    const idToken = (body as { idToken?: unknown } | null)?.idToken;
    return typeof idToken === "string" && idToken.length > 0 ? idToken : null;
  } catch {
    return null;
  }
}

/** Exchanges the identity token of a fresh sign-in for a session cookie. */
export async function POST(request: Request): Promise<NextResponse> {
  if (!isSameOrigin(request)) return refused(403);

  const idToken = await readIdToken(request);
  if (!idToken) return refused(400);

  const session = await createSession(
    adminAuth(),
    serverSettings(),
    idToken,
    Math.floor(Date.now() / MS_PER_SECOND),
  );
  if (!session.ok) return refused(403);

  const response = NextResponse.json({ ok: true });
  response.cookies.set(SESSION_COOKIE, session.cookie, {
    ...cookieOptions,
    maxAge: SESSION_MAX_AGE_MS / MS_PER_SECOND,
  });
  return response;
}

/** Ends the session on this browser. */
export async function DELETE(request: Request): Promise<NextResponse> {
  if (!isSameOrigin(request)) return refused(403);

  const response = NextResponse.json({ ok: true });
  response.cookies.set(SESSION_COOKIE, "", { ...cookieOptions, maxAge: 0 });
  return response;
}
