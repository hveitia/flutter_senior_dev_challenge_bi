import { htmlResponse, newNonce } from "@/lib/partners/http";
import { rechargePage } from "@/lib/partners/recharge-page";

// Every answer carries its own nonce, so the page is never prerendered.
export const dynamic = "force-dynamic";

/**
 * The mobile top-up mini app of "Aliado Recargas": a simulated partner,
 * hosted next to the console for the demonstration and sharing nothing with
 * it. It is public and sets no cookie.
 */
export function GET(): Response {
  const nonce = newNonce();
  return htmlResponse(rechargePage(nonce), nonce);
}
