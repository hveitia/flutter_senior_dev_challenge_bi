import { describe, expect, it } from "vitest";
import type { FeatureFlags } from "@/lib/config/types";
import { exampleConfig } from "@/test/support/fixtures";
import { MAX_PROPS_DEPTH, validateHomeConfig } from "./validate";

function issuesOf(document: unknown): string[] {
  const result = validateHomeConfig(document);
  return result.ok ? [] : result.issues.map((issue) => issue.path);
}

describe("validateHomeConfig", () => {
  it("accepts the contract example", () => {
    const result = validateHomeConfig(exampleConfig());

    expect(result.ok).toBe(true);
  });

  it("rejects a document that is not an object", () => {
    expect(validateHomeConfig("nope").ok).toBe(false);
    expect(validateHomeConfig(null).ok).toBe(false);
  });

  it("rejects a document without segments", () => {
    const config = exampleConfig();
    config.segments = {};

    expect(issuesOf(config)).toContain("/segments");
  });

  it("rejects a segment that does not state every feature flag", () => {
    const config = exampleConfig();
    const features: Partial<FeatureFlags> = config.segments.starting!.features;
    delete features.partnerServices;

    expect(issuesOf(config)).toContain("/segments/starting/features");
  });

  it("rejects a module without a type", () => {
    const config = exampleConfig();
    const first = config.segments.starting!.modules[0] as { type?: string };
    delete first.type;

    expect(issuesOf(config)).toContain("/segments/starting/modules/0");
  });

  it("rejects a simulated latency above the contract maximum", () => {
    const config = exampleConfig();
    config.resilience = { latencyMs: 10001 };

    expect(issuesOf(config)).toContain("/resilience/latencyMs");
  });

  it("rejects two modules with the same id in a segment", () => {
    const config = exampleConfig();
    const modules = config.segments.starting!.modules;
    modules[1]!.id = modules[0]!.id;

    expect(issuesOf(config)).toContain("/segments/starting/modules/1/id");
  });

  it("accepts the same module id in two different segments", () => {
    const config = exampleConfig();

    expect(config.segments.starting!.modules[0]!.id).toBe(
      config.segments.family!.modules[0]!.id,
    );
    expect(validateHomeConfig(config).ok).toBe(true);
  });

  it("rejects a banner action that points outside the destination list", () => {
    const config = exampleConfig();
    const promo = config.segments.starting!.modules.find(
      (module) => module.type === "promoBanner",
    )!;
    promo.props = { action: { label: "Ir", destination: "https://example.com" } };

    expect(issuesOf(config)).toContain(
      "/segments/starting/modules/3/props/action/destination",
    );
  });

  it("rejects a quick action nested in a list that points outside the destination list", () => {
    const config = exampleConfig();
    const actions = config.segments.starting!.modules.find(
      (module) => module.type === "quickActions",
    )!;
    actions.props = { actions: [{ label: "Otro", destination: "savingsGoals" }] };

    expect(issuesOf(config)).toContain(
      "/segments/starting/modules/2/props/actions/0/destination",
    );
  });

  it("rejects module settings nested deeper than the reader accepts", () => {
    const config = exampleConfig();
    let nested: Record<string, unknown> = {};
    const props = nested;
    for (let depth = 0; depth < MAX_PROPS_DEPTH + 1; depth += 1) {
      const next = {};
      nested.child = next;
      nested = next;
    }
    config.segments.starting!.modules[0]!.props = props as never;

    expect(issuesOf(config)).toContain("/segments/starting/modules/0/props");
  });

  it("reports every problem, not only the first", () => {
    const config = exampleConfig();
    config.resilience = { latencyMs: -1 };
    config.segments = {};

    expect(issuesOf(config)).toEqual(
      expect.arrayContaining(["/resilience/latencyMs", "/segments"]),
    );
  });
});
