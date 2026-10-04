import { describe, expect, it, vi } from "vitest";
import {
  adminFromCookie,
  cookieFrom,
  createSession,
  endSession,
  RECENT_SIGN_IN_SECONDS,
  SESSION_MAX_AGE_MS,
  type AuthPort,
  type DecodedToken,
} from "./session";
import type { ServerSettings } from "./settings";

const NOW_SECONDS = 1_800_000_000;

const settings: ServerSettings = {
  projectId: "flutter-challenge-bi",
  adminEmails: new Set(["ana@example.com"]),
  isDemo: true,
  pushDryRun: false,
  serviceAccount: null,
  usesEmulators: false,
  isHosted: false,
};

function token(overrides: Partial<DecodedToken> = {}): DecodedToken {
  return {
    uid: "uid-ana",
    email: "ana@example.com",
    email_verified: true,
    auth_time: NOW_SECONDS - 10,
    ...overrides,
  };
}

function authReturning(decoded: DecodedToken): AuthPort {
  return {
    verifyIdToken: vi.fn().mockResolvedValue(decoded),
    createSessionCookie: vi.fn().mockResolvedValue("signed-cookie"),
    verifySessionCookie: vi.fn().mockResolvedValue(decoded),
    revokeRefreshTokens: vi.fn().mockResolvedValue(undefined),
  };
}

function authRejecting(): AuthPort {
  const rejected = () => Promise.reject(new Error("auth/argument-error"));
  return {
    verifyIdToken: vi.fn(rejected),
    createSessionCookie: vi.fn(rejected),
    verifySessionCookie: vi.fn(rejected),
    revokeRefreshTokens: vi.fn().mockResolvedValue(undefined),
  };
}

describe("createSession", () => {
  it("issues a cookie to an allow-listed administrator who just signed in", async () => {
    const auth = authReturning(token());

    const result = await createSession(auth, settings, "id-token", NOW_SECONDS);

    expect(result).toEqual({
      ok: true,
      cookie: "signed-cookie",
      admin: { uid: "uid-ana", email: "ana@example.com" },
    });
    expect(auth.createSessionCookie).toHaveBeenCalledWith("id-token", {
      expiresIn: SESSION_MAX_AGE_MS,
    });
  });

  it("checks that the token was not revoked", async () => {
    const auth = authReturning(token());

    await createSession(auth, settings, "id-token", NOW_SECONDS);

    expect(auth.verifyIdToken).toHaveBeenCalledWith("id-token", true);
  });

  it("refuses an address that is not on the allow-list and issues no cookie", async () => {
    const auth = authReturning(token({ email: "eva@example.com" }));

    const result = await createSession(auth, settings, "id-token", NOW_SECONDS);

    expect(result).toEqual({ ok: false, reason: "not-allowed" });
    expect(auth.createSessionCookie).not.toHaveBeenCalled();
  });

  it("matches the allow-list without regard to case", async () => {
    const auth = authReturning(token({ email: "Ana@Example.com" }));

    const result = await createSession(auth, settings, "id-token", NOW_SECONDS);

    expect(result.ok).toBe(true);
  });

  it("refuses an allow-listed address that was never verified", async () => {
    const auth = authReturning(token({ email_verified: false }));

    const result = await createSession(auth, settings, "id-token", NOW_SECONDS);

    expect(result).toEqual({ ok: false, reason: "unverified" });
    expect(auth.createSessionCookie).not.toHaveBeenCalled();
  });

  it("refuses a token without an address", async () => {
    const auth = authReturning(token({ email: undefined }));

    const result = await createSession(auth, settings, "id-token", NOW_SECONDS);

    expect(result).toEqual({ ok: false, reason: "not-allowed" });
  });

  it("refuses a sign-in that is not recent", async () => {
    const auth = authReturning(
      token({ auth_time: NOW_SECONDS - RECENT_SIGN_IN_SECONDS - 1 }),
    );

    const result = await createSession(auth, settings, "id-token", NOW_SECONDS);

    expect(result).toEqual({ ok: false, reason: "stale" });
    expect(auth.createSessionCookie).not.toHaveBeenCalled();
  });

  it("refuses a token that cannot be verified", async () => {
    const result = await createSession(
      authRejecting(),
      settings,
      "forged",
      NOW_SECONDS,
    );

    expect(result).toEqual({ ok: false, reason: "invalid" });
  });
});

describe("endSession", () => {
  it("revokes the sessions of the administrator behind the cookie", async () => {
    const auth = authReturning(token());

    expect(await endSession(auth, "signed-cookie")).toBe(true);
    expect(auth.verifySessionCookie).toHaveBeenCalledWith("signed-cookie", true);
    expect(auth.revokeRefreshTokens).toHaveBeenCalledWith("uid-ana");
  });

  it("revokes nothing for a cookie it cannot verify", async () => {
    const auth = authRejecting();

    expect(await endSession(auth, "forged")).toBe(false);
    expect(auth.revokeRefreshTokens).not.toHaveBeenCalled();
  });

  it("revokes nothing without a cookie", async () => {
    const auth = authReturning(token());

    expect(await endSession(auth, undefined)).toBe(false);
    expect(auth.verifySessionCookie).not.toHaveBeenCalled();
  });

  it("reports a revocation that failed instead of throwing", async () => {
    const auth = authReturning(token());
    vi.mocked(auth.revokeRefreshTokens).mockRejectedValue(new Error("down"));

    expect(await endSession(auth, "signed-cookie")).toBe(false);
  });
});

describe("cookieFrom", () => {
  it("finds one cookie among several", () => {
    expect(cookieFrom("a=1; __session=abc.def; b=2", "__session")).toBe("abc.def");
  });

  it("finds nothing when the cookie is absent or there is no header", () => {
    expect(cookieFrom("a=1; b=2", "__session")).toBeUndefined();
    expect(cookieFrom(null, "__session")).toBeUndefined();
  });

  it("does not confuse a cookie whose name merely ends the same way", () => {
    expect(cookieFrom("x__session=evil", "__session")).toBeUndefined();
  });
});

describe("adminFromCookie", () => {
  it("recognizes the administrator behind a valid cookie", async () => {
    const auth = authReturning(token());

    const admin = await adminFromCookie(auth, settings, "signed-cookie");

    expect(admin).toEqual({ uid: "uid-ana", email: "ana@example.com" });
    expect(auth.verifySessionCookie).toHaveBeenCalledWith("signed-cookie", true);
  });

  it("recognizes nobody without a cookie, and does not call the provider", async () => {
    const auth = authReturning(token());

    expect(await adminFromCookie(auth, settings, undefined)).toBeNull();
    expect(await adminFromCookie(auth, settings, "")).toBeNull();
    expect(auth.verifySessionCookie).not.toHaveBeenCalled();
  });

  it("recognizes nobody behind a forged, expired or revoked cookie", async () => {
    expect(await adminFromCookie(authRejecting(), settings, "forged")).toBeNull();
  });

  it("stops recognizing an administrator removed from the allow-list", async () => {
    const auth = authReturning(token());
    const without = { ...settings, adminEmails: new Set(["luis@example.com"]) };

    expect(await adminFromCookie(auth, without, "signed-cookie")).toBeNull();
  });

  it("does not require a recent sign-in for an existing session", async () => {
    const auth = authReturning(token({ auth_time: NOW_SECONDS - 3600 }));

    const admin = await adminFromCookie(auth, settings, "signed-cookie");

    expect(admin?.uid).toBe("uid-ana");
  });
});
