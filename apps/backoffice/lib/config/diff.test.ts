import { describe, expect, it } from "vitest";
import { exampleConfig } from "@/test/support/fixtures";
import { changesBySection, countChanges } from "./diff";
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

describe("changesBySection", () => {
  it("finds nothing anywhere between a configuration and its copy", () => {
    expect(changesBySection(exampleConfig(), exampleConfig())).toEqual({
      home: 0,
      features: 0,
      resilience: 0,
    });
  });

  it("files order, visibility and the banner under the home", () => {
    let draft = moveModule(exampleConfig(), "starting", 0, 4);
    draft = setModuleVisible(draft, "family", "promo", false);
    draft = setPromo(draft, "starting", { title: "Otro título" });

    expect(changesBySection(exampleConfig(), draft)).toEqual({
      home: 3,
      features: 0,
      resilience: 0,
    });
  });

  it("files a feature switch under features, whichever the segment", () => {
    let draft = setFeature(exampleConfig(), "wealth", "partnerServices", false);
    draft = setFeature(draft, "starting", "transfers", false);

    expect(changesBySection(exampleConfig(), draft)).toEqual({
      home: 0,
      features: 2,
      resilience: 0,
    });
  });

  it("files each fault setting under resilience", () => {
    const draft = setResilience(exampleConfig(), {
      latencyMs: 2000,
      movementsUnavailable: true,
    });

    expect(changesBySection(exampleConfig(), draft)).toEqual({
      home: 0,
      features: 0,
      resilience: 2,
    });
  });

  it("adds up to what the editor counts as a whole", () => {
    let draft = moveModule(exampleConfig(), "starting", 0, 4);
    draft = setFeature(draft, "wealth", "partnerServices", false);
    draft = setResilience(draft, { latencyMs: 2000 });
    const bySection = changesBySection(exampleConfig(), draft);

    expect(bySection.home + bySection.features + bySection.resilience).toBe(
      countChanges(exampleConfig(), draft),
    );
  });
});
