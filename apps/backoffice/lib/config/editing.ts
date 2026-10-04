import type {
  FeatureName,
  HomeConfig,
  JsonObject,
  ModuleConfig,
  ResilienceSettings,
  SegmentConfig,
} from "./types";
import { resilienceOf } from "./types";

/**
 * Edits to the draft. Every function returns a new configuration and leaves
 * the one it receives untouched; when an edit changes nothing it returns the
 * same object, so callers can compare by reference.
 */

export const PROMO_MODULE_TYPE = "promoBanner";

export interface PromoFields {
  moduleId: string;
  title: string;
  body: string;
  actionLabel: string;
  destination: string;
}

export type PromoPatch = Partial<Omit<PromoFields, "moduleId">>;

function withSegment(
  config: HomeConfig,
  segmentId: string,
  edit: (segment: SegmentConfig) => SegmentConfig,
): HomeConfig {
  const segment = config.segments[segmentId];
  if (!segment) return config;
  const edited = edit(segment);
  if (edited === segment) return config;
  return { ...config, segments: { ...config.segments, [segmentId]: edited } };
}

/** Moves the module at `from` so that it ends at position `to`. */
export function moveModule(
  config: HomeConfig,
  segmentId: string,
  from: number,
  to: number,
): HomeConfig {
  return withSegment(config, segmentId, (segment) => {
    const last = segment.modules.length - 1;
    if (from === to || from < 0 || to < 0 || from > last || to > last) {
      return segment;
    }
    const modules = [...segment.modules];
    const [moved] = modules.splice(from, 1);
    if (!moved) return segment;
    modules.splice(to, 0, moved);
    return { ...segment, modules };
  });
}

/** A module is shown unless the configuration says otherwise. */
export function isVisible(module: ModuleConfig): boolean {
  return module.visible ?? true;
}

export function setModuleVisible(
  config: HomeConfig,
  segmentId: string,
  moduleId: string,
  visible: boolean,
): HomeConfig {
  return withSegment(config, segmentId, (segment) => {
    const target = segment.modules.find((module) => module.id === moduleId);
    if (!target || isVisible(target) === visible) return segment;
    return {
      ...segment,
      modules: segment.modules.map((module) =>
        module === target ? { ...module, visible } : module,
      ),
    };
  });
}

function textOf(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function actionOf(props: JsonObject | undefined): JsonObject {
  const action = props?.action;
  return typeof action === "object" && action !== null && !Array.isArray(action)
    ? action
    : {};
}

/** The banner of a segment, or null when the segment has none. */
export function promoOf(segment: SegmentConfig): PromoFields | null {
  const banner = segment.modules.find(
    (module) => module.type === PROMO_MODULE_TYPE,
  );
  if (!banner) return null;
  const action = actionOf(banner.props);
  return {
    moduleId: banner.id,
    title: textOf(banner.props?.title),
    body: textOf(banner.props?.body),
    actionLabel: textOf(action.label),
    destination: textOf(action.destination),
  };
}

export function setPromo(
  config: HomeConfig,
  segmentId: string,
  patch: PromoPatch,
): HomeConfig {
  return withSegment(config, segmentId, (segment) => {
    const current = promoOf(segment);
    if (!current) return segment;
    const next = { ...current, ...patch };
    return {
      ...segment,
      modules: segment.modules.map((module) =>
        module.id === current.moduleId
          ? {
              ...module,
              props: {
                ...module.props,
                title: next.title,
                body: next.body,
                action: {
                  ...actionOf(module.props),
                  label: next.actionLabel,
                  destination: next.destination,
                },
              },
            }
          : module,
      ),
    };
  });
}

export function setFeature(
  config: HomeConfig,
  segmentId: string,
  feature: FeatureName,
  enabled: boolean,
): HomeConfig {
  return withSegment(config, segmentId, (segment) =>
    segment.features[feature] === enabled
      ? segment
      : { ...segment, features: { ...segment.features, [feature]: enabled } },
  );
}

export function setResilience(
  config: HomeConfig,
  patch: Partial<ResilienceSettings>,
): HomeConfig {
  return { ...config, resilience: { ...resilienceOf(config), ...patch } };
}
