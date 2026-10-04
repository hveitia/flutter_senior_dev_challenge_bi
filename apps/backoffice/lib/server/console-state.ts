import example from "../../../../contracts/home-config.example.json";
import type { HomeConfig } from "@/lib/config/types";
import { configVersionOf, validateHomeConfig } from "@/lib/config/validate";

/** What the editor opens with. */
export interface ConsoleState {
  config: HomeConfig;
  /** Version to publish on top of, or null when no document exists. */
  baseVersion: number | null;
  /** Whether `config` is what is live or the contract's example. */
  source: "published" | "example";
  lastPublishedAt: string | null;
}

/**
 * Decides what the editor shows for whatever is stored. A missing or broken
 * document does not block the console: the editor opens on the contract's
 * example, and publishing it repairs the stored document.
 */
export function consoleStateFrom(
  stored: unknown,
  lastPublishedAt: string | null,
): ConsoleState {
  const validation = validateHomeConfig(stored);
  if (validation.ok) {
    return {
      config: validation.config,
      baseVersion: validation.config.configVersion,
      source: "published",
      lastPublishedAt,
    };
  }
  return {
    config: structuredClone(example) as unknown as HomeConfig,
    baseVersion: configVersionOf(stored),
    source: "example",
    lastPublishedAt,
  };
}
