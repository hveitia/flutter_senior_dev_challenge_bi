import { vi } from "vitest";
import type { AccountBalance } from "@/lib/api/transfer";

/** Shared fixtures for the tests of the customer API routes. */

export const ORIGIN = "http://localhost:3000";
export const UID = "uid-valentina";
export const TOKEN = "valentina-id-token";
export const TRANSFER_ID = "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f";

export const savings: AccountBalance = {
  id: "savings",
  name: "Cuenta de ahorros",
  availableCents: 357_035,
  ledgerCents: 357_035,
  currency: "USD",
};
export const checking: AccountBalance = {
  id: "checking",
  name: "Cuenta corriente",
  availableCents: 125_000,
  ledgerCents: 125_000,
  currency: "USD",
};

export const order = {
  fromAccountId: "savings",
  toAccountId: "checking",
  amountCents: 15_010,
  concept: "Arriendo",
};

/**
 * An identity provider that knows one token. Anything else is rejected the
 * way the real one rejects a forged, expired or revoked token.
 */
export function identityProvider() {
  return {
    verifyIdToken: vi.fn(async (token: string) => {
      if (token === TOKEN) return { uid: UID };
      throw new Error("auth/argument-error");
    }),
  };
}

export function post(
  path: string,
  body: unknown,
  headers: Record<string, string> = { authorization: `Bearer ${TOKEN}` },
): Request {
  return new Request(`${ORIGIN}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

/** The single log line a request leaves, parsed. */
export function logLines(spy: { mock: { calls: unknown[][] } }): Record<string, unknown>[] {
  return spy.mock.calls.map(([line]) => JSON.parse(String(line)) as Record<string, unknown>);
}
