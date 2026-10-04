import { isVisible, promoOf } from "./editing";
import type { HomeConfig, SegmentConfig } from "./types";
import { resilienceOf } from "./types";

function differing<T extends object>(before: T, after: T): number {
  const keys = Object.keys(after) as (keyof T)[];
  return keys.filter((key) => before[key] !== after[key]).length;
}

function sameOrder(before: SegmentConfig, after: SegmentConfig): boolean {
  return (
    before.modules.length === after.modules.length &&
    before.modules.every((module, index) => module.id === after.modules[index]?.id)
  );
}

/** What a segment's home composition changes: order, visibility and banner. */
function homeChanges(before: SegmentConfig, after: SegmentConfig): number {
  let changes = sameOrder(before, after) ? 0 : 1;

  for (const drafted of after.modules) {
    const published = before.modules.find((other) => other.id === drafted.id);
    if (published && isVisible(published) !== isVisible(drafted)) changes += 1;
  }

  const publishedPromo = promoOf(before);
  const draftPromo = promoOf(after);
  if (publishedPromo && draftPromo) {
    changes += differing(publishedPromo, draftPromo);
  }

  return changes;
}

/** Unpublished changes, filed under the part of the console that edits them. */
export interface SectionChanges {
  home: number;
  features: number;
  resilience: number;
}

/**
 * How many settings the draft changes with respect to what is published, in
 * the terms an editor thinks in: a reordering counts once per segment, and
 * each switch or field counts once. The version number is not an edit.
 */
export function changesBySection(
  published: HomeConfig,
  draft: HomeConfig,
): SectionChanges {
  const changes: SectionChanges = {
    home: 0,
    features: 0,
    resilience: differing(resilienceOf(published), resilienceOf(draft)),
  };
  for (const [segmentId, segment] of Object.entries(draft.segments)) {
    const before = published.segments[segmentId];
    if (!before) continue;
    changes.home += homeChanges(before, segment);
    changes.features += differing(before.features, segment.features);
  }
  return changes;
}

/** Every unpublished change, wherever in the console it was made. */
export function countChanges(published: HomeConfig, draft: HomeConfig): number {
  const { home, features, resilience } = changesBySection(published, draft);
  return home + features + resilience;
}
