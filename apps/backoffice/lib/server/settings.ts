import "server-only";

/** Settings the server reads from the environment, checked once at startup. */

export const EXPECTED_PROJECT_ID = "flutter-challenge-bi";

const DEMO_ENVIRONMENT = "demo";
const LIVE_DELIVERY = "live";

export class SettingsError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SettingsError";
  }
}

export interface ServerSettings {
  projectId: string;
  /** Lower-cased addresses allowed to use the console. */
  adminEmails: ReadonlySet<string>;
  /** Only a demonstration environment may publish simulated faults. */
  isDemo: boolean;
  /**
   * Ask the messaging service to validate a send without delivering it.
   * True unless the environment sets PUSH_DELIVERY=live.
   */
  pushDryRun: boolean;
  /** Parsed service account, or null to use the default credentials. */
  serviceAccount: Record<string, unknown> | null;
}

type Environment = Record<string, string | undefined>;

function isOn(value: string | undefined): boolean {
  return value === "true";
}

function readProjectId(env: Environment): string {
  const projectId = env.FIREBASE_PROJECT_ID?.trim();
  if (!projectId) {
    throw new SettingsError("FIREBASE_PROJECT_ID is required");
  }
  // An administration tool pointed at the wrong project writes to real data.
  if (projectId !== EXPECTED_PROJECT_ID && !isOn(env.ALLOW_OTHER_PROJECT)) {
    throw new SettingsError(
      `FIREBASE_PROJECT_ID is "${projectId}", expected "${EXPECTED_PROJECT_ID}". ` +
        "Set ALLOW_OTHER_PROJECT=true to use another project on purpose.",
    );
  }
  return projectId;
}

function readAdminEmails(env: Environment): ReadonlySet<string> {
  const emails = (env.ADMIN_EMAILS ?? "")
    .split(",")
    .map((email) => email.trim().toLowerCase())
    .filter((email) => email.length > 0);
  if (emails.length === 0) {
    throw new SettingsError("ADMIN_EMAILS must list at least one administrator");
  }
  return new Set(emails);
}

function readServiceAccount(env: Environment): Record<string, unknown> | null {
  const raw = env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) return null;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
  } catch {
    // Reported below without the value: it is a credential.
  }
  throw new SettingsError("FIREBASE_SERVICE_ACCOUNT is not a JSON object");
}

export function readServerSettings(env: Environment): ServerSettings {
  return {
    projectId: readProjectId(env),
    adminEmails: readAdminEmails(env),
    isDemo: env.BACKOFFICE_ENVIRONMENT === DEMO_ENVIRONMENT,
    // Delivering to real phones is opt-in: a deployment that forgot the
    // setting, or mistyped it, validates its sends and delivers nothing.
    pushDryRun: env.PUSH_DELIVERY !== LIVE_DELIVERY,
    serviceAccount: readServiceAccount(env),
  };
}
