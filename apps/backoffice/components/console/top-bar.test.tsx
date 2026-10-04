// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { TopBar, type TopBarProps } from "./top-bar";

afterEach(cleanup);

function renderBar(overrides: Partial<TopBarProps> = {}) {
  const props: TopBarProps = {
    configVersion: 14,
    isDemo: true,
    lastPublishedAt: "2026-10-03T13:40:00.000Z",
    changes: 0,
    canPublish: false,
    publishing: false,
    adminEmail: "ana@example.com",
    onPublish: vi.fn(),
    onDiscard: vi.fn(),
    onSignOut: vi.fn(),
    ...overrides,
  };
  render(<TopBar {...props} />);
  return props;
}

const publishButton = () =>
  screen.getByRole("button", { name: /^(Publicar cambios|Publicando…)$/ });

describe("TopBar", () => {
  it("shows the live version, the environment and the last publication", () => {
    renderBar();

    expect(screen.getByText("Configuración v14")).toBeTruthy();
    expect(screen.getByText("Demostración")).toBeTruthy();
    expect(screen.getByText("Última publicación: 3 oct, 08:40")).toBeTruthy();
  });

  it("without changes, says so and does not let anything be published or discarded", () => {
    renderBar();

    expect(screen.getByText("Sin cambios pendientes")).toBeTruthy();
    expect((publishButton() as HTMLButtonElement).disabled).toBe(true);
    expect(screen.queryByRole("button", { name: "Descartar" })).toBeNull();
  });

  it("with changes, counts them and offers to publish or discard", async () => {
    const props = renderBar({ changes: 3, canPublish: true });

    expect(screen.getByText("3 cambios sin publicar")).toBeTruthy();
    await userEvent.click(publishButton());
    await userEvent.click(screen.getByRole("button", { name: "Descartar" }));

    expect(props.onPublish).toHaveBeenCalledOnce();
    expect(props.onDiscard).toHaveBeenCalledOnce();
  });

  it("counts a single change in the singular", () => {
    renderBar({ changes: 1, canPublish: true });

    expect(screen.getByText("1 cambio sin publicar")).toBeTruthy();
  });

  it("while publishing, says so and does not accept a second click", async () => {
    const props = renderBar({ changes: 3, canPublish: false, publishing: true });

    expect(publishButton().textContent).toBe("Publicando…");
    await userEvent.click(publishButton());

    expect(props.onPublish).not.toHaveBeenCalled();
  });

  it("keeps the changes visible after a failed publication so it can be retried", () => {
    renderBar({ changes: 3, canPublish: true });

    expect(screen.getByText("3 cambios sin publicar")).toBeTruthy();
    expect((publishButton() as HTMLButtonElement).disabled).toBe(false);
  });

  it("says that nothing is published yet and lets the first version go out", () => {
    renderBar({ configVersion: null, lastPublishedAt: null, canPublish: true });

    expect(screen.getByText("Configuración sin publicar")).toBeTruthy();
    expect(screen.queryByText(/Última publicación/)).toBeNull();
    expect((publishButton() as HTMLButtonElement).disabled).toBe(false);
  });

  it("names the environment as production outside a demonstration", () => {
    renderBar({ isDemo: false });

    expect(screen.getByText("Producción")).toBeTruthy();
    expect(screen.queryByText("Demostración")).toBeNull();
  });

  it("shows who is signed in and lets them leave", async () => {
    const props = renderBar();

    expect(screen.getByText("ana@example.com")).toBeTruthy();
    await userEvent.click(screen.getByRole("button", { name: "Cerrar sesión" }));

    expect(props.onSignOut).toHaveBeenCalledOnce();
  });
});
