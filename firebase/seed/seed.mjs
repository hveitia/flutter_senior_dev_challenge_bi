#!/usr/bin/env node
// Development tool: gives one customer two accounts and their movements, so
// the accounts screens have real data before the server API that opens
// accounts exists.
//
// It writes with the developer's own Google credentials (an access token
// from the gcloud CLI), which bypass the security rules exactly as the
// server will. Nothing secret is read from or written to the repository.
//
//   node seed/seed.mjs --email cliente@example.com [--dry-run]
//
// Running it again rewrites the same documents.
import { execFileSync } from 'node:child_process';
import { parseArgs } from 'node:util';

import { buildSeed } from './seed-data.mjs';

/** The only project this tool writes to unless told otherwise. */
const DEMO_PROJECT = 'flutter-challenge-bi';
const DATABASE = '(default)';

const { values: options } = parseArgs({
  options: {
    email: { type: 'string' },
    project: { type: 'string', default: DEMO_PROJECT },
    'allow-other-project': { type: 'boolean', default: false },
    'dry-run': { type: 'boolean', default: false },
  },
});

function fail(message) {
  console.error(`seed: ${message}`);
  process.exit(1);
}

if (!options.email) {
  fail('missing --email, the address the customer signed up with');
}
if (options.project !== DEMO_PROJECT && !options['allow-other-project']) {
  fail(
    `refusing to write to "${options.project}". This tool is for ` +
      `${DEMO_PROJECT}; pass --allow-other-project if you really mean it.`,
  );
}

/** The developer's access token: from the environment, else from gcloud. */
function accessToken() {
  if (process.env.GOOGLE_OAUTH_ACCESS_TOKEN) {
    return process.env.GOOGLE_OAUTH_ACCESS_TOKEN;
  }
  try {
    return execFileSync('gcloud', ['auth', 'print-access-token'], {
      encoding: 'utf8',
    }).trim();
  } catch {
    return fail(
      'no credentials. Run `gcloud auth login`, or set ' +
        'GOOGLE_OAUTH_ACCESS_TOKEN.',
    );
  }
}

async function call(url, token, body) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      'x-goog-user-project': options.project,
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    fail(`${response.status} from ${new URL(url).host}: ${await response.text()}`);
  }
  return response.json();
}

async function customerUid(token) {
  const found = await call(
    `https://identitytoolkit.googleapis.com/v1/projects/${options.project}/accounts:lookup`,
    token,
    { email: [options.email] },
  );
  const uid = found.users?.[0]?.localId;
  return uid ?? fail(`no customer has signed up with ${options.email}`);
}

/** A JavaScript value as the Firestore REST API expects it. */
function firestoreValue(value) {
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'string') return { stringValue: value };
  throw new TypeError(`unsupported value: ${value}`);
}

function write(documentPath, data) {
  return {
    update: {
      name: documentPath,
      fields: Object.fromEntries(
        Object.entries(data).map(([field, value]) => [
          field,
          firestoreValue(value),
        ]),
      ),
    },
  };
}

function dollars(cents) {
  const sign = cents < 0 ? '-' : '';
  return `${sign}$${(Math.abs(cents) / 100).toFixed(2)}`;
}

const seed = buildSeed(new Date());

console.log(`Project:  ${options.project}`);
console.log(`Customer: ${options.email}`);
console.log('Will write:');
for (const { id, data } of seed.accounts) {
  const count = seed.movements.filter(
    (movement) => movement.data.accountId === id,
  ).length;
  console.log(
    `  accounts/${id}  ${data.name} ${data.number}  ` +
      `${dollars(data.availableCents)}  (${count} movements)`,
  );
}

if (options['dry-run']) {
  console.log('Dry run: nothing was written.');
  process.exit(0);
}

const token = accessToken();
const uid = await customerUid(token);
const root =
  `projects/${options.project}/databases/${DATABASE}/documents/users/${uid}`;

await call(
  `https://firestore.googleapis.com/v1/projects/${options.project}/databases/${DATABASE}/documents:commit`,
  token,
  {
    writes: [
      ...seed.accounts.map(({ id, data }) =>
        write(`${root}/accounts/${id}`, data),
      ),
      ...seed.movements.map(({ id, data }) =>
        write(`${root}/movements/${id}`, data),
      ),
    ],
  },
);

console.log(
  `Wrote ${seed.accounts.length} accounts and ${seed.movements.length} ` +
    'movements.',
);
