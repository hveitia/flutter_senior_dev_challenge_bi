import { jsonResponse, newReference, readJsonBody } from "@/lib/partners/http";
import {
  parseQuoteRequest,
  quote,
  utcDay,
} from "@/lib/partners/travel-insurance";

/** Prefix of the references this partner gives its quotes. */
const REFERENCE_PREFIX = "SV";

/**
 * Prices a trip. The request is validated here whatever the page checked,
 * and the price comes from the partner's own rates, never from the request.
 */
export async function POST(request: Request): Promise<Response> {
  const read = await readJsonBody(request);
  if (!read.ok) return jsonResponse(read.status, { error: read.error });

  const parsed = parseQuoteRequest(read.body, utcDay(new Date()));
  if (!parsed.ok) {
    return jsonResponse(422, { error: "invalid", problems: parsed.problems });
  }

  return jsonResponse(200, {
    quote: quote(parsed.request),
    reference: newReference(REFERENCE_PREFIX),
  });
}
