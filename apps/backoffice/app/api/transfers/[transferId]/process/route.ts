import { isTransferId } from "@/lib/api/transfer-request";
import { failure, handleApi } from "@/lib/server/api-http";
import { customerFromRequest } from "@/lib/server/customer-auth";
import { adminAuth, adminDb } from "@/lib/server/firebase";
import { transferAnswer } from "@/lib/server/transfer-http";
import { firestoreTransferLedger } from "@/lib/server/transfer-store";
import { processTransfer } from "@/lib/server/transfers";

/**
 * Settles a transfer the app left pending, typically one queued while the
 * phone was offline. The order is the one in the pending document under the
 * customer of the token; the request carries no body and none is read.
 *
 * Safe to call any number of times, from the phone and from a retry at once:
 * the first call settles it and every other one gets that outcome.
 */
export async function POST(
  request: Request,
  { params }: { params: Promise<{ transferId: string }> },
): Promise<Response> {
  return handleApi("transfers.process", async () => {
    const customer = await customerFromRequest(adminAuth(), request);
    if (!customer) return failure("unauthorized");

    const { transferId } = await params;
    if (!isTransferId(transferId)) {
      return failure("invalid-request", { fields: ["transferId"] });
    }

    return transferAnswer(
      await processTransfer(
        firestoreTransferLedger(adminDb()),
        customer.uid,
        transferId,
        new Date(),
      ),
    );
  });
}
