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
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
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

  test('an account whose token carries no email cannot create a profile',
    async () => {
      const withoutEmail = environment.authenticatedContext(OWNER).firestore();

      await assertFails(setDoc(doc(withoutEmail, `users/${OWNER}`), profile()));
    });
  test('an interest cannot be repeated', async () => {
    await assertFails(
      setDoc(own(), profile({ interests: ['saving', 'saving'] })),
    );
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

  test('an update cannot exceed the number of known interests', async () => {
    await assertFails(
      updateDoc(own(), {
        interests: ['saving', 'investing', 'travel', 'billPayments', 'credit',
          'insurance', 'business', 'saving'],
      }),
    );
  });

  test('an update cannot repeat an interest', async () => {
    await assertFails(updateDoc(own(), { interests: ['saving', 'saving'] }));
  });

  test('a profile cannot be deleted from a client', async () => {
    await assertFails(deleteDoc(own()));
  });
});

describe('users: the collection', () => {
  beforeEach(async () => {
    await seed(`users/${OWNER}`, { fullName: 'Valentina Andrade' });
    await seed(`users/${OTHER}`, { fullName: 'Otra Persona' });
  });

  test('a signed-in customer cannot list the profiles', async () => {
    await assertFails(getDocs(collection(asOwner(), 'users')));
  });

  test('a visitor cannot list the profiles', async () => {
    await assertFails(getDocs(collection(asVisitor(), 'users')));
  });
});

describe('users/{uid}/…: anything under the customer', () => {
  test('a customer cannot write a document in a subcollection of their '
    + 'own invention', async () => {
    await assertFails(
      setDoc(doc(asOwner(), `users/${OWNER}/notes/n-1`), { text: 'x' }),
    );
    await assertFails(
      setDoc(doc(asOwner(), `users/${OWNER}/pushTokens/t-1`), { token: 'x' }),
    );
  });
});

describe('users/{uid}/accounts and movements: money data', () => {
  const accounts = `users/${OWNER}/accounts`;
  const movements = `users/${OWNER}/movements`;
  const account = `${accounts}/savings`;
  const movement = `${movements}/m-1`;

  /** The page of movements the app follows for one account. */
  function movementsOf(firestore, owner) {
    return query(
      collection(firestore, `users/${owner}/movements`),
      where('accountId', '==', 'savings'),
      orderBy('postedAt', 'desc'),
      limit(20),
    );
  }

  beforeEach(async () => {
    await seed(account, {
      name: 'Cuenta de ahorros',
      kind: 'savings',
      number: '22004821',
      availableCents: 357035,
      ledgerCents: 357035,
      currency: 'USD',
      updatedAt: Timestamp.now(),
    });
    await seed(movement, {
      accountId: 'savings',
      description: 'Supermercado',
      category: 'groceries',
      amountCents: -6480,
      postedAt: Timestamp.now(),
      reference: 'MOV-202610-0002',
      channel: 'debit_card',
      status: 'completed',
    });
  });

  test('a customer reads their own account and movement', async () => {
    await assertSucceeds(getDoc(doc(asOwner(), account)));
    await assertSucceeds(getDoc(doc(asOwner(), movement)));
  });

  test('a customer lists their accounts, as the accounts screen does',
    async () => {
      await assertSucceeds(getDocs(collection(asOwner(), accounts)));
    });

  test('a customer queries the movements of one account, newest first, as '
    + 'the account screen does', async () => {
    await assertSucceeds(getDocs(movementsOf(asOwner(), OWNER)));
  });

  test('a customer cannot read another customer\'s account or movement',
    async () => {
      await assertFails(getDoc(doc(asOtherCustomer(), account)));
      await assertFails(getDoc(doc(asOtherCustomer(), movement)));
    });

  test('a customer cannot list or query another customer\'s money data',
    async () => {
      await assertFails(getDocs(collection(asOtherCustomer(), accounts)));
      await assertFails(getDocs(movementsOf(asOtherCustomer(), OWNER)));
    });

  test('a visitor reads no money data', async () => {
    await assertFails(getDoc(doc(asVisitor(), account)));
    await assertFails(getDocs(movementsOf(asVisitor(), OWNER)));
  });

  test('a customer cannot change their own balance', async () => {
    await assertFails(
      updateDoc(doc(asOwner(), account), { availableCents: 99999999 }),
    );
  });

  test('a customer cannot create an account', async () => {
    await assertFails(
      setDoc(doc(asOwner(), `${accounts}/extra`), {
        availableCents: 99999999,
      }),
    );
  });

  test('a customer cannot create or change a movement', async () => {
    await assertFails(
      setDoc(doc(asOwner(), `${movements}/m-2`), {
        accountId: 'savings',
        amountCents: 500000,
        postedAt: Timestamp.now(),
      }),
    );
    await assertFails(
      updateDoc(doc(asOwner(), movement), { amountCents: 6480 }),
    );
  });

  test('a customer cannot delete an account or a movement', async () => {
    await assertFails(deleteDoc(doc(asOwner(), account)));
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

  test('a visitor cannot write it either', async () => {
    await assertFails(
      setDoc(doc(asVisitor(), 'config/home'), { schemaVersion: 2 }),
    );
    await assertFails(
      setDoc(doc(asVisitor(), 'config/other'), { schemaVersion: 2 }),
    );
    await assertFails(deleteDoc(doc(asVisitor(), 'config/home')));
  });
});

describe('users/{uid}/transfers: transfer orders left by the app', () => {
  const TRANSFER_ID = '4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f';
  const path = `users/${OWNER}/transfers/${TRANSFER_ID}`;

  /** A transfer order exactly as the app leaves it. */
  function order(overrides = {}) {
    return {
      fromAccountId: 'savings',
      toAccountId: 'checking',
      amountCents: 15010,
      concept: 'Arriendo',
      status: 'pending',
      createdAt: serverTimestamp(),
      ...overrides,
    };
  }

  test('a customer leaves a pending order under an id of their choosing',
    async () => {
      await assertSucceeds(setDoc(doc(asOwner(), path), order()));
    });

  test('a customer reads their own order, to follow its outcome', async () => {
    await seed(path, order({ createdAt: Timestamp.now() }));
    await assertSucceeds(getDoc(doc(asOwner(), path)));
  });

  test('the largest amount, the longest concept and an empty concept are '
    + 'accepted', async () => {
    await assertSucceeds(setDoc(doc(asOwner(), path),
      order({ amountCents: 500000, concept: 'a'.repeat(80) })));
    await assertSucceeds(setDoc(
      doc(asOwner(), `users/${OWNER}/transfers/another-order-id-0001`),
      order({ concept: '' })));
  });

  test('a customer cannot leave an order for another customer', async () => {
    await assertFails(setDoc(doc(asOtherCustomer(), path), order()));
  });

  test('a visitor cannot leave an order', async () => {
    await assertFails(setDoc(doc(asVisitor(), path), order()));
  });

  test('a customer cannot read another customer\'s order', async () => {
    await seed(path, order({ createdAt: Timestamp.now() }));
    await assertFails(getDoc(doc(asOtherCustomer(), path)));
  });

  const refused = {
    'already completed': { status: 'completed' },
    'already rejected': { status: 'rejected' },
    'for zero': { amountCents: 0 },
    'for a negative amount': { amountCents: -100 },
    'for a fraction of a cent': { amountCents: 150.1 },
    'with the amount as text': { amountCents: '15010' },
    'one cent over the limit': { amountCents: 500001 },
    'from an account to itself': { toAccountId: 'savings' },
    'with an account id that is a path': { fromAccountId: 'a/b' },
    'with an empty account id': { toAccountId: '' },
    'with an account id that is not text': { fromAccountId: 7 },
    'with a concept one character too long': { concept: 'a'.repeat(81) },
    'with a concept that is not text': { concept: 42 },
    'dated by the device instead of the server':
      { createdAt: Timestamp.fromMillis(1_700_000_000_000) },
    'that already carries a reference': { reference: 'TRF-202610-ABCDEF0123' },
    'that already carries a settlement time': { processedAt: serverTimestamp() },
    'that names a customer': { uid: OTHER },
  };

  for (const [name, change] of Object.entries(refused)) {
    test(`a customer cannot leave an order ${name}`, async () => {
      await assertFails(setDoc(doc(asOwner(), path), order(change)));
    });
  }

  for (const field of ['fromAccountId', 'toAccountId', 'amountCents',
    'concept', 'status', 'createdAt']) {
    test(`a customer cannot leave an order without ${field}`, async () => {
      await assertFails(setDoc(doc(asOwner(), path), without(order(), field)));
    });
  }

  test('an order id must be long enough to be unique', async () => {
    await assertFails(
      setDoc(doc(asOwner(), `users/${OWNER}/transfers/short`), order()),
    );
  });

  test('a customer cannot change an order once it is left', async () => {
    await seed(path, order({ createdAt: Timestamp.now() }));
    await assertFails(updateDoc(doc(asOwner(), path), { amountCents: 1 }));
    await assertFails(updateDoc(doc(asOwner(), path), { status: 'completed' }));
  });

  test('a customer cannot replace an order by leaving it again', async () => {
    await seed(path, order({ createdAt: Timestamp.now() }));
    await assertFails(
      setDoc(doc(asOwner(), path), order({ amountCents: 20000 })),
    );
  });

  test('a customer cannot reopen an order the server settled', async () => {
    await seed(path, order({
      status: 'rejected',
      reason: 'insufficient-funds',
      createdAt: Timestamp.now(),
      processedAt: Timestamp.now(),
    }));
    await assertFails(updateDoc(doc(asOwner(), path), { status: 'pending' }));
    await assertFails(setDoc(doc(asOwner(), path), order()));
  });

  test('a customer cannot delete an order', async () => {
    await seed(path, order({ createdAt: Timestamp.now() }));
    await assertFails(deleteDoc(doc(asOwner(), path)));
  });
});

describe('anything else', () => {
  test('a path no rule mentions is closed, even when signed in', async () => {
    await assertFails(getDoc(doc(asOwner(), 'secrets/keys')));
    await assertFails(setDoc(doc(asOwner(), 'secrets/keys'), { a: 1 }));
  });
});

// --- Notifications ---------------------------------------------------------

/** A device exactly as the app registers it. */
function device(overrides = {}) {
  return {
    token: 'fcm-token-of-this-installation',
    platform: 'android',
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

describe('users/{uid}/devices: the devices that receive notifications', () => {
  const OWN = `users/${OWNER}/devices/device-1`;

  test('a customer registers their own device', async () => {
    await assertSucceeds(setDoc(doc(asOwner(), OWN), device()));
  });

  test('a customer replaces the address of a device the console flagged',
    async () => {
      await seed(OWN, {
        token: 'old-token',
        platform: 'android',
        updatedAt: Timestamp.now(),
        unregistered: true,
        unregisteredAt: Timestamp.now(),
      });
      await assertSucceeds(
        setDoc(doc(asOwner(), OWN), device({ token: 'new-token' })),
      );
    });

  test('a customer removes their own device', async () => {
    await seed(OWN, device({ updatedAt: Timestamp.now() }));
    await assertSucceeds(deleteDoc(doc(asOwner(), OWN)));
  });

  test('a customer cannot register a device for another customer',
    async () => {
      await assertFails(
        setDoc(doc(asOtherCustomer(), OWN), device()),
      );
    });

  test('nobody else reads or removes a customer\'s devices', async () => {
    await seed(OWN, device({ updatedAt: Timestamp.now() }));
    await assertFails(getDoc(doc(asOtherCustomer(), OWN)));
    await assertFails(deleteDoc(doc(asOtherCustomer(), OWN)));
    await assertFails(getDoc(doc(asVisitor(), OWN)));
    await assertFails(setDoc(doc(asVisitor(), OWN), device()));
  });

  test('a device holds only its address, its platform and when it was saved',
    async () => {
      await assertFails(
        setDoc(doc(asOwner(), OWN), device({ unregistered: false })),
      );
      await assertFails(setDoc(doc(asOwner(), OWN), without(device(), 'platform')));
    });

  test('the address is a bounded, non-empty text', async () => {
    await assertFails(setDoc(doc(asOwner(), OWN), device({ token: '' })));
    await assertFails(setDoc(doc(asOwner(), OWN), device({ token: 42 })));
    await assertFails(
      setDoc(doc(asOwner(), OWN), device({ token: 'x'.repeat(4097) })),
    );
  });

  test('the platform is one the sender knows', async () => {
    await assertFails(setDoc(doc(asOwner(), OWN), device({ platform: 'web' })));
  });

  test('the time it was saved is the server\'s, not the device\'s', async () => {
    await assertFails(
      setDoc(doc(asOwner(), OWN), device({ updatedAt: Timestamp.fromMillis(0) })),
    );
  });

  test('a device identifier cannot be arbitrarily long', async () => {
    await assertFails(
      setDoc(doc(asOwner(), `users/${OWNER}/devices/${'d'.repeat(65)}`), device()),
    );
  });

  test('a device identifier is made of letters, digits, hyphens and underscores',
    async () => {
      await assertSucceeds(
        setDoc(doc(asOwner(), `users/${OWNER}/devices/a1-B2_c3`), device()),
      );
      for (const id of ['with space', 'dot.ted', 'acentuación', 'a$b']) {
        await assertFails(
          setDoc(doc(asOwner(), `users/${OWNER}/devices/${id}`), device()),
        );
      }
    });

  test('another customer cannot update or replace a customer\'s device',
    async () => {
      await seed(OWN, device({ updatedAt: Timestamp.now() }));
      await assertFails(
        setDoc(doc(asOtherCustomer(), OWN), device({ token: 'theirs' })),
      );
    });
});

describe('users/{uid}/inbox: notifications written by the server', () => {
  const OWN = `users/${OWNER}/inbox/n-1`;

  function notification(overrides = {}) {
    return {
      title: 'Nuevo inicio de sesión',
      body: 'Ingresaste desde tu dispositivo habitual.',
      kind: 'security',
      destination: 'profile',
      createdAt: Timestamp.now(),
      read: false,
      ...overrides,
    };
  }

  beforeEach(() => seed(OWN, notification()));

  test('a customer reads and lists their own inbox', async () => {
    await assertSucceeds(getDoc(doc(asOwner(), OWN)));
    await assertSucceeds(
      getDocs(query(
        collection(asOwner(), `users/${OWNER}/inbox`),
        orderBy('createdAt', 'desc'),
        limit(50),
      )),
    );
  });

  test('a customer marks a notification as read', async () => {
    await assertSucceeds(updateDoc(doc(asOwner(), OWN), { read: true }));
  });

  test('a read notification cannot go back to unread', async () => {
    await seed(OWN, notification({ read: true }));
    await assertFails(updateDoc(doc(asOwner(), OWN), { read: false }));
  });

  test('a customer cannot change what a notification says or where it leads',
    async () => {
      await assertFails(
        updateDoc(doc(asOwner(), OWN), { read: true, title: 'Otro título' }),
      );
      await assertFails(
        updateDoc(doc(asOwner(), OWN), { destination: 'transfer' }),
      );
      await assertFails(
        updateDoc(doc(asOwner(), OWN), { read: true, pinned: true }),
      );
    });

  test('a customer cannot write a notification into their own inbox',
    async () => {
      await assertFails(
        setDoc(doc(asOwner(), `users/${OWNER}/inbox/n-2`), notification()),
      );
    });

  test('nobody else can write a notification into a customer\'s inbox',
    async () => {
      const target = `users/${OWNER}/inbox/n-forged`;
      await assertFails(setDoc(doc(asOtherCustomer(), target), notification()));
      await assertFails(setDoc(doc(asVisitor(), target), notification()));
    });

  test('a notification stored without its read mark cannot be marked by a client',
    async () => {
      await seed(OWN, without(notification(), 'read'));
      await assertFails(updateDoc(doc(asOwner(), OWN), { read: true }));
    });

  test('the read mark is true or false, nothing else', async () => {
    await assertFails(updateDoc(doc(asOwner(), OWN), { read: 'true' }));
    await assertFails(updateDoc(doc(asOwner(), OWN), { read: 1 }));
  });

  test('a customer cannot delete a notification', async () => {
    await assertFails(deleteDoc(doc(asOwner(), OWN)));
  });

  test('nobody else reads or marks a customer\'s notifications', async () => {
    await assertFails(getDoc(doc(asOtherCustomer(), OWN)));
    await assertFails(updateDoc(doc(asOtherCustomer(), OWN), { read: true }));
    await assertFails(getDoc(doc(asVisitor(), OWN)));
  });
});
