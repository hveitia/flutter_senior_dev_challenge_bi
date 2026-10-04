import type { MouseEvent } from "react";
import type { Section, SectionId } from "@/lib/console/sections";

export interface SectionNavProps {
  sections: Section[];
  current: SectionId;
  /** Sections whose settings differ from what is published. */
  edited: Set<SectionId>;
  hrefOf: (section: SectionId) => string;
  onSelect: (section: SectionId) => void;
}

/** A click the browser should handle itself: a new tab, a new window, a download. */
function isForTheBrowser(event: MouseEvent): boolean {
  return (
    event.button !== 0 ||
    event.metaKey ||
    event.ctrlKey ||
    event.shiftKey ||
    event.altKey
  );
}

/**
 * The console's menu. Each entry is a real link, so a section has an address
 * that can be reloaded, shared or opened in another tab; a plain click only
 * changes what is on screen.
 */
export function SectionNav({
  sections,
  current,
  edited,
  hrefOf,
  onSelect,
}: SectionNavProps) {
  return (
    <nav
      aria-label="Secciones de la consola"
      className="border-b border-line bg-surface-0 px-6"
    >
      <ul className="flex flex-wrap gap-1">
        {sections.map((section) => {
          const isCurrent = section.id === current;
          return (
            <li key={section.id}>
              <a
                href={hrefOf(section.id)}
                aria-current={isCurrent ? "page" : undefined}
                onClick={(event) => {
                  if (isForTheBrowser(event)) return;
                  event.preventDefault();
                  onSelect(section.id);
                }}
                className={`-mb-px flex items-center gap-2 border-b-2 px-3 py-3 text-body ${
                  isCurrent
                    ? "border-brand-500 font-semibold text-ink-900"
                    : "border-transparent text-secondary hover:text-ink-900"
                }`}
              >
                {section.label}
                {edited.has(section.id) ? (
                  <>
                    <span aria-hidden className="size-2 rounded-chip bg-brand-500" />
                    <span className="sr-only">, con cambios sin publicar</span>
                  </>
                ) : null}
              </a>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
