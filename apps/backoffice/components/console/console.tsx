"use client";

import { useRouter } from "next/navigation";
import { useReducer } from "react";
import type { PublishOutcome } from "@/app/actions";
import {
  moveModule,
  promoOf,
  setFeature,
  setModuleVisible,
  setPromo,
  setResilience,
} from "@/lib/config/editing";
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
import type { PushRecord } from "@/lib/server/push";
import { AlertIcon, Button } from "../ui";
import { ModulesCard } from "./modules-card";
import { PhonePreview } from "./phone-preview";
import { PublishFailureBanner } from "./publish-failure-banner";
import { PushCard } from "./push-card";
import { SegmentList } from "./segment-list";
import { FeaturesCard, PromoCard, ResilienceCard } from "./settings-cards";
import { TopBar } from "./top-bar";

const LOGIN_PATH = "/login";

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

/** The editor: one draft, edited by the cards and published as a whole. */
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
  const [state, dispatch] = useReducer(editorReducer, loaded, initialEditorState);
  const segmentId = state.selectedSegment;
  const segment = state.draft.segments[segmentId];
  const edit = (draft: HomeConfig) => dispatch({ type: "edited", draft });

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

  if (!segment) {
    return <p className="p-6 text-body">La configuración no tiene segmentos.</p>;
  }

  return (
    <div className="min-h-screen">
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
      <div className="mx-auto grid max-w-[1440px] grid-cols-[280px_minmax(0,1fr)_360px] items-start gap-5 p-5">
        <SegmentList
          segments={state.draft.segments}
          selected={segmentId}
          customers={customers}
          onSelect={(id) => dispatch({ type: "segment-selected", segmentId: id })}
        />

        <main className="grid gap-5">
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
          <ModulesCard
            modules={segment.modules}
            onMove={(from, to) => edit(moveModule(state.draft, segmentId, from, to))}
            onVisibilityChange={(moduleId, visible) =>
              edit(setModuleVisible(state.draft, segmentId, moduleId, visible))
            }
          />
          <PromoCard
            promo={promoOf(segment)}
            destinations={state.draft.destinations}
            onChange={(patch) => edit(setPromo(state.draft, segmentId, patch))}
          />
          <FeaturesCard
            features={segment.features}
            onChange={(feature, enabled) =>
              edit(setFeature(state.draft, segmentId, feature, enabled))
            }
          />
          {isDemo ? (
            <ResilienceCard
              resilience={resilienceOf(state.draft)}
              onChange={(patch) => edit(setResilience(state.draft, patch))}
            />
          ) : hasFaults(resilienceOf(state.draft)) ? (
            // The lab is hidden here, but faults published from a
            // demonstration would otherwise stay live with no way out.
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
          </fieldset>
          <PushCard
            segmentId={segmentId}
            segmentLabel={segment.label}
            destinations={state.published.destinations}
            initialHistory={pushHistory}
            dryRun={pushDryRun}
          />
        </main>

        <PhonePreview segment={segment} resilience={resilienceOf(state.draft)} />
      </div>
    </div>
  );
}
