// @vitest-environment jsdom
import { cleanup, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { availableSections, type SectionId } from "@/lib/console/sections";
import { SectionNav } from "./section-nav";

afterEach(cleanup);

function renderNav({
  current = "home",
  edited = new Set<SectionId>(),
  isDemo = true,
}: {
  current?: SectionId;
  edited?: Set<SectionId>;
  isDemo?: boolean;
} = {}) {
  const onSelect = vi.fn();
  render(
    <SectionNav
      sections={availableSections({ isDemo })}
      current={current}
      edited={edited}
      hrefOf={(section) => `?seccion=${section}`}
      onSelect={onSelect}
    />,
  );
  return onSelect;
}

const nav = () => screen.getByRole("navigation", { name: "Secciones de la consola" });

describe("SectionNav", () => {
  it("is a navigation landmark with one link per section", () => {
    renderNav();

    const links = within(nav()).getAllByRole("link");

    expect(links.map((link) => link.textContent)).toEqual([
      "Inicio",
      "Funcionalidades",
      "Resiliencia",
      "Notificaciones",
    ]);
  });

  it("marks only the open section as the current page", () => {
    renderNav({ current: "features" });

    const current = within(nav())
      .getAllByRole("link")
      .filter((link) => link.getAttribute("aria-current") === "page");

    expect(current.map((link) => link.textContent)).toEqual(["Funcionalidades"]);
  });

  it("gives each link an address of its own, so it can be opened in a new tab", () => {
    renderNav();

    expect(
      within(nav()).getByRole("link", { name: "Notificaciones" }).getAttribute("href"),
    ).toBe("?seccion=notifications");
  });

  it("says which sections hold unpublished changes, not only shows it", () => {
    renderNav({ edited: new Set<SectionId>(["features"]) });

    expect(
      within(nav()).getByRole("link", {
        name: "Funcionalidades, con cambios sin publicar",
      }),
    ).toBeTruthy();
    expect(within(nav()).getByRole("link", { name: "Inicio" })).toBeTruthy();
  });

  it("opens a section on click without leaving the page", async () => {
    const onSelect = renderNav();

    await userEvent.click(within(nav()).getByRole("link", { name: "Resiliencia" }));

    expect(onSelect).toHaveBeenCalledWith("resilience");
  });

  it("opens a section with the keyboard", async () => {
    const onSelect = renderNav();

    within(nav()).getByRole("link", { name: "Funcionalidades" }).focus();
    await userEvent.keyboard("{Enter}");

    expect(onSelect).toHaveBeenCalledWith("features");
  });

  it("leaves a click meant for a new tab to the browser", async () => {
    const onSelect = renderNav();
    const user = userEvent.setup();

    await user.keyboard("{Meta>}");
    await user.click(within(nav()).getByRole("link", { name: "Resiliencia" }));
    await user.keyboard("{/Meta}");

    expect(onSelect).not.toHaveBeenCalled();
  });
});
