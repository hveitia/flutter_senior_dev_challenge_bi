import example from "@/shared/home-config.example.json";
import type { HomeConfig } from "@/lib/config/types";

/** A fresh copy of the contract example, safe to mutate in a test. */
export function exampleConfig(): HomeConfig {
  return structuredClone(example) as unknown as HomeConfig;
}
