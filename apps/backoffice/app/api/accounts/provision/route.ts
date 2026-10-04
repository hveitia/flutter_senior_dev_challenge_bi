import { failure, handleApi } from "@/lib/server/api-http";
import { customerFromRequest } from "@/lib/server/customer-auth";
import { adminAuth, adminDb } from "@/lib/server/firebase";
import { provisionAccounts } from "@/lib/server/provisioning";
import { firestoreAccountsStore } from "@/lib/server/provisioning-store";

const OK = 200;

/**
 * Opens the default accounts of the customer of the token, once. The app
 * calls it after sign-up; a customer who already has accounts gets them back
 * untouched, so calling it again is harmless.
 *
 * It carries no body and reads none: who the accounts are for, and what they
 * hold, is not something a client gets to say.
 */
export async function POST(request: Request): Promise<Response> {
  return handleApi("accounts.provision", async () => {
    const customer = await customerFromRequest(adminAuth(), request);
    if (!customer) return failure("unauthorized");

    const result = await provisionAccounts(
      firestoreAccountsStore(adminDb()),
      customer.uid,
      new Date(),
    );
    if (result.kind === "profile-required") return failure("profile-required");

    return {
      status: OK,
      body: { created: result.created, accounts: result.accounts },
      outcome: result.created ? "created" : "already-provisioned",
    };
  });
}
