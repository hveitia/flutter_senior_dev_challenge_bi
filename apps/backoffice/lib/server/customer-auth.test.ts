import { describe, expect, it, vi } from "vitest";
import {
  customerFromRequest,
  MAX_BEARER_LENGTH,
  type TokenVerifier,
} from "./customer-auth";

function verifierReturning(decoded: { uid?: unknown }): TokenVerifier {
  return { verifyIdToken: vi.fn().mockResolvedValue(decoded) };
}

function verifierRejecting(code: string): TokenVerifier {
  return { verifyIdToken: vi.fn().mockRejectedValue(new Error(code)) };
}

function request(headers: Record<string, string>): Request {
  return new Request("http://localhost:3000/api/transfers", {
    method: "POST",
    headers,
  });
}

describe("customerFromRequest", () => {
  it("names the customer of a token that verifies", async () => {
    const auth = verifierReturning({ uid: "uid-valentina" });

    const customer = await customerFromRequest(
      auth,
      request({ authorization: "Bearer id-token" }),
    );

    expect(customer).toEqual({ uid: "uid-valentina" });
  });

  it("asks the provider whether the token was revoked", async () => {
    const auth = verifierReturning({ uid: "uid-valentina" });

    await customerFromRequest(auth, request({ authorization: "Bearer id-token" }));

    expect(auth.verifyIdToken).toHaveBeenCalledWith("id-token", true);
  });

  it("accepts the scheme in any letter case", async () => {
    const auth = verifierReturning({ uid: "uid-valentina" });

    expect(
      await customerFromRequest(auth, request({ authorization: "bearer id-token" })),
    ).toEqual({ uid: "uid-valentina" });
  });

  it.each([
    ["no credentials at all", {}],
    ["another scheme", { authorization: "Basic dmFsZW50aW5hOnNlY3JldA==" }],
    ["the scheme without a token", { authorization: "Bearer " }],
    ["two tokens", { authorization: "Bearer one two" }],
    ["a token longer than any identity token", {
      authorization: `Bearer ${"a".repeat(MAX_BEARER_LENGTH + 1)}`,
    }],
  ])("refuses %s without asking the provider", async (_name, headers) => {
    const auth = verifierReturning({ uid: "uid-valentina" });

    expect(await customerFromRequest(auth, request(headers))).toBeNull();
    expect(auth.verifyIdToken).not.toHaveBeenCalled();
  });

  it("ignores an administrator session cookie", async () => {
    const auth = verifierReturning({ uid: "uid-ana" });

    const customer = await customerFromRequest(
      auth,
      request({ cookie: "__session=signed-administrator-cookie" }),
    );

    expect(customer).toBeNull();
    expect(auth.verifyIdToken).not.toHaveBeenCalled();
  });

  it.each([
    "auth/id-token-expired",
    "auth/id-token-revoked",
    "auth/argument-error",
    "auth/user-disabled",
  ])("refuses a token the provider rejects with %s", async (code) => {
    const auth = verifierRejecting(code);

    expect(
      await customerFromRequest(auth, request({ authorization: "Bearer id-token" })),
    ).toBeNull();
  });

  it("refuses a verified token that names nobody", async () => {
    const auth = verifierReturning({ uid: "" });

    expect(
      await customerFromRequest(auth, request({ authorization: "Bearer id-token" })),
    ).toBeNull();
  });
});
