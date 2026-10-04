import Ajv2020 from "ajv/dist/2020";
import contract from "../../../../contracts/home-config.schema.json";
import type { HomeConfig } from "./types";

export interface ConfigIssue {
  /** JSON pointer to the offending value, for example `/segments/starting`. */
  path: string;
  message: string;
}

export type ValidationResult =
  | { ok: true; config: HomeConfig }
  | { ok: false; issues: ConfigIssue[] };

/** Depth the mobile reader accepts for a module's settings. */
export const MAX_PROPS_DEPTH = 32;

const DESTINATION_KEY = "destination";

// The schema file is the single statement of the contract. It is compiled as
// it is, never retyped, so a change in contracts/ changes what is accepted
// here without touching this module.
const matchesContract = new Ajv2020({ allErrors: true, strict: false }).compile(
  contract,
);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * What the contract states in prose because JSON Schema cannot express it:
 * module ids are unique within a segment, every destination belongs to the
 * allow-list, and settings stay within the depth the reader accepts.
 */
function publisherIssues(config: HomeConfig): ConfigIssue[] {
  const issues: ConfigIssue[] = [];
  const allowed = new Set(config.destinations);

  const inspect = (value: unknown, path: string, depth: number): boolean => {
    if (depth > MAX_PROPS_DEPTH) return false;
    if (Array.isArray(value)) {
      return value.every((item, index) =>
        inspect(item, `${path}/${index}`, depth + 1),
      );
    }
    if (!isRecord(value)) return true;
    let withinDepth = true;
    for (const [key, child] of Object.entries(value)) {
      const childPath = `${path}/${key}`;
      if (key === DESTINATION_KEY && typeof child === "string") {
        if (!allowed.has(child)) {
          issues.push({
            path: childPath,
            message: `"${child}" is not in the destination allow-list`,
          });
        }
        continue;
      }
      withinDepth = inspect(child, childPath, depth + 1) && withinDepth;
    }
    return withinDepth;
  };

  for (const [segmentId, segment] of Object.entries(config.segments)) {
    const seen = new Set<string>();
    segment.modules.forEach((module, index) => {
      const modulePath = `/segments/${segmentId}/modules/${index}`;
      if (seen.has(module.id)) {
        issues.push({
          path: `${modulePath}/id`,
          message: `"${module.id}" is already used in this segment`,
        });
      }
      seen.add(module.id);

      const propsPath = `${modulePath}/props`;
      if (!inspect(module.props ?? {}, propsPath, 0)) {
        issues.push({
          path: propsPath,
          message: `settings are nested deeper than ${MAX_PROPS_DEPTH} levels`,
        });
      }
    });
  }
  return issues;
}

/**
 * The version number of whatever is stored, valid or not. A document can
 * break the contract and still carry the number a publish must be based on.
 */
export function configVersionOf(stored: unknown): number | null {
  if (!isRecord(stored)) return null;
  const version = stored.configVersion;
  return typeof version === "number" && Number.isInteger(version) ? version : null;
}

/** Checks a document against everything the publisher must guarantee. */
export function validateHomeConfig(document: unknown): ValidationResult {
  if (!matchesContract(document)) {
    const issues = (matchesContract.errors ?? []).map((error) => ({
      path: error.instancePath,
      message: error.message ?? "does not match the contract",
    }));
    return { ok: false, issues };
  }

  const config = document as unknown as HomeConfig;
  const issues = publisherIssues(config);
  return issues.length === 0 ? { ok: true, config } : { ok: false, issues };
}
