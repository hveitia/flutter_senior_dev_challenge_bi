/**
 * The few calls of the database client that the customer API makes, over
 * documents held in memory by path. Enough to check which documents an
 * adapter reads and what it writes to them; it does not model contention,
 * which `MemoryLedger` does for the code above the adapter.
 */

export interface FakeReference {
  path: string;
  id: string;
}

type Data = Record<string, unknown>;

interface FakeSnapshot {
  exists: boolean;
  id: string;
  data(): Data | undefined;
}

export interface RecordedWrite {
  kind: "set" | "update";
  path: string;
  data: Data;
  merge?: boolean;
}

/** A stored timestamp, as the database client hands it back. */
export function timestamp(date: Date): { toDate(): Date } {
  return { toDate: () => date };
}

export class FakeFirestore {
  readonly documents = new Map<string, Data>();
  readonly writes: RecordedWrite[] = [];
  readonly reads: string[] = [];
  transactions = 0;

  collection(name: string) {
    return collectionAt(name);
  }

  private snapshot(reference: FakeReference): FakeSnapshot {
    const data = this.documents.get(reference.path);
    return { exists: data !== undefined, id: reference.id, data: () => data };
  }

  async runTransaction<T>(run: (transaction: FakeTransaction) => Promise<T>): Promise<T> {
    this.transactions += 1;
    const pending: RecordedWrite[] = [];
    const result = await run({
      get: async (target: FakeReference | FakeQuery) => {
        if (pending.length > 0) throw new Error("read after write in a transaction");
        if ("prefix" in target) {
          this.reads.push(`${target.prefix}*`);
          const docs = [...this.documents.keys()]
            .filter(
              (path) =>
                path.startsWith(target.prefix) &&
                !path.slice(target.prefix.length).includes("/"),
            )
            .map((path) =>
              this.snapshot({ path, id: path.slice(target.prefix.length) }),
            );
          return { docs, empty: docs.length === 0 };
        }
        this.reads.push(target.path);
        return this.snapshot(target);
      },
      set: (reference, data, options) => {
        pending.push({
          kind: "set",
          path: reference.path,
          data,
          ...(options?.merge ? { merge: true } : {}),
        });
      },
      update: (reference, data) => {
        pending.push({ kind: "update", path: reference.path, data });
      },
    } as FakeTransaction);

    // All or nothing: a function that throws leaves no trace.
    for (const write of pending) {
      const merged = write.kind === "update" || write.merge;
      this.documents.set(write.path, {
        ...(merged ? this.documents.get(write.path) : {}),
        ...write.data,
      });
      this.writes.push(write);
    }
    return result;
  }
}

export interface FakeQuery {
  prefix: string;
}

interface FakeTransaction {
  get(target: FakeReference): Promise<FakeSnapshot>;
  get(target: FakeQuery): Promise<{ docs: FakeSnapshot[]; empty: boolean }>;
  set(reference: FakeReference, data: Data, options?: { merge?: boolean }): void;
  update(reference: FakeReference, data: Data): void;
}

function collectionAt(path: string) {
  return {
    prefix: `${path}/`,
    doc(id: string) {
      const documentPath = `${path}/${id}`;
      return {
        path: documentPath,
        id,
        collection: (name: string) => collectionAt(`${documentPath}/${name}`),
      };
    },
  };
}
