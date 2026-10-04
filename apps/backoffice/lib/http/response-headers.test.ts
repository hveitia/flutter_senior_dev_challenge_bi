import { readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { responseHeaderRules } from "./response-headers";

const appRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
);

/** Every TypeScript source of the app, skipping dependencies and build output. */
function sources(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    if (entry === "node_modules" || entry.startsWith(".")) return [];
    const full = path.join(directory, entry);
    if (statSync(full).isDirectory()) return sources(full);
    return /\.(ts|tsx|mts)$/.test(entry) ? [full] : [];
  });
}

describe("the response header rules", () => {
  it("cover every route with the security headers", () => {
    const everything = responseHeaderRules().find(
      (rule) => rule.source === "/:path*",
    );

    expect(everything?.headers).toContainEqual({
      key: "X-Content-Type-Options",
      value: "nosniff",
    });
    expect(everything?.headers).toContainEqual({
      key: "X-Frame-Options",
      value: "DENY",
    });
  });

  it("are never read through the framework's config file", () => {
    // A hosting platform wraps next.config at build time, and the type check
    // of that build fails on any module that imports it.
    const importers = sources(appRoot).filter((file) =>
      /from\s+["'][^"']*next\.config["']/.test(readFileSync(file, "utf8")),
    );

    expect(importers).toEqual([]);
  });
});
