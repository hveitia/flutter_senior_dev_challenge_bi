import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
// @ts-expect-error The script is plain JavaScript run by Node before a build.
import { SHARED_FILES, syncShared } from "./sync-shared.mjs";

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = path.resolve(appRoot, "..", "..");

describe("the copies of what the console shares with the repository", () => {
  it("are byte for byte the repository's files", () => {
    for (const [source, name] of SHARED_FILES as [string, string][]) {
      const original = readFileSync(path.join(repositoryRoot, source));
      const copy = readFileSync(path.join(appRoot, "shared", name));

      expect(copy.equals(original), `${name} differs from ${source}`).toBe(true);
    }
  });

  it("are written again on every run, replacing an older copy", () => {
    const from = mkdtempSync(path.join(tmpdir(), "shared-from-"));
    const to = mkdtempSync(path.join(tmpdir(), "shared-to-"));
    for (const [source, name] of SHARED_FILES as [string, string][]) {
      mkdirSync(path.dirname(path.join(from, source)), { recursive: true });
      writeFileSync(path.join(from, source), `new ${name}`);
      writeFileSync(path.join(to, name), "old");
    }

    syncShared({ from, to });

    for (const [, name] of SHARED_FILES as [string, string][]) {
      expect(readFileSync(path.join(to, name), "utf8")).toBe(`new ${name}`);
    }
  });

  it("stop the build with the missing file's name when a source is absent", () => {
    const from = mkdtempSync(path.join(tmpdir(), "shared-empty-"));
    const to = mkdtempSync(path.join(tmpdir(), "shared-to-"));

    expect(() => syncShared({ from, to })).toThrow(/home-config\.schema\.json/);
  });
});
