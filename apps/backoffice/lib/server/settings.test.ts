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

  it("only validates notifications unless real delivery is enabled explicitly", () => {
    expect(readServerSettings(valid).pushDryRun).toBe(true);
    expect(readServerSettings({ ...valid, PUSH_DELIVERY: "live" }).pushDryRun).toBe(
      false,
    );
  });

  it("stays in dry run for any delivery value it does not recognize", () => {
    expect(readServerSettings({ ...valid, PUSH_DELIVERY: "true" }).pushDryRun).toBe(
      true,
    );
    expect(readServerSettings({ ...valid, PUSH_DELIVERY: "LIVE " }).pushDryRun).toBe(
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

  it.each(["FIREBASE_AUTH_EMULATOR_HOST", "FIRESTORE_EMULATOR_HOST"])(
    "refuses to start in production with %s set, since an emulator accepts unsigned tokens",
    (variable) => {
      const read = () =>
        readServerSettings({ ...valid, NODE_ENV: "production", [variable]: "localhost:9099" });

      expect(read).toThrow(SettingsError);
    },
  );

  it("accepts an emulator outside production", () => {
    const read = () =>
      readServerSettings({
        ...valid,
        NODE_ENV: "test",
        FIRESTORE_EMULATOR_HOST: "localhost:8080",
      });

    expect(read).not.toThrow();
  });

  it("does not use the emulators unless the environment points at them", () => {
    expect(readServerSettings(valid).usesEmulators).toBe(false);
  });

  it.each(["FIREBASE_AUTH_EMULATOR_HOST", "FIRESTORE_EMULATOR_HOST"])(
    "knows it runs against a local stack when %s is set",
    (variable) => {
      const settings = readServerSettings({ ...valid, [variable]: "localhost:9099" });

      expect(settings.usesEmulators).toBe(true);
    },
  );

  it("never delivers a notification from a local stack, whatever delivery says", () => {
    const settings = readServerSettings({
      ...valid,
      FIRESTORE_EMULATOR_HOST: "localhost:8080",
      PUSH_DELIVERY: "live",
    });

    expect(settings.pushDryRun).toBe(true);
  });

  // A hosting platform is a deployment whatever NODE_ENV says: a server
  // started there in development mode must still refuse the emulators.
  describe.each([
    ["Cloud Run and Firebase App Hosting", "K_SERVICE", "backoffice"],
    ["Vercel", "VERCEL", "1"],
  ])("on %s", (_platform, marker, value) => {
    it.each(["FIREBASE_AUTH_EMULATOR_HOST", "FIRESTORE_EMULATOR_HOST"])(
      "refuses to start with %s set, even outside production mode",
      (variable) => {
        const read = () =>
          readServerSettings({
            ...valid,
            NODE_ENV: "development",
            [marker]: value,
            [variable]: "localhost:9099",
          });

        expect(read).toThrow(SettingsError);
        expect(read).toThrow(new RegExp(variable));
      },
    );

    it("knows it is hosted and uses the platform's own credentials", () => {
      const settings = readServerSettings({ ...valid, [marker]: value });

      expect(settings.isHosted).toBe(true);
      expect(settings.serviceAccount).toBeNull();
      expect(settings.usesEmulators).toBe(false);
    });
  });

  it("is not hosted on a developer machine", () => {
    expect(readServerSettings(valid).isHosted).toBe(false);
  });
});
