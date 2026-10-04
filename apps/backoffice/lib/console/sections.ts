import type { SectionChanges } from "@/lib/config/diff";

/**
 * The console is one editor split into sections. A section only chooses what
 * is on screen: the draft, the publish state and the selected segment belong
 * to the editor as a whole and survive a change of section.
 */
export type SectionId = "home" | "features" | "resilience" | "notifications";

export interface Section {
  id: SectionId;
  /** What the address shows; the interface is in Spanish, so is this. */
  slug: string;
  label: string;
  description: string;
  /** Whether what is edited here belongs to the selected segment. */
  perSegment: boolean;
  /** Whether an edit made here changes what the home shows. */
  showsPreview: boolean;
}

/** The query parameter that carries the section. */
export const SECTION_PARAM = "seccion";

const SECTIONS: readonly Section[] = [
  {
    id: "home",
    slug: "inicio",
    label: "Inicio",
    description: "Orden, visibilidad y banner del inicio de cada segmento.",
    perSegment: true,
    showsPreview: true,
  },
  {
    id: "features",
    slug: "funcionalidades",
    label: "Funcionalidades",
    description: "Lo que cada segmento puede usar en la aplicación.",
    perSegment: true,
    showsPreview: true,
  },
  {
    id: "resilience",
    slug: "resiliencia",
    label: "Resiliencia",
    description: "Fallos simulados para la demostración.",
    perSegment: false,
    showsPreview: true,
  },
  {
    id: "notifications",
    slug: "notificaciones",
    label: "Notificaciones",
    description: "Envía un aviso y revisa los últimos envíos.",
    perSegment: false,
    showsPreview: false,
  },
];

const FIRST_SECTION: SectionId = "home";

/** The resilience lab exists only where the environment is a demonstration. */
export function availableSections(environment: { isDemo: boolean }): Section[] {
  return SECTIONS.filter(
    (section) => section.id !== "resilience" || environment.isDemo,
  );
}

/**
 * The section an address asks for. Anything it does not name exactly, or a
 * section this environment does not have, opens the first one.
 */
export function sectionFrom(
  value: string | null,
  environment: { isDemo: boolean },
): SectionId {
  const named = availableSections(environment).find(
    (section) => section.slug === value,
  );
  return named?.id ?? FIRST_SECTION;
}

/** The query that opens a section, keeping whatever else the address carries. */
export function sectionHref(section: SectionId, search: string): string {
  const params = new URLSearchParams(search);
  const slug = SECTIONS.find((candidate) => candidate.id === section)?.slug;
  if (slug) params.set(SECTION_PARAM, slug);
  return `?${params.toString()}`;
}

/** The sections whose settings differ from what is published. */
export function sectionsWithChanges(changes: SectionChanges): Set<SectionId> {
  const edited = new Set<SectionId>();
  if (changes.home > 0) edited.add("home");
  if (changes.features > 0) edited.add("features");
  if (changes.resilience > 0) edited.add("resilience");
  return edited;
}
