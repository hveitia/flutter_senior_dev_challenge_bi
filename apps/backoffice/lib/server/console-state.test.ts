import { describe, expect, it } from "vitest";
import { exampleConfig } from "@/test/support/fixtures";
import { consoleStateFrom } from "./console-state";

describe("consoleStateFrom", () => {
  it("starts the editor from the published document", () => {
    const stored = { ...exampleConfig(), configVersion: 21 };

    const state = consoleStateFrom(stored, "2026-10-03T13:40:00.000Z");

    expect(state).toEqual({
      config: stored,
      baseVersion: 21,
      source: "published",
      lastPublishedAt: "2026-10-03T13:40:00.000Z",
    });
  });

  it("starts from the contract example when nothing was published yet", () => {
    const state = consoleStateFrom(null, null);

    expect(state.source).toBe("example");
    expect(state.baseVersion).toBeNull();
    expect(state.config.segments.starting?.label).toBe("Estoy empezando");
    expect(state.lastPublishedAt).toBeNull();
  });

  it("starts from the example when the stored document breaks the contract, keeping its version as the base", () => {
    const broken = { schemaVersion: 1, configVersion: 7, segments: {} };

    const state = consoleStateFrom(broken, null);

    expect(state.source).toBe("example");
    expect(state.baseVersion).toBe(7);
  });

  it("has no base version when the stored document carries no usable one", () => {
    expect(consoleStateFrom({ configVersion: "seven" }, null).baseVersion).toBeNull();
    expect(consoleStateFrom("garbage", null).baseVersion).toBeNull();
  });
});
