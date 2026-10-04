import "server-only";
import type { Firestore } from "firebase-admin/firestore";
import type { AccountsStore } from "./provisioning";
import {
  ACCOUNTS_SUBCOLLECTION,
  MOVEMENTS_SUBCOLLECTION,
  USERS_COLLECTION,
} from "./transfer-store";

/**
 * A customer's profile and accounts on the database. The profile is the
 * document `users/{uid}` the app writes at sign-up; the accounts are read as
 * a whole collection inside the transaction, so two calls at once cannot
 * both find it empty.
 */
export function firestoreAccountsStore(db: Firestore): AccountsStore {
  return {
    transact(uid, run) {
      const customer = db.collection(USERS_COLLECTION).doc(uid);
      const accounts = customer.collection(ACCOUNTS_SUBCOLLECTION);
      const movements = customer.collection(MOVEMENTS_SUBCOLLECTION);

      return db.runTransaction((transaction) =>
        run({
          async hasProfile() {
            return (await transaction.get(customer)).exists;
          },
          async accounts() {
            const snapshot = await transaction.get(accounts);
            return snapshot.docs.map((document) => ({
              id: document.id,
              data: document.data(),
            }));
          },
          create(plan, now) {
            for (const { id, ...account } of plan.accounts) {
              transaction.set(accounts.doc(id), { ...account, updatedAt: now });
            }
            for (const { id, ...movement } of plan.movements) {
              transaction.set(movements.doc(id), movement);
            }
          },
        }),
      );
    },
  };
}
