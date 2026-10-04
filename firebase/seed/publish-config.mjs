#!/usr/bin/env node
// Development tool: publishes the home configuration to `config/home`, the
// document the app listens to. It stands in for the backoffice until that
// exists, and lets the resilience lab be exercised from a terminal.
//
// It writes with the developer's own Google credentials, which bypass the
// security rules exactly as the server will. Nothing secret is read from or
// written to the repository.
//
//   node seed/publish-config.mjs                        the contract example
//   node seed/publish-config.mjs --bump                 same, next version
//   node seed/publish-config.mjs --bump --latency-ms 5000
//   node seed/publish-config.mjs --bump --movements-unavailable
//   node seed/publish-config.mjs --bump --from my-config.json
//   node seed/publish-config.mjs --dry-run
//
// Publishing without the fault flags lifts every fault: the document is
// replaced whole.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { parseArgs } from 'node:util';

import {
  CONTRACT_EXAMPLE,
  buildConfigDocument,
  toFirestoreFields,
} from './config-document.mjs';

/** The only project this tool writes to unless told otherwise. */
const DEMO_PROJECT = 'flutter-challenge-bi';
const DATABASE = '(default)';
const DOCUMENT = 'config/home';

const { values: options } = parseArgs({
  options: {
    from: { type: 'string', default: CONTRACT_EXAMPLE },
    'latency-ms': { type: 'string' },
    'movements-unavailable': { type: 'boolean', default: false },
    'config-version': { type: 'string' },
    bump: { type: 'boolean', default: false },
    project: { type: 'string', default: DEMO_PROJECT },
    'allow-other-project': { type: 'boolean', default: false },
    'dry-run': { type: 'boolean', default: false },
  },
});

function fail(message) {
  console.error(`publish-config: ${message}`);
  process.exit(1);
}

if (options.project !== DEMO_PROJECT && !options['allow-other-project']) {
  fail(
    `refusing to write to "${options.project}". This tool is for ` +
      `${DEMO_PROJECT}; pass --allow-other-project if you really mean it.`,
  );
}
if (options.bump && options['config-version'] !== undefined) {
  fail('--bump and --config-version cannot be used together');
}

/**
 * The developer's access token: from the environment, else the application
 * default credentials, else the gcloud account.
 */
function accessToken() {
  if (process.env.GOOGLE_OAUTH_ACCESS_TOKEN) {
    return process.env.GOOGLE_OAUTH_ACCESS_TOKEN;
  }
  for (const command of [
    ['auth', 'application-default', 'print-access-token'],
    ['auth', 'print-access-token'],
  ]) {
    try {
      return execFileSync('gcloud', command, {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
    } catch {
      // Try the next source.
    }
  }
  return fail(
    'no credentials. Run `gcloud auth application-default login`, ' +
      '`gcloud auth login`, or set GOOGLE_OAUTH_ACCESS_TOKEN.',
  );
}

const documentUrl =
  `https://firestore.googleapis.com/v1/projects/${options.project}` +
  `/databases/${DATABASE}/documents`;

async function request(url, token, init = {}) {
  const response = await fetch(url, {
    ...init,
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      'x-goog-user-project': options.project,
    },
  });
  return response;
}

/** The version published right now, or null when nothing is published. */
async function publishedVersion(token) {
  const response = await request(`${documentUrl}/${DOCUMENT}`, token);
  if (response.status === 404) return null;
  if (!response.ok) {
    fail(`${response.status} reading ${DOCUMENT}: ${await response.text()}`);
  }
  const version = (await response.json()).fields?.configVersion?.integerValue;
  return version === undefined ? null : Number(version);
}

function numberOption(name) {
  const text = options[name];
  return text === undefined ? undefined : Number(text);
}

let base;
try {
  base = JSON.parse(readFileSync(options.from, 'utf8'));
} catch (error) {
  fail(`cannot read ${options.from}: ${error.message}`);
}

const token = options['dry-run'] && !options.bump ? null : accessToken();

let configVersion = numberOption('config-version');
if (options.bump) {
  const current = await publishedVersion(token);
  configVersion = (current ?? base.configVersion ?? 0) + 1;
}

let document;
try {
  document = buildConfigDocument(base, {
    latencyMs: numberOption('latency-ms'),
    movementsUnavailable: options['movements-unavailable'],
    configVersion,
  });
} catch (error) {
  fail(error.message);
}

console.log(`Project:  ${options.project}`);
console.log(`Document: ${DOCUMENT}`);
console.log(`Source:   ${options.from}`);
console.log('Will publish:');
console.log(`  configVersion  ${document.configVersion}`);
console.log(`  resilience     ${JSON.stringify(document.resilience)}`);
for (const [id, segment] of Object.entries(document.segments ?? {})) {
  const modules = (segment.modules ?? [])
    .map((module) => (module.visible === false ? `(${module.id})` : module.id))
    .join(', ');
  console.log(`  ${id.padEnd(13)}  ${modules}`);
}

if (options['dry-run']) {
  console.log('Dry run: nothing was written.');
  process.exit(0);
}

const response = await request(`${documentUrl}:commit`, token, {
  method: 'POST',
  body: JSON.stringify({
    writes: [
      {
        update: {
          name:
            `projects/${options.project}/databases/${DATABASE}` +
            `/documents/${DOCUMENT}`,
          fields: toFirestoreFields(document),
        },
      },
    ],
  }),
});
if (!response.ok) {
  fail(`${response.status} writing ${DOCUMENT}: ${await response.text()}`);
}

console.log(`Published version ${document.configVersion}.`);
