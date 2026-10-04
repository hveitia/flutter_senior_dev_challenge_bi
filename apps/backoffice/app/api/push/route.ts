import { NextResponse } from "next/server";
import { loadConsoleState } from "@/lib/server/config-store";
import { currentAdmin } from "@/lib/server/current-admin";
import {
  adminAuth,
  adminDb,
  adminMessaging,
  serverSettings,
} from "@/lib/server/firebase";
import { retryPush, sendPush, validatePushDraft } from "@/lib/server/push";
import { firebasePushPorts } from "@/lib/server/push-store";
import { isSameOrigin } from "@/lib/server/same-origin";

/** Shown in the history for a send addressed to one person. */
const ONE_CUSTOMER_LABEL = "Un cliente";

function answer(status: number, body: object): NextResponse {
  return NextResponse.json(body, { status });
}

async function readBody(request: Request): Promise<Record<string, unknown>> {
  try {
    const body: unknown = await request.json();
    return typeof body === "object" && body !== null
      ? (body as Record<string, unknown>)
      : {};
  } catch {
    return {};
  }
}

/**
 * Sends a notification, or retries a failed one when the body carries
 * `retryOf`. A send the messaging service rejects is still a 200: the answer
 * is the history row, with its failed status.
 */
export async function POST(request: Request): Promise<NextResponse> {
  if (!isSameOrigin(request)) return answer(403, { error: "refused" });

  const admin = await currentAdmin();
  if (!admin) return answer(401, { error: "unauthorized" });

  const body = await readBody(request);
  try {
    const db = adminDb();
    const ports = firebasePushPorts(db, adminAuth(), adminMessaging());
    const settings = serverSettings();

    if (typeof body.retryOf === "string") {
      const record = await retryPush(ports, settings, body.retryOf, new Date());
      return record
        ? answer(200, { record })
        : answer(409, { error: "nothing-to-retry" });
    }

    // Destinations and segments are whatever is live, not what the browser
    // claims they are.
    const { config } = await loadConsoleState(db);
    const validation = validatePushDraft(
      body,
      config.destinations,
      Object.keys(config.segments),
    );
    if (!validation.ok) {
      return answer(400, { error: "invalid", fields: validation.fields });
    }

    const { audience } = validation.draft;
    const audienceLabel =
      audience.kind === "segment"
        ? (config.segments[audience.segmentId]?.label ?? audience.segmentId)
        : ONE_CUSTOMER_LABEL;

    const record = await sendPush(
      ports,
      settings,
      admin,
      new Date(),
      validation.draft,
      audienceLabel,
    );
    return answer(200, { record });
  } catch {
    return answer(503, { error: "unavailable" });
  }
}
