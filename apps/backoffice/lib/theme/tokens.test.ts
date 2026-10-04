import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import designTokens from "../../../../packages/design_system/tokens/tokens.json";
import { cssVariableName, themeCss, toCssVariables } from "./tokens";

describe("cssVariableName", () => {
  it("turns a token path into a custom property name", () => {
    expect(cssVariableName("brand/500")).toBe("--ds-brand-500");
    expect(cssVariableName("text/secondary-aa")).toBe("--ds-text-secondary-aa");
  });
});

describe("toCssVariables", () => {
  it("carries the value of a color token unchanged", () => {
    const css = toCssVariables({ "brand/500": "#EA8E29" });

    expect(css).toBe("--ds-brand-500:#EA8E29;");
  });

  it("resolves a reference to the variable of the token it points to", () => {
    const css = toCssVariables({ "focus/color": "{ink/900}" });

    expect(css).toBe("--ds-focus-color:var(--ds-ink-900);");
  });

  it("flattens the size and line height of a type token in pixels", () => {
    const css = toCssVariables({
      "type/title": { family: "Poppins", weight: 600, size: 22, height: 28 },
    });

    expect(css).toBe("--ds-type-title-size:22px;--ds-type-title-height:28px;");
  });

  it("leaves out tokens that are not style values", () => {
    const css = toCssVariables({
      "motion/reduced": "disable transitions and shimmer",
      "frame/admin": { width: 1440, height: 900 },
    });

    expect(css).toBe("");
  });
});

describe("themeCss", () => {
  it("takes the brand color from the design tokens file", () => {
    expect(themeCss).toContain(`--ds-brand-500:${designTokens["brand/500"]};`);
  });

  it("defines every design variable the stylesheet uses", () => {
    const stylesheet = readFileSync(
      path.join(import.meta.dirname, "..", "..", "app", "globals.css"),
      "utf8",
    );
    const used = new Set(stylesheet.match(/--ds-[a-z0-9-]+/g) ?? []);

    expect(used.size).toBeGreaterThan(0);
    const missing = [...used].filter((name) => !themeCss.includes(`${name}:`));
    expect(missing).toEqual([]);
  });
});
