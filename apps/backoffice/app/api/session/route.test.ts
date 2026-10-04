import { beforeEach, describe, expect, it, vi } from "vitest";
import { SESSION_COOKIE } from "@/lib/server/session";

const auth = {
  verifyIdToken: vi.fn(),
  createSessionCookie: vi.fn(),
  verifySessionCookie: vi.fn(),
};

vi.mock("@/lib/server/firebase", () => ({
  adminAuth: () => auth,
  serverSettings: () => ({
    projectId: "flutter-challenge-bi",
    adminEmails: new Set(["ana@example.com"]),
    isDemo: true,
    pushDryRun: false,
    serviceAccount: null,
  }),
}));

const { DELETE, POST } = await import("./route");

const ORIGIN = "http://localhost:3000";

function request(
  method: "POST" | "DELETE",
  body?: unknown,
  origin: string | null = ORIGIN,
): Request {
  const headers: Record<string, string> = {
    host: "localhost:3000",
    "content-type": "application/json",
  };
  if (origin) headers.origin = origin;
  return new Request(`${ORIGIN}/api/session`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

function admitted() {
  auth.verifyIdToken.mockResolvedValue({
    uid: "uid-ana",
    email: "ana@example.com",
    email_verified: true,
    auth_time: Math.floor(Date.now() / 1000),
  });
  auth.createSessionCookie.mockResolvedValue("signed-cookie");
}

beforeEach(() => {
  auth.verifyIdToken.mockReset();
  auth.createSessionCookie.mockReset();
});

describe("POST /api/session", () => {
  it("sets an HTTP-only, same-site cookie for an administrator", async () => {
    admitted();

    const response = await POST(request("POST", { idToken: "id-token" }));

    expect(response.status).toBe(200);
    const cookie = response.headers.get("set-cookie") ?? "";
    expect(cookie).toContain(`${SESSION_COOKIE}=signed-cookie`);
    expect(cookie).toMatch(/HttpOnly/i);
    expect(cookie).toMatch(/SameSite=strict/i);
    expect(cookie).toMatch(/Path=\//i);
  });

  it("refuses a request from another site before looking at the token", async () => {
    admitted();

    const response = await POST(
      request("POST", { idToken: "id-token" }, "https://evil.example.net"),
    );

    expect(response.status).toBe(403);
    expect(response.headers.get("set-cookie")).toBeNull();
    expect(auth.verifyIdToken).not.toHaveBeenCalled();
  });

  it("refuses a request without an origin", async () => {
    admitted();

    const response = await POST(request("POST", { idToken: "id-token" }, null));

    expect(response.status).toBe(403);
  });

  it("refuses someone who is not an administrator and sets no cookie", async () => {
    auth.verifyIdToken.mockResolvedValue({
      uid: "uid-eva",
      email: "eva@example.com",
      email_verified: true,
      auth_time: Math.floor(Date.now() / 1000),
    });

    const response = await POST(request("POST", { idToken: "id-token" }));

    expect(response.status).toBe(403);
    expect(response.headers.get("set-cookie")).toBeNull();
  });

  it("answers every refusal the same way, without saying why", async () => {
    auth.verifyIdToken.mockRejectedValue(new Error("auth/argument-error"));
    const forged = await POST(request("POST", { idToken: "forged" }));

    auth.verifyIdToken.mockResolvedValue({
      uid: "uid-eva",
      email: "eva@example.com",
      email_verified: true,
      auth_time: Math.floor(Date.now() / 1000),
    });
    const stranger = await POST(request("POST", { idToken: "id-token" }));

    expect(forged.status).toBe(stranger.status);
    expect(await forged.json()).toEqual(await stranger.json());
  });

  it("rejects a body without a token", async () => {
    const response = await POST(request("POST", { other: 1 }));

    expect(response.status).toBe(400);
    expect(auth.verifyIdToken).not.toHaveBeenCalled();
  });

  it("rejects a body that is not JSON", async () => {
    const malformed = new Request(`${ORIGIN}/api/session`, {
      method: "POST",
      headers: { host: "localhost:3000", origin: ORIGIN },
      body: "{",
    });

    const response = await POST(malformed);

    expect(response.status).toBe(400);
  });
});

describe("DELETE /api/session", () => {
  it("clears the cookie", async () => {
    const response = await DELETE(request("DELETE"));

    expect(response.status).toBe(200);
    const cookie = response.headers.get("set-cookie") ?? "";
    expect(cookie).toContain(`${SESSION_COOKIE}=;`);
    expect(cookie).toMatch(/Max-Age=0/i);
  });

  it("refuses a request from another site", async () => {
    const response = await DELETE(
      request("DELETE", undefined, "https://evil.example.net"),
    );

    expect(response.status).toBe(403);
  });
});
