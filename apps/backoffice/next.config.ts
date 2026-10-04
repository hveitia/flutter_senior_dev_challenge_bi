import type { NextConfig } from "next";

import { responseHeaderRules } from "./lib/http/response-headers";

const nextConfig: NextConfig = {
  poweredByHeader: false,
  // The app root is this folder, stated so the framework does not infer one
  // from another lockfile in the repository. What the console shares with the
  // rest of the repository is copied into `shared/` before every build (see
  // scripts/sync-shared.mjs), so nothing outside this folder is imported and
  // the standalone output sits at its top level, where the hosting platform
  // expects it.
  turbopack: { root: __dirname },
  outputFileTracingRoot: __dirname,
  async headers() {
    return responseHeaderRules().map((rule) => ({
      source: rule.source,
      headers: [...rule.headers],
    }));
  },
};

export default nextConfig;
