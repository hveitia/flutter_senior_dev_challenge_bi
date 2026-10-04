import { htmlResponse, newNonce } from "@/lib/partners/http";
import { travelInsurancePage } from "@/lib/partners/travel-insurance-page";

// Every answer carries its own nonce, so the page is never prerendered.
export const dynamic = "force-dynamic";

/**
 * The travel insurance mini app of "Aliado Seguros": a simulated partner,
 * hosted next to the console for the demonstration and sharing nothing with
 * it. It is public and sets no cookie.
 */
export function GET(): Response {
  const nonce = newNonce();
  return htmlResponse(travelInsurancePage(nonce), nonce);
}
