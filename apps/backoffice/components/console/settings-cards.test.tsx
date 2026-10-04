// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ResilienceCard } from "./settings-cards";

afterEach(cleanup);

function renderCard(latencyMs: number) {
  render(
    <ResilienceCard
      resilience={{
        latencyMs,
        movementsUnavailable: false,
        partnerInsuranceUnavailable: false,
      }}
      onChange={vi.fn()}
    />,
  );
  return screen.getByRole("slider") as HTMLInputElement;
}

describe("ResilienceCard", () => {
  it("shows a latency within the slider's usual range", () => {
    const slider = renderCard(2000);

    expect(screen.getByText("Latencia simulada: 2 s")).toBeTruthy();
    expect(slider.value).toBe("2");
    expect(slider.max).toBe("8");
  });

  it("shows a published latency above the usual range as it is", () => {
    const slider = renderCard(10000);

    expect(screen.getByText("Latencia simulada: 10 s")).toBeTruthy();
    expect(slider.value).toBe("10");
  });

  it("shows a latency that is not a whole number of seconds without rounding the label", () => {
    renderCard(2500);

    expect(screen.getByText("Latencia simulada: 2.5 s")).toBeTruthy();
  });
});
