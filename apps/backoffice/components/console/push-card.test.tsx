// @vitest-environment jsdom
import { cleanup, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { PushRecord } from "@/lib/push/types";
import { PushCard } from "./push-card";

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function row(overrides: Partial<PushRecord>): PushRecord {
  return {
    id: "push-1",
    createdAt: "2026-10-03T14:12:00.000Z",
    title: "Una novedad para ti",
    audienceLabel: "Un cliente",
    status: "sent",
    error: null,
    deliveredCount: null,
    failedCount: null,
    retryable: false,
    ...overrides,
  };
}

function renderCard(history: PushRecord[]) {
  render(
    <PushCard
      segmentId="starting"
      segmentLabel="Estoy empezando"
      destinations={["inbox", "transfer"]}
      initialHistory={history}
      dryRun={false}
    />,
  );
}

const historyRow = (title: string) => screen.getByText(title).closest("tr")!;

describe("PushCard history", () => {
  it("labels a partial delivery as such, with the devices reached", () => {
    renderCard([row({ status: "partial", deliveredCount: 1, failedCount: 2 })]);

    const cells = within(historyRow("Una novedad para ti"));
    expect(cells.getByText("Entrega parcial")).toBeTruthy();
    expect(cells.getByText("1 de 3 dispositivos")).toBeTruthy();
    expect(cells.queryByText("Enviado")).toBeNull();
  });

  it("offers a retry only for a send the server would retry", () => {
    renderCard([
      row({ id: "a", title: "Reintentable", status: "failed", retryable: true }),
      row({ id: "b", title: "Sin destinatario", status: "failed", retryable: false }),
      row({ id: "c", title: "En curso", status: "retrying" }),
    ]);

    expect(within(historyRow("Reintentable")).getByRole("button", { name: "Reintentar" })).toBeTruthy();
    expect(within(historyRow("Sin destinatario")).queryByRole("button")).toBeNull();
    expect(within(historyRow("En curso")).getByText("Reintentando")).toBeTruthy();
    expect(within(historyRow("En curso")).queryByRole("button")).toBeNull();
  });

  it("disables every retry button while one retry is pending", async () => {
    let answer: (response: Response) => void = () => {};
    const fetchMock = vi.fn(
      () => new Promise<Response>((resolve) => (answer = resolve)),
    );
    vi.stubGlobal("fetch", fetchMock);
    renderCard([
      row({ id: "a", title: "Primero", status: "failed", retryable: true }),
      row({ id: "b", title: "Segundo", status: "failed", retryable: true }),
    ]);

    await userEvent.click(
      within(historyRow("Primero")).getByRole("button", { name: "Reintentar" }),
    );

    const buttons = screen.getAllByRole("button", { name: /Reintenta/ });
    expect(buttons.every((button) => (button as HTMLButtonElement).disabled)).toBe(true);
    await userEvent.click(within(historyRow("Segundo")).getByRole("button"));
    expect(fetchMock).toHaveBeenCalledOnce();

    answer(
      Response.json({
        record: row({ id: "a", title: "Primero", status: "sent", retryable: false }),
      }),
    );
    expect(await within(historyRow("Primero")).findByText("Enviado")).toBeTruthy();
  });
});
