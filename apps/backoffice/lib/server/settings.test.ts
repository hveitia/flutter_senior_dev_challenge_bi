import { describe, expect, it } from "vitest";
import { EXPECTED_PROJECT_ID, readServerSettings, SettingsError } from "./settings";

const valid = {
  FIREBASE_PROJECT_ID: EXPECTED_PROJECT_ID,
  ADMIN_EMAILS: "ana@example.com",
};

describe("readServerSettings", () => {
  it("reads the project and the administrators", () => {
    const settings = readServerSettings(valid);

    expect(settings.projectId).toBe(EXPECTED_PROJECT_ID);
    expect([...settings.adminEmails]).toEqual(["ana@example.com"]);
  });

  it("refuses to start without a project", () => {
    expect(() => readServerSettings({ ADMIN_EMAILS: "ana@example.com" })).toThrow(
      SettingsError,
    );
  });

  it("refuses a project other than the expected one", () => {
    expect(() =>
      readServerSettings({ ...valid, FIREBASE_PROJECT_ID: "another-project" }),
    ).toThrow(/another-project/);
  });

  it("accepts another project only when it is allowed explicitly", () => {
    const settings = readServerSettings({
      ...valid,
      FIREBASE_PROJECT_ID: "another-project",
      ALLOW_OTHER_PROJECT: "true",
    });

    expect(settings.projectId).toBe("another-project");
  });

  it("refuses to start without any administrator", () => {
    expect(() => readServerSettings({ ...valid, ADMIN_EMAILS: " , " })).toThrow(
      SettingsError,
    );
    expect(() =>
      readServerSettings({ FIREBASE_PROJECT_ID: EXPECTED_PROJECT_ID }),
    ).toThrow(SettingsError);
  });

  it("compares administrator addresses without case or surrounding spaces", () => {
    const settings = readServerSettings({
      ...valid,
      ADMIN_EMAILS: " Ana@Example.com , luis@example.com ",
    });

    expect([...settings.adminEmails]).toEqual([
      "ana@example.com",
      "luis@example.com",
    ]);
  });

  it("is a production environment unless it is marked as a demonstration", () => {
    expect(readServerSettings(valid).isDemo).toBe(false);
    expect(
      readServerSettings({ ...valid, BACKOFFICE_ENVIRONMENT: "demo" }).isDemo,
    ).toBe(true);
    expect(
      readServerSettings({ ...valid, BACKOFFICE_ENVIRONMENT: "staging" }).isDemo,
    ).toBe(false);
  });

  it("sends real notifications unless a dry run is requested", () => {
    expect(readServerSettings(valid).pushDryRun).toBe(false);
    expect(readServerSettings({ ...valid, PUSH_DRY_RUN: "true" }).pushDryRun).toBe(
      true,
    );
  });

  it("uses the default credentials when no service account is given", () => {
    expect(readServerSettings(valid).serviceAccount).toBeNull();
  });

  it("reads a service account given as JSON", () => {
    const account = { project_id: EXPECTED_PROJECT_ID, client_email: "x@y.z" };
    const settings = readServerSettings({
      ...valid,
      FIREBASE_SERVICE_ACCOUNT: JSON.stringify(account),
    });

    expect(settings.serviceAccount).toEqual(account);
  });

  it("refuses a service account that is not valid JSON, without echoing it", () => {
    const read = () =>
      readServerSettings({ ...valid, FIREBASE_SERVICE_ACCOUNT: "{secret" });

    expect(read).toThrow(SettingsError);
    expect(read).not.toThrow(/secret/);
  });
});
