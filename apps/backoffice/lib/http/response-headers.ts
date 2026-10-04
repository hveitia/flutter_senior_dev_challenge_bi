/** One response header rule, in the shape the framework's `headers()` returns. */
export interface ResponseHeaderRule {
  readonly source: string;
  readonly headers: ReadonlyArray<{ readonly key: string; readonly value: string }>;
}

const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "same-origin" },
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=()",
  },
];

/**
 * The header rules of every response, in the order the framework applies them.
 *
 * They live here, and not in the framework's config file, so tests can read
 * them: a hosting platform may wrap that file at build time, and nothing else
 * should import it.
 */
export function responseHeaderRules(): ResponseHeaderRule[] {
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
}
