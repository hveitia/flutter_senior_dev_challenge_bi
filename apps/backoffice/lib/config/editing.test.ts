import { describe, expect, it } from "vitest";
import { exampleConfig } from "@/test/support/fixtures";
import {
  moveModule,
  promoOf,
  setFeature,
  setModuleVisible,
  setPromo,
  setResilience,
} from "./editing";
import { resilienceOf } from "./types";

function idsOf(config: ReturnType<typeof exampleConfig>, segment: string) {
  return config.segments[segment]!.modules.map((module) => module.id);
}

describe("moveModule", () => {
  it("moves a module to a later position and keeps the others in order", () => {
    const moved = moveModule(exampleConfig(), "starting", 0, 2);

    expect(idsOf(moved, "starting")).toEqual([
      "accounts",
      "actions",
      "balance",
      "promo",
      "movements",
      "services",
    ]);
  });

  it("moves a module to an earlier position", () => {
    const moved = moveModule(exampleConfig(), "starting", 5, 0);

    expect(idsOf(moved, "starting")[0]).toBe("services");
    expect(idsOf(moved, "starting")).toHaveLength(6);
  });

  it("changes only the chosen segment", () => {
    const original = exampleConfig();
    const moved = moveModule(original, "starting", 0, 1);

    expect(idsOf(moved, "family")).toEqual(idsOf(original, "family"));
  });

  it("does not modify the configuration it receives", () => {
    const original = exampleConfig();
    const before = structuredClone(original);

    moveModule(original, "starting", 0, 3);

    expect(original).toEqual(before);
  });

  it("returns the same configuration when the move leads nowhere", () => {
    const original = exampleConfig();

    expect(moveModule(original, "starting", 0, -1)).toBe(original);
    expect(moveModule(original, "starting", 5, 6)).toBe(original);
    expect(moveModule(original, "starting", 2, 2)).toBe(original);
    expect(moveModule(original, "unknown", 0, 1)).toBe(original);
  });
});

describe("setModuleVisible", () => {
  it("hides one module by id", () => {
    const edited = setModuleVisible(exampleConfig(), "starting", "promo", false);

    const promo = edited.segments.starting!.modules.find(
      (module) => module.id === "promo",
    );
    expect(promo?.visible).toBe(false);
  });

  it("keeps the module settings when its visibility changes", () => {
    const original = exampleConfig();
    const edited = setModuleVisible(original, "starting", "movements", false);

    const movements = edited.segments.starting!.modules.find(
      (module) => module.id === "movements",
    );
    expect(movements?.props).toEqual({ limit: 4 });
  });

  it("returns the same configuration when nothing changes", () => {
    const original = exampleConfig();

    expect(setModuleVisible(original, "starting", "promo", true)).toBe(original);
    expect(setModuleVisible(original, "starting", "missing", false)).toBe(
      original,
    );
  });
});

describe("promo banner", () => {
  it("reads the banner fields of a segment", () => {
    expect(promoOf(exampleConfig().segments.starting!)).toEqual({
      moduleId: "promo",
      title: "Protege tu próximo viaje",
      body: "Cotiza tu seguro en menos de un minuto",
      actionLabel: "Cotizar",
      destination: "partner:travelInsurance",
    });
  });

  it("reads nothing from a segment without a banner", () => {
    const config = exampleConfig();
    const segment = config.segments.starting!;
    segment.modules = segment.modules.filter(
      (module) => module.type !== "promoBanner",
    );

    expect(promoOf(segment)).toBeNull();
  });

  it("changes one field and leaves the others as they were", () => {
    const edited = setPromo(exampleConfig(), "starting", { title: "Viaja tranquilo" });

    expect(promoOf(edited.segments.starting!)).toEqual({
      moduleId: "promo",
      title: "Viaja tranquilo",
      body: "Cotiza tu seguro en menos de un minuto",
      actionLabel: "Cotizar",
      destination: "partner:travelInsurance",
    });
  });

  it("changes the action label and its destination", () => {
    const edited = setPromo(exampleConfig(), "starting", {
      actionLabel: "Transferir",
      destination: "transfer",
    });

    const promo = promoOf(edited.segments.starting!);
    expect(promo?.actionLabel).toBe("Transferir");
    expect(promo?.destination).toBe("transfer");
  });

  it("changes only the chosen segment's banner", () => {
    const edited = setPromo(exampleConfig(), "starting", { title: "Otro" });

    expect(promoOf(edited.segments.wealth!)?.title).toBe(
      "Mueve tu dinero sin costo",
    );
  });
});

describe("setFeature", () => {
  it("turns one feature off for one segment", () => {
    const edited = setFeature(exampleConfig(), "family", "transfers", false);

    expect(edited.segments.family!.features).toEqual({
      transfers: false,
      partnerServices: true,
    });
    expect(edited.segments.starting!.features.transfers).toBe(true);
  });
});

describe("setResilience", () => {
  it("changes one fault and states the rest", () => {
    const edited = setResilience(exampleConfig(), { latencyMs: 2000 });

    expect(resilienceOf(edited)).toEqual({
      latencyMs: 2000,
      movementsUnavailable: false,
      partnerInsuranceUnavailable: false,
    });
  });

  it("adds the block to a configuration published without it", () => {
    const config = exampleConfig();
    delete config.resilience;

    const edited = setResilience(config, { movementsUnavailable: true });

    expect(edited.resilience?.movementsUnavailable).toBe(true);
  });
});
