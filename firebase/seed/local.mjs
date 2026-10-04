#!/usr/bin/env node
// Fills the Firebase emulators of a local stack with everything a demo
// needs: the published home configuration, an administrator for the
// console, and a customer with accounts, an investment and movements.
//
// It needs no Google credentials and never talks to the real project: it
// writes to the emulators with their owner token and refuses any host that
// is not this machine.
//
//   node seed/local.mjs
//
// Running it again rewrites the same documents. Start the emulators first
// (`tool/local-stack.sh up`).
import { readFileSync } from 'node:fs';

import {
  CONTRACT_EXAMPLE,
  buildConfigDocument,
  toFirestoreFields,
} from './config-document.mjs';
import {
  LOCAL_ADMIN,
  LOCAL_CUSTOMER,
  emulatorHosts,
  isLocalHost,
  profileOf,
} from './local-identities.mjs';
import { buildSeed } from './seed-data.mjs';

/** The project id the app is built for; the emulators keep it apart. */
const PROJECT = 'flutter-challenge-bi';
const DATABASE = '(default)';
/** The emulators take this token as the project owner. */
const OWNER = 'owner';

function fail(message) {
  console.error(`seed (local): ${message}`);
  process.exit(1);
}

const hosts = emulatorHosts(process.env);
for (const host of Object.values(hosts)) {
  if (!isLocalHost(host)) {
    fail(`refusing to write to ${host}: the local seed is for emulators on this machine.`);
  }
}

const AUTH = `http://${hosts.auth}/identitytoolkit.googleapis.com/v1`;
const FIRESTORE =
  `http://${hosts.firestore}/v1/projects/${PROJECT}/databases/${DATABASE}/documents`;
const DOCUMENTS = `projects/${PROJECT}/databases/${DATABASE}/documents`;

async function post(url, body, { asOwner = false } = {}) {
  let response;
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(asOwner ? { authorization: `Bearer ${OWNER}` } : {}),
      },
      body: JSON.stringify(body),
    });
  } catch {
    return fail(
      `nothing answers at ${new URL(url).host}. Start the emulators with ` +
        '`tool/local-stack.sh up`.',
    );
  }
  return { ok: response.ok, body: await response.json() };
}

/** The uid of the person with [email], created if the emulator lacks them. */
async function person(email, password) {
  const created = await post(`${AUTH}/accounts:signUp?key=local`, {
    email,
    password,
    returnSecureToken: true,
  });
  let uid = created.body.localId;
  if (!created.ok) {
    if (created.body.error?.message !== 'EMAIL_EXISTS') {
      fail(`could not create ${email}: ${created.body.error?.message}`);
    }
    const found = await post(
      `${AUTH}/projects/${PROJECT}/accounts:lookup`,
      { email: [email] },
      { asOwner: true },
    );
    uid = found.body.users?.[0]?.localId;
    if (!uid) fail(`${email} exists but could not be looked up`);
  }
  // The console only admits administrators whose address is verified.
  const verified = await post(
    `${AUTH}/projects/${PROJECT}/accounts:update`,
    { localId: uid, emailVerified: true, password },
    { asOwner: true },
  );
  if (!verified.ok) fail(`could not verify ${email}`);
  return uid;
}

/** A value of the seed (dates included) as the Firestore REST API takes it. */
function fields(data) {
  const plain = {};
  const dates = {};
  for (const [field, value] of Object.entries(data)) {
    if (value instanceof Date) {
      dates[field] = { timestampValue: value.toISOString() };
    } else {
      plain[field] = value;
    }
  }
  return { ...toFirestoreFields(plain), ...dates };
}

function write(path, data) {
  return { update: { name: `${DOCUMENTS}/${path}`, fields: fields(data) } };
}

async function commit(writes) {
  const committed = await post(`${FIRESTORE}:commit`, { writes }, { asOwner: true });
  if (!committed.ok) {
    fail(`the Firestore emulator refused the write: ${JSON.stringify(committed.body)}`);
  }
}

const now = new Date();
const config = buildConfigDocument(
  JSON.parse(readFileSync(CONTRACT_EXAMPLE, 'utf8')),
  {},
);
// `wealth` is the data set with an investment, so every segment of the
// home has something to show when the customer changes it in Perfil.
const seed = buildSeed(now, { segment: 'wealth' });

await person(LOCAL_ADMIN.email, LOCAL_ADMIN.password);
const uid = await person(LOCAL_CUSTOMER.email, LOCAL_CUSTOMER.password);

await commit([
  write('config/home', config),
  write(`users/${uid}`, profileOf(LOCAL_CUSTOMER, now)),
  ...seed.accounts.map(({ id, data }) => write(`users/${uid}/accounts/${id}`, data)),
  ...seed.movements.map(({ id, data }) => write(`users/${uid}/movements/${id}`, data)),
]);

console.log(`Emulators: auth ${hosts.auth}, firestore ${hosts.firestore}`);
console.log(`Published: config/home v${config.configVersion}`);
console.log(`Administrator: ${LOCAL_ADMIN.email}  /  ${LOCAL_ADMIN.password}`);
console.log(`Customer:      ${LOCAL_CUSTOMER.email}  /  ${LOCAL_CUSTOMER.password}`);
console.log(
  `               ${seed.accounts.length} accounts, ${seed.movements.length} movements`,
);
