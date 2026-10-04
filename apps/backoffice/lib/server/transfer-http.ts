import "server-only";
import { failure, type ApiAnswer } from "./api-http";
import type { ProcessResult } from "./transfers";

const OK = 200;

/**
 * How the result of settling a transfer is answered. Both transfer routes
 * answer the same way, and a replay answers exactly as the first time did:
 * only the log tells them apart.
 */
export function transferAnswer(result: ProcessResult): ApiAnswer {
  if (result.kind === "not-found") return failure("transfer-not-found");
  if (result.kind === "key-reused") return failure("idempotency-key-reused");

  const { transfer, replayed } = result;
  const settled =
    transfer.status === "completed"
      ? { status: OK, body: { transfer }, outcome: "completed" }
      : {
          ...failure("transfer-rejected", { reason: transfer.reason, transfer }),
          outcome: `rejected:${transfer.reason}`,
        };
  return replayed ? { ...settled, outcome: `replayed:${settled.outcome}` } : settled;
}
