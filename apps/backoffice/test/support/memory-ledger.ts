import type { AccountBalance } from "@/lib/api/transfer";
import type {
  LedgerTransaction,
  MovementRecord,
  Settlement,
  TransferLedger,
} from "@/lib/server/transfers";

/**
 * A ledger in memory with the semantics of a database transaction: a unit of
 * work reads, then writes, and its writes take effect only if nothing it read
 * was changed by another unit in the meantime; otherwise the whole function
 * runs again against the new state. Reading after writing is an error, as it
 * is in the real database.
 */
export class MemoryLedger implements TransferLedger {
  private readonly transfers = new Map<string, Record<string, unknown>>();
  private readonly accounts = new Map<string, AccountBalance>();
  private readonly movements = new Map<string, MovementRecord>();
  private readonly versions = new Map<string, number>();

  /** How many times a unit of work ran, counting the ones that were redone. */
  attempts = 0;
  /** How many settlements were actually applied. */
  commits = 0;

  /**
   * Awaited after a unit of work finished reading and deciding, before its
   * writes are checked and applied. Tests use it to make units overlap.
   */
  beforeCommit: () => Promise<void> = async () => {};

  putAccount(uid: string, account: AccountBalance): void {
    this.accounts.set(`${uid}/${account.id}`, { ...account });
  }

  putTransfer(uid: string, id: string, data: Record<string, unknown>): void {
    this.transfers.set(`${uid}/${id}`, { ...data });
  }

  account(uid: string, id: string): AccountBalance | undefined {
    return this.accounts.get(`${uid}/${id}`);
  }

  transfer(uid: string, id: string): Record<string, unknown> | undefined {
    return this.transfers.get(`${uid}/${id}`);
  }

  movementsOf(uid: string): MovementRecord[] {
    return [...this.movements.entries()]
      .filter(([key]) => key.startsWith(`${uid}/`))
      .map(([, movement]) => movement);
  }

  private version(key: string): number {
    return this.versions.get(key) ?? 0;
  }

  private bump(key: string): void {
    this.versions.set(key, this.version(key) + 1);
  }

  async transact<T>(
    uid: string,
    transferId: string,
    run: (transaction: LedgerTransaction) => Promise<T>,
  ): Promise<T> {
    const transferKey = `transfer:${uid}/${transferId}`;

    for (;;) {
      this.attempts += 1;
      const seen = new Map<string, number>();
      let settlement: Settlement | null = null;

      const note = (key: string) => {
        if (settlement) throw new Error("a transaction must read before it writes");
        seen.set(key, this.version(key));
      };

      const result = await run({
        readTransfer: async () => {
          note(transferKey);
          const stored = this.transfers.get(`${uid}/${transferId}`);
          return stored ? { ...stored } : null;
        },
        readAccount: async (accountId) => {
          note(`account:${uid}/${accountId}`);
          const stored = this.accounts.get(`${uid}/${accountId}`);
          return stored ? { ...stored } : null;
        },
        write: (next) => {
          settlement = next;
        },
      });

      await this.beforeCommit();

      const unchanged = [...seen].every(([key, version]) => this.version(key) === version);
      if (!unchanged) continue;

      if (settlement) this.apply(uid, transferId, settlement);
      return result;
    }
  }

  private apply(uid: string, transferId: string, settlement: Settlement): void {
    this.commits += 1;
    const key = `${uid}/${transferId}`;
    const created = settlement.newRequest
      ? { ...settlement.newRequest.order, createdAt: settlement.newRequest.createdAt }
      : {};
    this.transfers.set(key, {
      ...this.transfers.get(key),
      ...created,
      ...settlement.record,
    });
    this.bump(`transfer:${key}`);

    for (const account of settlement.accounts) {
      this.accounts.set(`${uid}/${account.id}`, { ...account });
      this.bump(`account:${uid}/${account.id}`);
    }
    for (const movement of settlement.movements) {
      this.movements.set(`${uid}/${movement.id}`, movement);
    }
  }
}
