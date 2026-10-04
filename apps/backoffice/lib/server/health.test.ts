import { describe, expect, it } from "vitest";
import { healthReport } from "./health";
import { EXPECTED_PROJECT_ID } from "./settings";

const valid = {
  FIREBASE_PROJECT_ID: EXPECTED_PROJECT_ID,
  ADMIN_EMAILS: "ana@example.com",
};

describe("healthReport", () => {
  it("is healthy when the settings can be read", () => {
    const report = healthReport(valid, "1.2.3");

    expect(report).toEqual({ status: "ok", version: "1.2.3", configuration: "valid" });
  });

  it("says the configuration is invalid without saying why", () => {
    const report = healthReport({ ADMIN_EMAILS: "ana@example.com" }, "1.2.3");

    expect(report).toEqual({
      status: "misconfigured",
      version: "1.2.3",
      configuration: "invalid",
    });
  });

  it("never carries a value from the environment", () => {
    const secret = "ana.secreta@example.com";
    const reports = [
      healthReport({ ...valid, ADMIN_EMAILS: secret }, "1.2.3"),
      healthReport({ FIREBASE_PROJECT_ID: "another-project", ADMIN_EMAILS: secret }, "1.2.3"),
    ];

    for (const report of reports) {
      const text = JSON.stringify(report);
      expect(text).not.toContain(secret);
      expect(text).not.toContain("another-project");
      expect(text).not.toContain(EXPECTED_PROJECT_ID);
    }
  });
});
