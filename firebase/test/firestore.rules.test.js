// Tests for firestore.rules, run against the Firestore emulator.
//
// Each test names one thing a client may or may not do. They are the
// executable form of the access model described in docs/adr/0011.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const OWNER = 'uid-owner';
const OTHER = 'uid-other';
const OWNER_EMAIL = 'valentina.andrade@example.com';

let environment;

/** A profile exactly as the app writes it at sign-up. */
function profile(overrides = {}) {
  return {
    fullName: 'Valentina Andrade',
    nationalId: '1710034065',
    email: OWNER_EMAIL,
    phone: '0991234567',
    segment: 'family',
    interests: ['saving', 'travel'],
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

function without(data, field) {
  const copy = { ...data };
  delete copy[field];
  return copy;
}

/** Firestore as the signed-in owner of `users/uid-owner`. */
function asOwner() {
  return environment
    .authenticatedContext(OWNER, { email: OWNER_EMAIL })
    .firestore();
}

function asOtherCustomer() {
  return environment
    .authenticatedContext(OTHER, { email: 'otra@example.com' })
    .firestore();
}

function asVisitor() {
  return environment.unauthenticatedContext().firestore();
}

/** Writes with the Admin SDK's privileges, as the server API does. */
async function seed(path, data) {
  await environment.withSecurityRulesDisabled((context) =>
    setDoc(doc(context.firestore(), path), data),
  );
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-banca-digital',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(() => environment.clearFirestore());

after(() => environment.cleanup());

describe('users/{uid}: reading', () => {
  beforeEach(() =>
    seed(`users/${OWNER}`, profile({ createdAt: Timestamp.now() })),
  );

  test('a customer reads their own profile', async () => {
    await assertSucceeds(getDoc(doc(asOwner(), `users/${OWNER}`)));
  });

  test('a customer cannot read another customer\'s profile', async () => {
    await assertFails(getDoc(doc(asOtherCustomer(), `users/${OWNER}`)));
  });

  test('a visitor cannot read any profile', async () => {
    await assertFails(getDoc(doc(asVisitor(), `users/${OWNER}`)));
  });
});

describe('users/{uid}: creating', () => {
  const own = () => doc(asOwner(), `users/${OWNER}`);

  test('a customer creates their own profile', async () => {
    await assertSucceeds(setDoc(own(), profile()));
  });

  test('a profile may have no interests', async () => {
    await assertSucceeds(setDoc(own(), profile({ interests: [] })));
  });

  test('a customer cannot create another customer\'s profile', async () => {
    await assertFails(
      setDoc(doc(asOtherCustomer(), `users/${OWNER}`), profile()),
    );
  });

  test('a visitor cannot create a profile', async () => {
    await assertFails(setDoc(doc(asVisitor(), `users/${OWNER}`), profile()));
  });

  test('a field outside the allow-list is rejected', async () => {
    await assertFails(setDoc(own(), profile({ balance: 1000000 })));
    await assertFails(setDoc(own(), profile({ role: 'admin' })));
  });

  for (const field of [
    'fullName',
    'nationalId',
    'email',
    'phone',
    'segment',
    'interests',
    'createdAt',
  ]) {
    test(`a profile without ${field} is rejected`, async () => {
      await assertFails(setDoc(own(), without(profile(), field)));
    });
  }

  test('the creation time must be the server time', async () => {
    await assertFails(
      setDoc(own(), profile({ createdAt: Timestamp.fromMillis(0) })),
    );
    await assertFails(setDoc(own(), profile({ createdAt: 'yesterday' })));
  });

  test('the email must be the one of the signed-in account', async () => {
    await assertFails(setDoc(own(), profile({ email: 'otra@example.com' })));
  });

  test('the segment must be one the app knows', async () => {
    await assertFails(setDoc(own(), profile({ segment: 'platinum' })));
    await assertFails(setDoc(own(), profile({ segment: 3 })));
  });

  test('interests must come from the known list', async () => {
    await assertFails(setDoc(own(), profile({ interests: ['crypto'] })));
    await assertFails(setDoc(own(), profile({ interests: 'saving' })));
  });

  test('the cédula must be ten digits', async () => {
    await assertFails(setDoc(own(), profile({ nationalId: '171003406' })));
    await assertFails(setDoc(own(), profile({ nationalId: '17100340651' })));
    await assertFails(setDoc(own(), profile({ nationalId: '17100340a5' })));
    await assertFails(setDoc(own(), profile({ nationalId: 1710034065 })));
  });

  test('the phone must be a ten-digit mobile number', async () => {
    await assertFails(setDoc(own(), profile({ phone: '022345678' })));
    await assertFails(setDoc(own(), profile({ phone: '+593991234567' })));
  });

  test('the name has a minimum and a maximum length', async () => {
    await assertFails(setDoc(own(), profile({ fullName: 'Va' })));
    await assertFails(setDoc(own(), profile({ fullName: 'a'.repeat(121) })));
    await assertFails(setDoc(own(), profile({ fullName: 42 })));
  });
});

describe('users/{uid}: updating', () => {
  const own = () => doc(asOwner(), `users/${OWNER}`);

  beforeEach(() => setDoc(own(), profile()));

  test('a customer changes their segment and interests', async () => {
    await assertSucceeds(
      updateDoc(own(), { segment: 'wealth', interests: ['investing'] }),
    );
  });

  test('a customer changes their name and phone', async () => {
    await assertSucceeds(
      updateDoc(own(), { fullName: 'Valentina Paz', phone: '0987654321' }),
    );
  });

  test('the creation time cannot be changed', async () => {
    await assertFails(updateDoc(own(), { createdAt: serverTimestamp() }));
    await assertFails(updateDoc(own(), { createdAt: Timestamp.fromMillis(0) }));
  });

  test('writing the whole profile again is rejected, because it would '
    + 'reset the creation time', async () => {
    await assertFails(setDoc(own(), profile()));
  });

  test('the cédula cannot be changed', async () => {
    await assertFails(updateDoc(own(), { nationalId: '0926687856' }));
  });

  test('the email cannot be changed', async () => {
    await assertFails(updateDoc(own(), { email: 'otra@example.com' }));
  });

  test('an update cannot add a field outside the allow-list', async () => {
    await assertFails(updateDoc(own(), { balance: 1000000 }));
  });

  test('an update must keep the values valid', async () => {
    await assertFails(updateDoc(own(), { segment: 'platinum' }));
    await assertFails(updateDoc(own(), { phone: '123' }));
  });

  test('a customer cannot update another customer\'s profile', async () => {
    await assertFails(
      updateDoc(doc(asOtherCustomer(), `users/${OWNER}`), { segment: 'wealth' }),
    );
  });

  test('a profile cannot be deleted from a client', async () => {
    await assertFails(deleteDoc(own()));
  });
});

describe('users/{uid}/accounts: money data', () => {
  const account = `users/${OWNER}/accounts/savings`;
  const movement = `${account}/movements/m-1`;

  beforeEach(async () => {
    await seed(account, { name: 'Cuenta de ahorros', balanceCents: 357035 });
    await seed(movement, { amountCents: -6480 });
  });

  test('a customer reads their own account and its movements', async () => {
    await assertSucceeds(getDoc(doc(asOwner(), account)));
    await assertSucceeds(getDoc(doc(asOwner(), movement)));
  });

  test('a customer cannot read another customer\'s account', async () => {
    await assertFails(getDoc(doc(asOtherCustomer(), account)));
    await assertFails(getDoc(doc(asOtherCustomer(), movement)));
  });

  test('a customer cannot change their own balance', async () => {
    await assertFails(updateDoc(doc(asOwner(), account), { balanceCents: 1 }));
  });

  test('a customer cannot create an account or a movement', async () => {
    await assertFails(
      setDoc(doc(asOwner(), `users/${OWNER}/accounts/extra`), {
        balanceCents: 99999999,
      }),
    );
    await assertFails(
      setDoc(doc(asOwner(), `${account}/movements/m-2`), { amountCents: 500 }),
    );
  });

  test('a customer cannot delete a movement', async () => {
    await assertFails(deleteDoc(doc(asOwner(), movement)));
  });
});

describe('config: published configuration', () => {
  beforeEach(() => seed('config/home', { schemaVersion: 1 }));

  test('a signed-in customer reads it', async () => {
    await assertSucceeds(getDoc(doc(asOwner(), 'config/home')));
  });

  test('a visitor cannot read it', async () => {
    await assertFails(getDoc(doc(asVisitor(), 'config/home')));
  });

  test('no client can write it', async () => {
    await assertFails(
      setDoc(doc(asOwner(), 'config/home'), { schemaVersion: 2 }),
    );
    await assertFails(deleteDoc(doc(asOwner(), 'config/home')));
  });
});

describe('anything else', () => {
  test('a path no rule mentions is closed, even when signed in', async () => {
    await assertFails(getDoc(doc(asOwner(), 'secrets/keys')));
    await assertFails(setDoc(doc(asOwner(), 'secrets/keys'), { a: 1 }));
  });
});
