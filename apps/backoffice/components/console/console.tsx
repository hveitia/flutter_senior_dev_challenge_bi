"use client";

import { useRouter, useSearchParams } from "next/navigation";
import {
  useEffect,
  useReducer,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { PublishOutcome } from "@/app/actions";
import { changesBySection } from "@/lib/config/diff";
import {
  moveModule,
  promoOf,
  setFeature,
  setModuleVisible,
  setPromo,
  setResilience,
} from "@/lib/config/editing";
import { moduleLabel } from "@/lib/config/labels";
import {
  hasFaults,
  NO_FAULTS,
  resilienceOf,
  type HomeConfig,
} from "@/lib/config/types";
import {
  canPublish,
  editorReducer,
  initialEditorState,
  isPublishing,
  pendingChanges,
  type LoadedConfig,
} from "@/lib/console/editor-state";
import {
  availableSections,
  SECTION_PARAM,
  sectionFrom,
  sectionHref,
  sectionsWithChanges,
  type Section,
  type SectionId,
} from "@/lib/console/sections";
import type { PushRecord } from "@/lib/push/types";
import { AlertIcon, Button } from "../ui";
import { ModulesCard } from "./modules-card";
import { PhonePreview } from "./phone-preview";
import { PublishFailureBanner } from "./publish-failure-banner";
import { PushCard } from "./push-card";
import { SectionNav } from "./section-nav";
import { SegmentList } from "./segment-list";
import { FeaturesCard, PromoCard, ResilienceCard } from "./settings-cards";
import { TopBar } from "./top-bar";

const LOGIN_PATH = "/login";
const CONTENT_ID = "contenido";
/** Custom property with the height of the bar that stays at the top. */
const HEADER_HEIGHT = "--console-header";

export interface ConsoleProps {
  loaded: LoadedConfig;
  customers: Record<string, number>;
  pushHistory: PushRecord[];
  isDemo: boolean;
  pushDryRun: boolean;
  adminEmail: string;
  publish: (request: {
    draft: HomeConfig;
    baseVersion: number | null;
  }) => Promise<PublishOutcome>;
}

/**
 * One section of the console. Every section stays mounted and only the open
 * one is shown: what was typed in another, the notification composer
 * included, is still there when the editor comes back to it.
 */
function SectionPanel({
  section,
  current,
  children,
}: {
  section: Section;
  current: SectionId;
  children: ReactNode;
}) {
  const headingId = `seccion-${section.slug}`;
  return (
    <section
      hidden={section.id !== current}
      aria-labelledby={headingId}
      className="grid min-w-0 gap-5"
    >
      <header>
        <h2 id={headingId} className="font-heading text-subtitle">
          {section.label}
        </h2>
        <p className="mt-1 text-caption text-secondary">{section.description}</p>
      </header>
      {children}
    </section>
  );
}

/**
 * The editor: one draft, edited across the sections and published as a whole.
 * A section is a view of that draft, so the pending changes and the publish
 * controls live in the top bar, above whichever section is open.
 */
export function Console({
  loaded,
  customers,
  pushHistory,
  isDemo,
  pushDryRun,
  adminEmail,
  publish,
}: ConsoleProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [state, dispatch] = useReducer(editorReducer, loaded, initialEditorState);
  const segmentId = state.selectedSegment;
  const segment = state.draft.segments[segmentId];
  const edit = (draft: HomeConfig) => dispatch({ type: "edited", draft });
  // Read out by screen readers: what just happened that sight alone shows.
  const [announcement, setAnnouncement] = useState("");

  const sections = availableSections({ isDemo });
  const sectionId = sectionFrom(searchParams.get(SECTION_PARAM), { isDemo });
  const section = sections.find((candidate) => candidate.id === sectionId);
  const byId = (id: SectionId) => sections.find((candidate) => candidate.id === id);

  // The preview stays in view under the bar that sticks to the top, whose
  // height changes when its content wraps on a narrower window.
  const frameRef = useRef<HTMLDivElement>(null);
  const headerRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const frame = frameRef.current;
    const header = headerRef.current;
    if (!frame || !header || typeof ResizeObserver === "undefined") return;
    const observer = new ResizeObserver(() => {
      frame.style.setProperty(HEADER_HEIGHT, `${header.offsetHeight}px`);
    });
    observer.observe(header);
    return () => observer.disconnect();
  }, []);

  /**
   * Opens a section by writing it into the address. The framework follows
   * the address without asking the server again, so the draft is untouched
   * and the back button returns to the previous section.
   */
  function openSection(id: SectionId) {
    if (id === sectionId) return;
    window.history.pushState(null, "", sectionHref(id, window.location.search));
    const opened = byId(id);
    if (opened) setAnnouncement(`Sección ${opened.label}`);
  }

  async function publishDraft() {
    dispatch({ type: "publish-started" });
    try {
      const outcome = await publish({
        draft: state.draft,
        baseVersion: state.baseVersion,
      });
      if (outcome.ok) {
        dispatch({
          type: "publish-succeeded",
          version: outcome.version,
          publishedAt: outcome.publishedAt,
        });
        setAnnouncement(`Configuración v${outcome.version} publicada`);
      } else {
        dispatch({ type: "publish-failed", failure: outcome });
      }
    } catch {
      // The request never reached the server, or its answer never came back.
      dispatch({ type: "publish-failed", failure: { kind: "unavailable" } });
    }
  }

  async function signOut() {
    await fetch("/api/session", { method: "DELETE" });
    router.replace(LOGIN_PATH);
  }

  if (!segment || !section) {
    return <p className="p-6 text-body">La configuración no tiene segmentos.</p>;
  }

  const home = byId("home");
  const features = byId("features");
  const resilience = byId("resilience");
  const notifications = byId("notifications");

  return (
    <div ref={frameRef} className="min-h-screen">
      <a
        href={`#${CONTENT_ID}`}
        className="sr-only rounded-admin bg-surface-0 px-3 py-2 text-body font-semibold text-ink-900 focus:not-sr-only focus:absolute focus:left-3 focus:top-3 focus:z-20"
      >
        Saltar al contenido
      </a>
      <p role="status" aria-live="polite" className="sr-only" data-testid="announcer">
        {announcement}
      </p>
      <div ref={headerRef} className="sticky top-0 z-10">
        <TopBar
          configVersion={state.source === "published" ? state.baseVersion : null}
          isDemo={isDemo}
          lastPublishedAt={state.lastPublishedAt}
          changes={pendingChanges(state)}
          canPublish={canPublish(state)}
          publishing={isPublishing(state)}
          adminEmail={adminEmail}
          onPublish={publishDraft}
          onDiscard={() => dispatch({ type: "discarded" })}
          onSignOut={signOut}
        />
        <SectionNav
          sections={sections}
          current={sectionId}
          edited={sectionsWithChanges(changesBySection(state.published, state.draft))}
          hrefOf={(id) => sectionHref(id, searchParams.toString())}
          onSelect={openSection}
        />
      </div>
      <div
        className={`mx-auto grid max-w-[1440px] items-start gap-5 p-5 ${
          section.showsPreview
            ? "lg:grid-cols-[minmax(0,1fr)_340px] xl:grid-cols-[232px_minmax(0,1fr)_340px]"
            : "xl:grid-cols-[232px_minmax(0,1fr)]"
        }`}
      >
        {/* Beside the content on wide screens, across the top otherwise. */}
        <div className={section.showsPreview ? "lg:col-span-2 xl:col-span-1" : ""}>
          <SegmentList
            segments={state.draft.segments}
            selected={segmentId}
            customers={customers}
            note={section.segmentNote}
            onSelect={(id) => dispatch({ type: "segment-selected", segmentId: id })}
          />
        </div>

        <main id={CONTENT_ID} tabIndex={-1} className="grid min-w-0 gap-5">
          {state.publication.status === "failed" ? (
            <PublishFailureBanner
              failure={state.publication.failure}
              onRetry={publishDraft}
              onReload={() => window.location.reload()}
              onSignIn={() => router.replace(LOGIN_PATH)}
            />
          ) : null}
          {/* Disabled as a group while publishing: the draft on screen is
              what was sent, and stays that way until the answer arrives. */}
          <fieldset
            disabled={isPublishing(state)}
            className="m-0 grid min-w-0 gap-5 border-0 p-0"
          >
            {!isDemo && hasFaults(resilienceOf(state.draft)) ? (
              // The lab does not exist here, but faults published from a
              // demonstration would otherwise stay live with no way out. It
              // affects every publication, so it shows above every section.
              <div
                role="status"
                className="flex items-center gap-3 rounded-admin border border-warning-500 bg-warning-tint px-4 py-3 text-warning-500"
              >
                <AlertIcon />
                <p className="flex-1 text-body">
                  La configuración publicada tiene fallos simulados activos. Este
                  entorno no permite añadirlos, solo quitarlos.
                </p>
                <Button
                  variant="text"
                  className="text-warning-500"
                  onClick={() => edit(setResilience(state.draft, NO_FAULTS))}
                >
                  Quitar fallos simulados
                </Button>
              </div>
            ) : null}
            {home ? (
              <SectionPanel section={home} current={sectionId}>
                <ModulesCard
                  modules={segment.modules}
                  onMove={(from, to) => {
                    const moved = segment.modules[from];
                    const next = moveModule(state.draft, segmentId, from, to);
                    if (!moved || next === state.draft) return;
                    edit(next);
                    setAnnouncement(
                      `${moduleLabel(moved.type)}, posición ${to + 1} de ${segment.modules.length}`,
                    );
                  }}
                  onVisibilityChange={(moduleId, visible) =>
                    edit(setModuleVisible(state.draft, segmentId, moduleId, visible))
                  }
                />
                <PromoCard
                  promo={promoOf(segment)}
                  destinations={state.draft.destinations}
                  onChange={(patch) => edit(setPromo(state.draft, segmentId, patch))}
                />
              </SectionPanel>
            ) : null}
            {features ? (
              <SectionPanel section={features} current={sectionId}>
                <FeaturesCard
                  features={segment.features}
                  onChange={(feature, enabled) =>
                    edit(setFeature(state.draft, segmentId, feature, enabled))
                  }
                />
              </SectionPanel>
            ) : null}
            {resilience ? (
              <SectionPanel section={resilience} current={sectionId}>
                <ResilienceCard
                  resilience={resilienceOf(state.draft)}
                  onChange={(patch) => edit(setResilience(state.draft, patch))}
                />
              </SectionPanel>
            ) : null}
          </fieldset>
          {notifications ? (
            <SectionPanel section={notifications} current={sectionId}>
              <PushCard
                segmentId={segmentId}
                segmentLabel={segment.label}
                destinations={state.published.destinations}
                initialHistory={pushHistory}
                dryRun={pushDryRun}
              />
            </SectionPanel>
          ) : null}
        </main>

        {/* In view while editing: it sticks under the top bar and scrolls on
            its own if the window is shorter than the phone. */}
        <div
          hidden={!section.showsPreview}
          className="lg:sticky lg:top-[calc(var(--console-header,8.5rem)+1.25rem)] lg:max-h-[calc(100vh-var(--console-header,8.5rem)-2.5rem)] lg:overflow-y-auto"
        >
          <PhonePreview segment={segment} resilience={resilienceOf(state.draft)} />
        </div>
      </div>
    </div>
  );
}
