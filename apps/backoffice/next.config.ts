import path from "node:path";
import type { NextConfig } from "next";

// The contract and the design tokens live at the repository root and are
// imported, not copied, so the bundler must be allowed to resolve them.
const repositoryRoot = path.join(__dirname, "..", "..");

const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "same-origin" },
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=()",
  },
];

const nextConfig: NextConfig = {
  poweredByHeader: false,
  turbopack: { root: repositoryRoot },
  outputFileTracingRoot: repositoryRoot,
  async headers() {
    return [
      { source: "/:path*", headers: securityHeaders },
      // The partners' mini apps stand in for a third party's server: their
      // addresses are handed to nobody. Listed last so it replaces the
      // policy above for these routes.
      {
        source: "/partners/:path*",
        headers: [{ key: "Referrer-Policy", value: "no-referrer" }],
      },
    ];
  },
};

export default nextConfig;
