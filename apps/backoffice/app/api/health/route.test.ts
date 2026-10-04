import { afterEach, describe, expect, it, vi } from "vitest";
import { EXPECTED_PROJECT_ID } from "@/lib/server/settings";
import { GET } from "./route";

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("GET /api/health", () => {
  it("answers 200 without a session when the server is configured", async () => {
    vi.stubEnv("FIREBASE_PROJECT_ID", EXPECTED_PROJECT_ID);
    vi.stubEnv("ADMIN_EMAILS", "ana@example.com");

    const response = GET();

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ status: "ok", configuration: "valid" });
  });

  it("answers 503 when the server cannot read its settings", async () => {
    vi.stubEnv("FIREBASE_PROJECT_ID", "");
    vi.stubEnv("ADMIN_EMAILS", "ana@example.com");

    const response = GET();

    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      status: "misconfigured",
      configuration: "invalid",
    });
  });

  it("is never cached", () => {
    vi.stubEnv("FIREBASE_PROJECT_ID", EXPECTED_PROJECT_ID);
    vi.stubEnv("ADMIN_EMAILS", "ana@example.com");

    expect(GET().headers.get("cache-control")).toBe("no-store");
  });
});
