import { jsonResponse, newReference, readJsonBody } from "@/lib/partners/http";
import { parseTopUpRequest, topUp } from "@/lib/partners/recharge";

/** Prefix of the references this partner gives its top-ups. */
const REFERENCE_PREFIX = "RC";

/**
 * Registers a simulated top-up: the request is validated and answered with
 * a reference. No operator is called and no money moves.
 */
export async function POST(request: Request): Promise<Response> {
  const read = await readJsonBody(request);
  if (!read.ok) return jsonResponse(read.status, { error: read.error });

  const parsed = parseTopUpRequest(read.body);
  if (!parsed.ok) {
    return jsonResponse(422, { error: "invalid", problems: parsed.problems });
  }

  return jsonResponse(200, {
    topUp: topUp(parsed.request),
    reference: newReference(REFERENCE_PREFIX),
  });
}
