import { useSyncExternalStore } from "react";

/**
 * A stand-in for the framework's `useSearchParams` in component tests: it
 * reads the real address of the test window and follows `pushState`,
 * `replaceState` and the back button, which is the part of the framework's
 * behavior the console depends on.
 */

const CHANGED = "test:address-changed";
let patched = false;

function followHistoryCalls() {
  if (patched) return;
  patched = true;
  for (const method of ["pushState", "replaceState"] as const) {
    const original = window.history[method].bind(window.history);
    window.history[method] = (...args: Parameters<History["pushState"]>) => {
      original(...args);
      window.dispatchEvent(new Event(CHANGED));
    };
  }
}

function subscribe(onChange: () => void) {
  window.addEventListener(CHANGED, onChange);
  window.addEventListener("popstate", onChange);
  return () => {
    window.removeEventListener(CHANGED, onChange);
    window.removeEventListener("popstate", onChange);
  };
}

export function useLocationSearch(): URLSearchParams {
  followHistoryCalls();
  const search = useSyncExternalStore(
    subscribe,
    () => window.location.search,
    () => "",
  );
  return new URLSearchParams(search);
}

/** Puts the test window at an address before a component is rendered. */
export function openAddress(search: string) {
  followHistoryCalls();
  window.history.replaceState(null, "", `/${search}`);
}
