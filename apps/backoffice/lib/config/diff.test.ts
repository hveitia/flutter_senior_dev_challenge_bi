import { describe, expect, it } from "vitest";
import { exampleConfig } from "@/test/support/fixtures";
import { countChanges } from "./diff";
import {
  moveModule,
  setFeature,
  setModuleVisible,
  setPromo,
  setResilience,
} from "./editing";

describe("countChanges", () => {
  it("counts nothing between a configuration and its copy", () => {
    expect(countChanges(exampleConfig(), exampleConfig())).toBe(0);
  });

  it("counts a reordering of a segment once, however many modules moved", () => {
    const draft = moveModule(exampleConfig(), "starting", 0, 4);

    expect(countChanges(exampleConfig(), draft)).toBe(1);
  });

  it("counts each visibility switch", () => {
    let draft = setModuleVisible(exampleConfig(), "starting", "promo", false);
    draft = setModuleVisible(draft, "starting", "services", false);

    expect(countChanges(exampleConfig(), draft)).toBe(2);
  });

  it("counts each banner field that differs", () => {
    const draft = setPromo(exampleConfig(), "starting", {
      title: "Otro título",
      destination: "transfer",
    });

    expect(countChanges(exampleConfig(), draft)).toBe(2);
  });

  it("counts each feature flag and each fault setting", () => {
    let draft = setFeature(exampleConfig(), "wealth", "partnerServices", false);
    draft = setResilience(draft, { latencyMs: 2000, movementsUnavailable: true });

    expect(countChanges(exampleConfig(), draft)).toBe(3);
  });

  it("counts the same edit in two segments twice", () => {
    let draft = setModuleVisible(exampleConfig(), "starting", "promo", false);
    draft = setModuleVisible(draft, "family", "promo", false);

    expect(countChanges(exampleConfig(), draft)).toBe(2);
  });

  it("stops counting an edit that was undone", () => {
    let draft = setModuleVisible(exampleConfig(), "starting", "promo", false);
    draft = setModuleVisible(draft, "starting", "promo", true);

    expect(countChanges(exampleConfig(), draft)).toBe(0);
  });

  it("does not count the version number", () => {
    const draft = { ...exampleConfig(), configVersion: 99 };

    expect(countChanges(exampleConfig(), draft)).toBe(0);
  });

  it("treats a missing resilience block as no faults", () => {
    const published = exampleConfig();
    delete published.resilience;

    expect(countChanges(published, exampleConfig())).toBe(0);
  });
});
