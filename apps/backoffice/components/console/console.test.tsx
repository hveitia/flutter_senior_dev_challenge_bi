// @vitest-environment jsdom
import { cleanup, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { PublishOutcome } from "@/app/actions";
import { exampleConfig } from "@/test/support/fixtures";
import { openAddress } from "@/test/support/location-search";
import { Console, type ConsoleProps } from "./console";

const router = vi.hoisted(() => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }));

vi.mock("next/navigation", async () => {
  const { useLocationSearch } = await import("@/test/support/location-search");
  return { useRouter: () => router, useSearchParams: useLocationSearch };
});

afterEach(() => {
  cleanup();
  openAddress("");
  vi.clearAllMocks();
});

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
const sections = () =>
  screen.getByRole("navigation", { name: "Secciones de la consola" });
const openSection = (name: string | RegExp) =>
  userEvent.click(within(sections()).getByRole("link", { name }));
const currentSection = () =>
  within(sections())
    .getAllByRole("link")
    .filter((link) => link.getAttribute("aria-current") === "page")
    .map((link) => link.textContent);

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

  it("announces a successful publication to assistive technology", async () => {
    const publish = renderConsole();
    publish.mockResolvedValue({
      ok: true,
      version: 15,
      publishedAt: "2026-10-03T14:00:00.000Z",
    });
    expect(screen.getByTestId("announcer").getAttribute("aria-live")).toBe("polite");

    await hidePromo();
    await userEvent.click(publishButton());
    await screen.findByText("Configuración v15");

    expect(screen.getByTestId("announcer").textContent).toBe(
      "Configuración v15 publicada",
    );
  });

  it("keeps focus on the moved module and announces its new position", async () => {
    renderConsole();

    await userEvent.click(screen.getByRole("button", { name: "Bajar Saldo total" }));

    expect(document.activeElement).toBe(
      screen.getByRole("button", { name: "Bajar Saldo total" }),
    );
    expect(screen.getByTestId("announcer").textContent).toBe(
      "Saldo total, posición 2 de 6",
    );
  });

  it("moves focus to the opposite arrow when the module reaches an end", async () => {
    renderConsole();

    await userEvent.click(
      screen.getByRole("button", { name: "Bajar Últimos movimientos" }),
    );

    expect(document.activeElement).toBe(
      screen.getByRole("button", { name: "Subir Últimos movimientos" }),
    );
  });

  it("can keep moving a module with the keyboard alone", async () => {
    renderConsole();

    screen.getByRole("button", { name: "Bajar Saldo total" }).focus();
    await userEvent.keyboard("{Enter}{Enter}");

    expect(screen.getByTestId("announcer").textContent).toBe(
      "Saldo total, posición 3 de 6",
    );
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
    await openSection("Resiliencia");

    await userEvent.click(
      screen.getByRole("switch", { name: "Servicio de movimientos no disponible" }),
    );

    expect(previewText()).toContain("No pudimos cargar tus movimientos");
  });

  it("hides what a switched-off feature gives access to", async () => {
    renderConsole();
    expect(previewText()).toContain("Transferir");
    await openSection("Funcionalidades");

    await userEvent.click(screen.getByRole("switch", { name: "Transferencias" }));

    expect(previewText()).not.toContain("Transferir");
  });
});

describe("Console sections", () => {
  it("opens on the home section, with the others one link away", () => {
    renderConsole();

    expect(currentSection()).toEqual(["Inicio"]);
    expect(screen.getByRole("switch", { name: "Mostrar Banner promocional" })).toBeTruthy();
    expect(screen.queryByRole("switch", { name: "Transferencias" })).toBeNull();
    expect(screen.queryByRole("button", { name: "Enviar" })).toBeNull();
  });

  it("shows one section at a time", async () => {
    renderConsole();

    await openSection("Funcionalidades");

    expect(currentSection()).toEqual(["Funcionalidades"]);
    expect(screen.getByRole("switch", { name: "Transferencias" })).toBeTruthy();
    expect(screen.queryByRole("switch", { name: "Mostrar Banner promocional" })).toBeNull();
    expect(
      screen.getByRole("heading", { level: 2, name: "Funcionalidades" }),
    ).toBeTruthy();
  });

  it("puts the open section in the address without asking the server again", async () => {
    renderConsole();

    await openSection("Notificaciones");

    expect(window.location.search).toBe("?seccion=notificaciones");
    expect(router.push).not.toHaveBeenCalled();
    expect(router.replace).not.toHaveBeenCalled();
    expect(router.refresh).not.toHaveBeenCalled();
  });

  it("opens the section the address names", () => {
    openAddress("?seccion=funcionalidades");
    renderConsole();

    expect(currentSection()).toEqual(["Funcionalidades"]);
    expect(screen.getByRole("switch", { name: "Transferencias" })).toBeTruthy();
  });

  it("falls back to the home section for an address it does not know", () => {
    openAddress("?seccion=ajustes");
    renderConsole();

    expect(currentSection()).toEqual(["Inicio"]);
    expect(screen.getByRole("switch", { name: "Mostrar Banner promocional" })).toBeTruthy();
  });

  it("goes back to the previous section with the browser's back button", async () => {
    renderConsole();
    await openSection("Funcionalidades");
    await openSection("Notificaciones");

    window.history.back();

    await waitFor(() => expect(currentSection()).toEqual(["Funcionalidades"]));
  });

  it("keeps the edits of one section while another is open", async () => {
    const publish = renderConsole();
    publish.mockResolvedValue({
      ok: true,
      version: 15,
      publishedAt: "2026-10-03T14:00:00.000Z",
    });

    await hidePromo();
    await openSection("Funcionalidades");
    await userEvent.click(screen.getByRole("switch", { name: "Transferencias" }));
    await openSection(/Inicio/);

    expect(
      screen
        .getByRole("switch", { name: "Mostrar Banner promocional" })
        .getAttribute("aria-checked"),
    ).toBe("false");
    expect(screen.getByText("2 cambios sin publicar")).toBeTruthy();

    await openSection("Notificaciones");
    await userEvent.click(publishButton());

    const { draft } = publish.mock.calls[0]![0];
    expect(draft.segments.starting!.modules.find((m) => m.id === "promo")?.visible).toBe(
      false,
    );
    expect(draft.segments.starting!.features.transfers).toBe(false);
  });

  it("shows the pending changes and the publish controls in every section", async () => {
    renderConsole();
    await hidePromo();

    for (const name of [/Funcionalidades/, /Resiliencia/, /Notificaciones/, /Inicio/]) {
      await openSection(name);

      expect(screen.getByText("1 cambio sin publicar")).toBeTruthy();
      expect((publishButton() as HTMLButtonElement).disabled).toBe(false);
      expect(screen.getByRole("button", { name: "Descartar" })).toBeTruthy();
    }
  });

  it("shows a failed publication in whichever section is open", async () => {
    const publish = renderConsole();
    publish.mockResolvedValue({ ok: false, kind: "unavailable" });
    await hidePromo();
    await userEvent.click(publishButton());
    await screen.findByRole("alert");

    await openSection("Notificaciones");

    expect(screen.getByRole("alert").textContent).toContain(
      "No pudimos publicar los cambios",
    );
  });

  it("marks in the menu the sections that hold unpublished changes", async () => {
    renderConsole();

    await hidePromo();
    await openSection("Resiliencia");
    await userEvent.click(
      screen.getByRole("switch", { name: "Servicio de movimientos no disponible" }),
    );

    const menu = within(sections());
    expect(menu.getByRole("link", { name: "Inicio, con cambios sin publicar" })).toBeTruthy();
    expect(
      menu.getByRole("link", { name: "Resiliencia, con cambios sin publicar" }),
    ).toBeTruthy();
    expect(menu.getByRole("link", { name: "Funcionalidades" })).toBeTruthy();
    expect(menu.getByRole("link", { name: "Notificaciones" })).toBeTruthy();
  });

  it("clears the marks once the changes are discarded", async () => {
    renderConsole();
    await hidePromo();

    await userEvent.click(screen.getByRole("button", { name: "Descartar" }));

    expect(within(sections()).getByRole("link", { name: "Inicio" })).toBeTruthy();
  });

  it("has no resilience section outside a demonstration environment", () => {
    openAddress("?seccion=resiliencia");
    renderConsole({ isDemo: false });

    expect(within(sections()).queryByRole("link", { name: /Resiliencia/ })).toBeNull();
    expect(currentSection()).toEqual(["Inicio"]);
    expect(screen.queryByText("Laboratorio de resiliencia")).toBeNull();
  });

  it("keeps the warning about published faults in view from any section", async () => {
    renderConsole({
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

    await openSection("Notificaciones");

    expect(screen.getByRole("button", { name: "Quitar fallos simulados" })).toBeTruthy();
  });

  it("keeps what was typed in the notification composer", async () => {
    renderConsole();
    await openSection("Notificaciones");
    const title = () => screen.getByRole("textbox", { name: "Título" });
    await userEvent.type(title(), "Nueva tarifa");

    await openSection("Inicio");
    await openSection("Notificaciones");

    expect((title() as HTMLInputElement).value).toBe("Nueva tarifa");
  });

  it("shows the preview where an edit changes the home, and not among notifications", async () => {
    renderConsole();
    const preview = () => screen.queryByRole("complementary", { name: "Vista previa" });

    expect(preview()).toBeTruthy();
    await openSection("Funcionalidades");
    expect(preview()).toBeTruthy();
    await openSection("Resiliencia");
    expect(preview()).toBeTruthy();
    await openSection("Notificaciones");
    expect(preview()).toBeNull();
  });

  it("says what the selected segment means in each section", async () => {
    renderConsole();
    const segments = () => screen.getByRole("navigation", { name: "Segmentos" });

    expect(segments().textContent).toContain(
      "Los cambios de esta sección se aplican al segmento seleccionado.",
    );
    await openSection("Resiliencia");
    expect(segments().textContent).toContain(
      "Estos ajustes valen para todos los segmentos.",
    );
    await openSection("Notificaciones");
    expect(segments().textContent).toContain(
      "Un envío a un segmento se dirige al segmento seleccionado.",
    );
  });

  it("keeps the selected segment across sections", async () => {
    renderConsole();
    await userEvent.click(screen.getByRole("button", { name: /Patrimonio/ }));

    await openSection("Funcionalidades");

    expect(
      screen.getByRole("button", { name: /Patrimonio/ }).getAttribute("aria-current"),
    ).toBe("true");
    expect(previewText()).toContain("Inversiones");
  });

  it("offers a way to skip the menus and tells assistive technology which section opened", async () => {
    renderConsole();

    const skip = screen.getByRole("link", { name: "Saltar al contenido" });
    expect(skip.getAttribute("href")).toBe("#contenido");
    expect(screen.getByRole("main").id).toBe("contenido");

    await openSection("Funcionalidades");

    expect(screen.getByTestId("announcer").textContent).toBe("Sección Funcionalidades");
  });

  it("keeps the headings in order: the console, the section, its cards", async () => {
    renderConsole();

    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe(
      "Consola de experiencia",
    );
    expect(screen.getByRole("heading", { level: 2, name: "Inicio" })).toBeTruthy();
    expect(
      screen.getByRole("heading", { level: 3, name: "Módulos del inicio" }),
    ).toBeTruthy();
  });
});
