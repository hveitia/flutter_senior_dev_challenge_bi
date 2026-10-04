import { describe, expect, it, vi } from "vitest";
import { identityProvider, ORIGIN, TOKEN } from "@/test/support/customer-api";

/**
 * The console and the customer API share one server and one identity
 * provider. This pins that a customer's valid token opens nothing in the
 * console: the real session check runs here, with a provider that would
 * accept the token if anyone asked it to.
 */

const provider = {
  ...identityProvider(),
  verifySessionCookie: vi.fn().mockResolvedValue({ uid: "uid-valentina" }),
};
const sendToTopic = vi.fn();

vi.mock("next/headers", () => ({
  // A request that carries no cookie at all.
  cookies: async () => ({ get: () => undefined }),
}));
vi.mock("@/lib/server/firebase", () => ({
  adminAuth: () => provider,
  adminDb: () => ({}),
  adminMessaging: () => ({}),
  serverSettings: () => ({ adminEmails: new Set(["ana@example.com"]), pushDryRun: true }),
}));
vi.mock("@/lib/server/push-store", () => ({
  firebasePushPorts: () => ({ gateway: { sendToTopic } }),
}));

const { POST } = await import("./route");

describe("POST /api/push with a customer's token", () => {
  it("answers 401 and never asks the provider about the token", async () => {
    const response = await POST(
      new Request(`${ORIGIN}/api/push`, {
        method: "POST",
        headers: {
          host: "localhost:3000",
          origin: ORIGIN,
          "content-type": "application/json",
          authorization: `Bearer ${TOKEN}`,
        },
        body: JSON.stringify({
          title: "Una novedad para ti",
          body: "Mensaje",
          audience: { kind: "segment", segmentId: "family" },
          destination: "inbox",
        }),
      }),
    );

    expect(response.status).toBe(401);
    expect(provider.verifyIdToken).not.toHaveBeenCalled();
    expect(provider.verifySessionCookie).not.toHaveBeenCalled();
    expect(sendToTopic).not.toHaveBeenCalled();
  });
});
