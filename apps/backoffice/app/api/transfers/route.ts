import { parseTransferBody } from "@/lib/api/transfer-request";
import { failure, handleApi, readJsonObject } from "@/lib/server/api-http";
import { customerFromRequest } from "@/lib/server/customer-auth";
import { adminAuth, adminDb } from "@/lib/server/firebase";
import { transferAnswer } from "@/lib/server/transfer-http";
import { firestoreTransferLedger } from "@/lib/server/transfer-store";
import { processTransfer } from "@/lib/server/transfers";

/**
 * A transfer between the customer's own accounts, sent while online: the
 * request is created and settled in one transaction. `transferId` is chosen
 * by the app and is the idempotency key, so sending the same order again
 * (a timeout, a retry) returns the first outcome and moves nothing.
 *
 * The customer is the one the bearer token names. Nothing in the body can
 * say otherwise: a field the route does not know is an error.
 */
export async function POST(request: Request): Promise<Response> {
  return handleApi("transfers.create", async () => {
    const customer = await customerFromRequest(adminAuth(), request);
    if (!customer) return failure("unauthorized");

    const json = await readJsonObject(request);
    if (!json.ok) return failure(json.error);

    const parsed = parseTransferBody(json.body);
    if (!parsed.ok) return failure("invalid-request", { fields: parsed.fields });

    return transferAnswer(
      await processTransfer(
        firestoreTransferLedger(adminDb()),
        customer.uid,
        parsed.transferId,
        new Date(),
        parsed.order,
      ),
    );
  });
}
