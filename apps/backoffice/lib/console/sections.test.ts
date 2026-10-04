import { describe, expect, it } from "vitest";
import {
  availableSections,
  SECTION_PARAM,
  sectionFrom,
  sectionHref,
  sectionsWithChanges,
} from "./sections";

const demo = { isDemo: true };
const production = { isDemo: false };

describe("availableSections", () => {
  it("offers the four sections in a demonstration environment", () => {
    expect(availableSections(demo).map((section) => section.id)).toEqual([
      "home",
      "features",
      "resilience",
      "notifications",
    ]);
  });

  it("leaves the resilience lab out anywhere else", () => {
    expect(availableSections(production).map((section) => section.id)).toEqual([
      "home",
      "features",
      "notifications",
    ]);
  });
});

describe("sectionFrom", () => {
  it("opens the first section when the address names none", () => {
    expect(sectionFrom(null, demo)).toBe("home");
    expect(sectionFrom("", demo)).toBe("home");
  });

  it("opens the section the address names", () => {
    expect(sectionFrom("funcionalidades", demo)).toBe("features");
    expect(sectionFrom("resiliencia", demo)).toBe("resilience");
    expect(sectionFrom("notificaciones", demo)).toBe("notifications");
    expect(sectionFrom("inicio", demo)).toBe("home");
  });

  it("falls back to the first section for a name it does not know", () => {
    expect(sectionFrom("ajustes", demo)).toBe("home");
    expect(sectionFrom("FUNCIONALIDADES", demo)).toBe("home");
    expect(sectionFrom("__proto__", demo)).toBe("home");
  });

  it("falls back when the address names a section this environment lacks", () => {
    expect(sectionFrom("resiliencia", production)).toBe("home");
  });
});

describe("sectionHref", () => {
  it("names the section in the query and keeps the rest of it", () => {
    expect(sectionHref("features", "")).toBe(`?${SECTION_PARAM}=funcionalidades`);
    expect(sectionHref("notifications", "?otro=1")).toBe(
      `?otro=1&${SECTION_PARAM}=notificaciones`,
    );
  });

  it("replaces the section already named", () => {
    expect(sectionHref("home", `?${SECTION_PARAM}=resiliencia`)).toBe(
      `?${SECTION_PARAM}=inicio`,
    );
  });
});

describe("sectionsWithChanges", () => {
  it("names nothing when the draft is what is published", () => {
    expect(sectionsWithChanges({ home: 0, features: 0, resilience: 0 })).toEqual(
      new Set(),
    );
  });

  it("names each section that holds unpublished changes", () => {
    expect(sectionsWithChanges({ home: 2, features: 0, resilience: 1 })).toEqual(
      new Set(["home", "resilience"]),
    );
  });
});
