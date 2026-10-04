// @vitest-environment jsdom
import { cleanup, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { PublishOutcome } from "@/app/actions";
import { exampleConfig } from "@/test/support/fixtures";
import { Console, type ConsoleProps } from "./console";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn() }),
}));

afterEach(cleanup);

function renderConsole(overrides: Partial<ConsoleProps> = {}) {
  const publish = vi.fn<ConsoleProps["publish"]>();
  render(
    <Console
      loaded={{
        config: { ...exampleConfig(), configVersion: 14 },
        baseVersion: 14,
        source: "published",
        lastPublishedAt: "2026-10-03T13:40:00.000Z",
      }}
      customers={{ starting: 12, family: 1 }}
      pushHistory={[]}
      isDemo
      pushDryRun={false}
      adminEmail="ana@example.com"
      publish={publish}
      {...overrides}
    />,
  );
  return publish;
}

const publishButton = () => screen.getByRole("button", { name: "Publicar cambios" });
const hidePromo = () =>
  userEvent.click(screen.getByRole("switch", { name: "Mostrar Banner promocional" }));
const previewText = () => screen.getByTestId("preview-modules").textContent ?? "";

describe("Console", () => {
  it("publishes the draft on top of the version it loaded", async () => {
    const publish = renderConsole();
    publish.mockResolvedValue({
      ok: true,
      version: 15,
      publishedAt: "2026-10-03T14:00:00.000Z",
    });

    await hidePromo();
    await userEvent.click(publishButton());

    const request = publish.mock.calls[0]![0];
    expect(request.baseVersion).toBe(14);
    expect(
      request.draft.segments.starting!.modules.find((m) => m.id === "promo")?.visible,
    ).toBe(false);
    expect(await screen.findByText("Configuración v15")).toBeTruthy();
    expect(screen.getByText("Sin cambios pendientes")).toBeTruthy();
  });

  it("keeps the edits and offers to retry when the publication fails", async () => {
    const publish = renderConsole();
    publish.mockResolvedValueOnce({ ok: false, kind: "unavailable" });
    publish.mockResolvedValueOnce({
      ok: true,
      version: 15,
      publishedAt: "2026-10-03T14:00:00.000Z",
    });

    await hidePromo();
    await userEvent.click(publishButton());

    const banner = await screen.findByRole("alert");
    expect(banner.textContent).toContain(
      "No pudimos publicar los cambios. Tus ediciones siguen aquí.",
    );
    expect(screen.getByText("1 cambio sin publicar")).toBeTruthy();
    expect(screen.getByText("Configuración v14")).toBeTruthy();

    await userEvent.click(within(banner).getByRole("button", { name: "Reintentar" }));

    expect(await screen.findByText("Configuración v15")).toBeTruthy();
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("treats a request that never reached the server as a failed publication", async () => {
    const publish = renderConsole();
    publish.mockRejectedValue(new TypeError("Failed to fetch"));

    await hidePromo();
    await userEvent.click(publishButton());

    expect((await screen.findByRole("alert")).textContent).toContain(
      "No pudimos publicar los cambios",
    );
  });

  it("asks to reload after a version conflict and does not let it be retried", async () => {
    const publish = renderConsole();
    const conflict: PublishOutcome = { ok: false, kind: "conflict", storedVersion: 16 };
    publish.mockResolvedValue(conflict);

    await hidePromo();
    await userEvent.click(publishButton());

    const banner = await screen.findByRole("alert");
    expect(banner.textContent).toContain("versión v16");
    expect(within(banner).getByRole("button", { name: "Recargar" })).toBeTruthy();
    expect((publishButton() as HTMLButtonElement).disabled).toBe(true);
  });

  it("keeps publish disabled when the draft is edited after a conflict", async () => {
    const publish = renderConsole();
    publish.mockResolvedValue({ ok: false, kind: "conflict", storedVersion: 16 });

    await hidePromo();
    await userEvent.click(publishButton());
    await screen.findByRole("alert");
    await userEvent.click(screen.getByRole("switch", { name: "Mostrar Para ti" }));

    expect((publishButton() as HTMLButtonElement).disabled).toBe(true);
    expect(screen.getByRole("alert").textContent).toContain("versión v16");
    expect(publish).toHaveBeenCalledOnce();
  });

  it("locks the editing controls while a publication is in flight", async () => {
    const publish = renderConsole();
    let finish: (outcome: PublishOutcome) => void = () => {};
    publish.mockReturnValue(new Promise((resolve) => (finish = resolve)));

    await hidePromo();
    await userEvent.click(publishButton());

    const anySwitch = screen.getByRole("switch", { name: "Mostrar Para ti" });
    expect(anySwitch.matches(":disabled")).toBe(true);
    expect(
      screen.getByLabelText("Título", { selector: "#promo-title" }).matches(":disabled"),
    ).toBe(true);

    finish({ ok: true, version: 15, publishedAt: "2026-10-03T14:00:00.000Z" });
    expect(await screen.findByText("Configuración v15")).toBeTruthy();
    expect(
      screen.getByRole("switch", { name: "Mostrar Para ti" }).matches(":disabled"),
    ).toBe(false);
  });

  it("shows the preview in the order and visibility of the draft", async () => {
    renderConsole();
    expect(previewText().indexOf("Saldo total")).toBeLessThan(
      previewText().indexOf("Cuenta de ahorros"),
    );
    expect(previewText()).toContain("Protege tu próximo viaje");

    await userEvent.click(screen.getByRole("button", { name: "Bajar Saldo total" }));
    await hidePromo();

    expect(previewText().indexOf("Cuenta de ahorros")).toBeLessThan(
      previewText().indexOf("Saldo total"),
    );
    expect(previewText()).not.toContain("Protege tu próximo viaje");
  });

  it("cannot move the first module up nor the last one down", () => {
    renderConsole();

    const up = screen.getByRole("button", { name: "Subir Saldo total" });
    const down = screen.getByRole("button", { name: "Bajar Para ti" });

    expect((up as HTMLButtonElement).disabled).toBe(true);
    expect((down as HTMLButtonElement).disabled).toBe(true);
  });

  it("edits the segment that is selected and leaves the others alone", async () => {
    renderConsole();

    await userEvent.click(screen.getByRole("button", { name: /Patrimonio/ }));
    expect(previewText()).toContain("Inversiones");

    await userEvent.click(screen.getByRole("switch", { name: "Mostrar Inversiones" }));
    expect(previewText()).not.toContain("Inversiones");

    await userEvent.click(screen.getByRole("button", { name: /Estoy empezando/ }));
    expect(previewText()).toContain("Protege tu próximo viaje");
    expect(screen.getByText("1 cambio sin publicar")).toBeTruthy();
  });

  it("discards the edits and shows what is published again", async () => {
    renderConsole();

    await hidePromo();
    await userEvent.click(screen.getByRole("button", { name: "Descartar" }));

    expect(screen.getByText("Sin cambios pendientes")).toBeTruthy();
    expect(previewText()).toContain("Protege tu próximo viaje");
  });

  it("offers only the contract's destinations for the banner", () => {
    renderConsole();

    const options = within(screen.getByLabelText("Destino", { selector: "#promo-destination" }))
      .getAllByRole("option")
      .map((option) => (option as HTMLOptionElement).value);

    expect(options).toEqual(exampleConfig().destinations);
  });

  it("offers the resilience lab only in a demonstration environment", () => {
    renderConsole({ isDemo: false });

    expect(screen.queryByText("Laboratorio de resiliencia")).toBeNull();
    expect(screen.getByText("Producción")).toBeTruthy();
  });

  it("outside a demonstration, warns about published faults and lets them be removed", async () => {
    const publish = renderConsole({
      isDemo: false,
      loaded: {
        config: {
          ...exampleConfig(),
          configVersion: 14,
          resilience: {
            latencyMs: 4000,
            movementsUnavailable: true,
            partnerInsuranceUnavailable: false,
          },
        },
        baseVersion: 14,
        source: "published",
        lastPublishedAt: null,
      },
    });
    publish.mockResolvedValue({ ok: true, version: 15, publishedAt: "2026-10-03T14:00:00.000Z" });

    expect(
      screen.getByText(/La configuración publicada tiene fallos simulados activos/),
    ).toBeTruthy();
    await userEvent.click(screen.getByRole("button", { name: "Quitar fallos simulados" }));
    expect(screen.getByText("2 cambios sin publicar")).toBeTruthy();
    await userEvent.click(publishButton());

    expect(publish.mock.calls[0]![0].draft.resilience).toEqual({
      latencyMs: 0,
      movementsUnavailable: false,
      partnerInsuranceUnavailable: false,
    });
  });

  it("shows no fault warning when nothing is simulated", () => {
    renderConsole({ isDemo: false });

    expect(screen.queryByRole("button", { name: "Quitar fallos simulados" })).toBeNull();
  });

  it("shows simulated faults in the preview", async () => {
    renderConsole();

    await userEvent.click(
      screen.getByRole("switch", { name: "Servicio de movimientos no disponible" }),
    );

    expect(previewText()).toContain("No pudimos cargar tus movimientos");
  });

  it("hides what a switched-off feature gives access to", async () => {
    renderConsole();
    expect(previewText()).toContain("Transferir");

    await userEvent.click(screen.getByRole("switch", { name: "Transferencias" }));

    expect(previewText()).not.toContain("Transferir");
  });
});
