import { countChanges } from "@/lib/config/diff";
import type { HomeConfig } from "@/lib/config/types";

/** What the server hands the editor when it opens. */
export interface LoadedConfig {
  config: HomeConfig;
  baseVersion: number | null;
  source: "published" | "example";
  lastPublishedAt: string | null;
}

export type PublishFailure =
  | { kind: "unavailable" }
  | { kind: "unauthorized" }
  | { kind: "invalid" }
  | { kind: "faults-not-allowed" }
  | { kind: "conflict"; storedVersion: number | null };

export type Publication =
  | { status: "idle" }
  | { status: "publishing" }
  | { status: "failed"; failure: PublishFailure };

export interface EditorState {
  /** What is live, as far as this editor knows. */
  published: HomeConfig;
  /** What the editor shows and would publish. */
  draft: HomeConfig;
  baseVersion: number | null;
  source: "published" | "example";
  lastPublishedAt: string | null;
  selectedSegment: string;
  publication: Publication;
}

export type EditorAction =
  | { type: "segment-selected"; segmentId: string }
  | { type: "edited"; draft: HomeConfig }
  | { type: "discarded" }
  | { type: "publish-started" }
  | { type: "publish-succeeded"; version: number; publishedAt: string }
  | { type: "publish-failed"; failure: PublishFailure };

const IDLE: Publication = { status: "idle" };

export function isPublishing(state: EditorState): boolean {
  return state.publication.status === "publishing";
}

/** After a conflict the base version is no longer the live one. */
export function hasConflict(state: EditorState): boolean {
  return (
    state.publication.status === "failed" &&
    state.publication.failure.kind === "conflict"
  );
}

/**
 * Editing dismisses a failure notice, except a conflict: nothing typed into
 * this editor makes its base version current again, only a reload does.
 */
function afterEdit(state: EditorState): Publication {
  return hasConflict(state) ? state.publication : IDLE;
}

export function initialEditorState(loaded: LoadedConfig): EditorState {
  return {
    published: loaded.config,
    draft: loaded.config,
    baseVersion: loaded.baseVersion,
    source: loaded.source,
    lastPublishedAt: loaded.lastPublishedAt,
    selectedSegment: Object.keys(loaded.config.segments)[0] ?? "",
    publication: IDLE,
  };
}

export function editorReducer(state: EditorState, action: EditorAction): EditorState {
  switch (action.type) {
    case "segment-selected":
      return action.segmentId in state.draft.segments
        ? { ...state, selectedSegment: action.segmentId }
        : state;
    // While a publication is in flight the draft is exactly what was sent:
    // an edit now would later be marked as published without having been.
    case "edited":
      return isPublishing(state)
        ? state
        : { ...state, draft: action.draft, publication: afterEdit(state) };
    case "discarded":
      return isPublishing(state)
        ? state
        : { ...state, draft: state.published, publication: afterEdit(state) };
    case "publish-started":
      return { ...state, publication: { status: "publishing" } };
    case "publish-succeeded": {
      const published = { ...state.draft, configVersion: action.version };
      return {
        ...state,
        published,
        draft: published,
        baseVersion: action.version,
        source: "published",
        lastPublishedAt: action.publishedAt,
        publication: IDLE,
      };
    }
    case "publish-failed":
      return {
        ...state,
        publication: { status: "failed", failure: action.failure },
      };
  }
}

export function pendingChanges(state: EditorState): number {
  return countChanges(state.published, state.draft);
}

/**
 * There must be something to publish, nothing in flight, and the base version
 * must still be the live one: after a conflict the editor has to be reloaded.
 */
export function canPublish(state: EditorState): boolean {
  if (isPublishing(state) || hasConflict(state)) return false;
  return pendingChanges(state) > 0 || state.source === "example";
}
