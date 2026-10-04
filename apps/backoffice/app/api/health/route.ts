import packageInfo from "@/package.json";
import { healthReport } from "@/lib/server/health";

const SERVICE_UNAVAILABLE = 503;

// Read on every request: the answer depends on the environment of the
// running server, not on what was true when it was built.
export const dynamic = "force-dynamic";

/** Uptime check. Public on purpose; see `healthReport` for what it tells. */
export function GET(): Response {
  const report = healthReport(process.env, packageInfo.version);
  return Response.json(report, {
    status: report.status === "ok" ? 200 : SERVICE_UNAVAILABLE,
    headers: { "cache-control": "no-store" },
  });
}
