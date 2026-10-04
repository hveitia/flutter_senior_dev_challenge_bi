import { describe, expect, it } from "vitest";
import { setModuleVisible } from "@/lib/config/editing";
import { exampleConfig } from "@/test/support/fixtures";
import {
  canPublish,
  editorReducer,
  initialEditorState,
  pendingChanges,
  type EditorState,
} from "./editor-state";

function loaded(): EditorState {
  return initialEditorState({
    config: { ...exampleConfig(), configVersion: 14 },
    baseVersion: 14,
    source: "published",
    lastPublishedAt: "2026-10-03T13:40:00.000Z",
  });
}

function edited(state: EditorState): EditorState {
  return editorReducer(state, {
    type: "edited",
    draft: setModuleVisible(state.draft, "starting", "promo", false),
  });
}

describe("editor state", () => {
  it("opens on the first segment with nothing to publish", () => {
    const state = loaded();

    expect(state.selectedSegment).toBe("starting");
    expect(pendingChanges(state)).toBe(0);
    expect(canPublish(state)).toBe(false);
  });

  it("can publish once the draft differs from what is live", () => {
    const state = edited(loaded());

    expect(pendingChanges(state)).toBe(1);
    expect(canPublish(state)).toBe(true);
  });

  it("goes back to what is live when the edits are discarded", () => {
    const state = editorReducer(edited(loaded()), { type: "discarded" });

    expect(pendingChanges(state)).toBe(0);
    expect(state.draft).toBe(state.published);
  });

  it("keeps the edits of other segments when the selection changes", () => {
    const state = editorReducer(edited(loaded()), {
      type: "segment-selected",
      segmentId: "wealth",
    });

    expect(state.selectedSegment).toBe("wealth");
    expect(pendingChanges(state)).toBe(1);
  });

  it("ignores the selection of a segment that does not exist", () => {
    const state = editorReducer(loaded(), {
      type: "segment-selected",
      segmentId: "vip",
    });

    expect(state.selectedSegment).toBe("starting");
  });

  it("cannot publish twice while a publication is in flight", () => {
    const state = editorReducer(edited(loaded()), { type: "publish-started" });

    expect(state.publication.status).toBe("publishing");
    expect(canPublish(state)).toBe(false);
  });

  it("takes the draft as live, with the new version, after a publication", () => {
    const publishing = editorReducer(edited(loaded()), { type: "publish-started" });

    const state = editorReducer(publishing, {
      type: "publish-succeeded",
      version: 15,
      publishedAt: "2026-10-03T14:00:00.000Z",
    });

    expect(state.baseVersion).toBe(15);
    expect(state.published.configVersion).toBe(15);
    expect(state.lastPublishedAt).toBe("2026-10-03T14:00:00.000Z");
    expect(state.source).toBe("published");
    expect(pendingChanges(state)).toBe(0);
    expect(state.publication.status).toBe("idle");
  });

  it("keeps the edits and the live version when a publication fails", () => {
    const publishing = editorReducer(edited(loaded()), { type: "publish-started" });

    const state = editorReducer(publishing, {
      type: "publish-failed",
      failure: { kind: "unavailable" },
    });

    expect(state.publication).toEqual({
      status: "failed",
      failure: { kind: "unavailable" },
    });
    expect(state.baseVersion).toBe(14);
    expect(pendingChanges(state)).toBe(1);
    expect(canPublish(state)).toBe(true);
  });

  it("clears a failure notice as soon as the draft is edited again", () => {
    let state = editorReducer(edited(loaded()), { type: "publish-started" });
    state = editorReducer(state, {
      type: "publish-failed",
      failure: { kind: "unavailable" },
    });

    state = edited(state);

    expect(state.publication.status).toBe("idle");
  });

  it("cannot retry after a version conflict: the base is no longer live", () => {
    let state = editorReducer(edited(loaded()), { type: "publish-started" });
    state = editorReducer(state, {
      type: "publish-failed",
      failure: { kind: "conflict", storedVersion: 16 },
    });

    expect(canPublish(state)).toBe(false);
  });

  it("stays locked after a conflict even if the draft is edited or discarded", () => {
    let state = editorReducer(edited(loaded()), { type: "publish-started" });
    const conflict = { kind: "conflict", storedVersion: 16 } as const;
    state = editorReducer(state, { type: "publish-failed", failure: conflict });

    const afterEdit = editorReducer(state, {
      type: "edited",
      draft: setModuleVisible(state.draft, "starting", "services", false),
    });
    const afterDiscard = editorReducer(state, { type: "discarded" });

    expect(afterEdit.publication).toEqual({ status: "failed", failure: conflict });
    expect(canPublish(afterEdit)).toBe(false);
    expect(afterDiscard.publication).toEqual({ status: "failed", failure: conflict });
    expect(canPublish(afterDiscard)).toBe(false);
  });

  it("ignores edits and discards while a publication is in flight", () => {
    const publishing = editorReducer(edited(loaded()), { type: "publish-started" });

    const afterEdit = editorReducer(publishing, {
      type: "edited",
      draft: setModuleVisible(publishing.draft, "starting", "services", false),
    });
    const afterDiscard = editorReducer(publishing, { type: "discarded" });

    expect(afterEdit).toBe(publishing);
    expect(afterDiscard).toBe(publishing);
    expect(canPublish(afterEdit)).toBe(false);
  });

  it("takes as live exactly the draft that was sent", () => {
    let state = editorReducer(edited(loaded()), { type: "publish-started" });
    const sent = state.draft;
    state = editorReducer(state, {
      type: "edited",
      draft: setModuleVisible(state.draft, "starting", "services", false),
    });

    state = editorReducer(state, {
      type: "publish-succeeded",
      version: 15,
      publishedAt: "2026-10-03T14:00:00.000Z",
    });

    expect(state.published).toEqual({ ...sent, configVersion: 15 });
    expect(pendingChanges(state)).toBe(0);
  });

  it("can publish the contract example when nothing is live yet", () => {
    const state = initialEditorState({
      config: exampleConfig(),
      baseVersion: null,
      source: "example",
      lastPublishedAt: null,
    });

    expect(pendingChanges(state)).toBe(0);
    expect(canPublish(state)).toBe(true);
  });
});
