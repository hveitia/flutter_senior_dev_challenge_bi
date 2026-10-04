/**
 * Shape of the document published at `config/home`, as described by
 * `contracts/home-config.schema.json`. The schema is the authority: these
 * types only name what the console edits, and unknown fields are preserved.
 */

export type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

export type JsonObject = { [key: string]: JsonValue };

export interface ModuleConfig {
  id: string;
  type: string;
  visible?: boolean;
  props?: JsonObject;
}

export interface FeatureFlags {
  transfers: boolean;
  partnerServices: boolean;
}

export type FeatureName = keyof FeatureFlags;

export interface SegmentConfig {
  label: string;
  modules: ModuleConfig[];
  features: FeatureFlags;
}

export interface ResilienceSettings {
  latencyMs: number;
  movementsUnavailable: boolean;
  partnerInsuranceUnavailable: boolean;
}

export interface HomeConfig {
  schemaVersion: number;
  configVersion: number;
  destinations: string[];
  resilience?: Partial<ResilienceSettings>;
  segments: Record<string, SegmentConfig>;
}

export const NO_FAULTS: ResilienceSettings = {
  latencyMs: 0,
  movementsUnavailable: false,
  partnerInsuranceUnavailable: false,
};

export function hasFaults(faults: ResilienceSettings): boolean {
  return (
    faults.latencyMs > NO_FAULTS.latencyMs ||
    faults.movementsUnavailable ||
    faults.partnerInsuranceUnavailable
  );
}

/** Whether `after` simulates anything that `before` did not, or more of it. */
export function worsensFaults(
  before: ResilienceSettings,
  after: ResilienceSettings,
): boolean {
  return (
    after.latencyMs > before.latencyMs ||
    (after.movementsUnavailable && !before.movementsUnavailable) ||
    (after.partnerInsuranceUnavailable && !before.partnerInsuranceUnavailable)
  );
}

/** The resilience block with every field stated. */
export function resilienceOf(config: HomeConfig): ResilienceSettings {
  return { ...NO_FAULTS, ...config.resilience };
}
