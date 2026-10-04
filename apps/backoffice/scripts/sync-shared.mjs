// Copies the files this app shares with the rest of the repository into
// `shared/`, inside the app folder.
//
// The configuration contract and the design tokens have one source of truth at
// the repository root. The console imports copies of them so that everything a
// build needs sits under the app root: a hosting platform that builds this
// folder as the application expects the standalone output at its top level,
// which the framework only produces when nothing outside the root is imported.
//
// It runs before dev, lint, build, typecheck and test (see package.json), so
// the copies can never be older than their sources. `shared/` is not tracked.
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = path.resolve(appRoot, "..", "..");

/** Source, relative to the repository root, and the name of its copy. */
export const SHARED_FILES = [
  ["contracts/home-config.schema.json", "home-config.schema.json"],
  ["contracts/home-config.example.json", "home-config.example.json"],
  ["packages/design_system/tokens/tokens.json", "tokens.json"],
];

export function syncShared({
  from = repositoryRoot,
  to = path.join(appRoot, "shared"),
} = {}) {
  mkdirSync(to, { recursive: true });
  for (const [source, name] of SHARED_FILES) {
    const origin = path.join(from, source);
    if (!existsSync(origin)) {
      throw new Error(
        `Cannot find ${source} from ${from}. The console is built from a ` +
          "checkout of the whole repository.",
      );
    }
    copyFileSync(origin, path.join(to, name));
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  syncShared();
}
