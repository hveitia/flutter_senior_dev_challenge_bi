import "server-only";
import { readServerSettings } from "./settings";

type Environment = Record<string, string | undefined>;

export interface HealthReport {
  status: "ok" | "misconfigured";
  version: string;
  configuration: "valid" | "invalid";
}

/**
 * What an uptime check may know: that the server answers and whether its
 * settings can be read. Never which setting is wrong nor any value, since
 * the route that serves this asks for no session.
 */
export function healthReport(env: Environment, version: string): HealthReport {
  try {
    readServerSettings(env);
    return { status: "ok", version, configuration: "valid" };
  } catch {
    return { status: "misconfigured", version, configuration: "invalid" };
  }
}
