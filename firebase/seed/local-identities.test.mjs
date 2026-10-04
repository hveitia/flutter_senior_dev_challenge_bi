import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  LOCAL_ADMIN,
  LOCAL_CUSTOMER,
  emulatorHosts,
  isLocalHost,
  profileOf,
} from './local-identities.mjs';

test('the profile has exactly the fields the rules accept', () => {
  const createdAt = new Date('2026-10-04T10:00:00Z');

  const profile = profileOf(LOCAL_CUSTOMER, createdAt);

  assert.deepEqual(Object.keys(profile).sort(), [
    'createdAt',
    'email',
    'fullName',
    'interests',
    'nationalId',
    'phone',
    'segment',
  ]);
  assert.equal(profile.createdAt, createdAt);
});

test('the customer passes the checks the rules make on a profile', () => {
  assert.match(LOCAL_CUSTOMER.nationalId, /^[0-9]{10}$/);
  assert.match(LOCAL_CUSTOMER.phone, /^09[0-9]{8}$/);
  assert.ok(['starting', 'family', 'wealth'].includes(LOCAL_CUSTOMER.segment));
  assert.equal(
    new Set(LOCAL_CUSTOMER.interests).size,
    LOCAL_CUSTOMER.interests.length,
  );
});

test('the people of a local stack use a reserved domain', () => {
  for (const { email } of [LOCAL_ADMIN, LOCAL_CUSTOMER]) {
    assert.ok(email.endsWith('.test'), email);
  }
});

test('the emulators are looked for where they listen by default', () => {
  assert.deepEqual(emulatorHosts({}), {
    auth: '127.0.0.1:9099',
    firestore: '127.0.0.1:8080',
  });
});

test('the environment can move the emulators', () => {
  const hosts = emulatorHosts({
    FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9199',
    FIRESTORE_EMULATOR_HOST: 'localhost:8181',
  });

  assert.deepEqual(hosts, { auth: 'localhost:9199', firestore: 'localhost:8181' });
});

test('only this machine counts as local', () => {
  for (const host of ['127.0.0.1:8080', 'localhost:9099', '[::1]:8080']) {
    assert.equal(isLocalHost(host), true, host);
  }
  for (const host of [
    'firestore.googleapis.com:443',
    '192.168.1.20:8080',
    'localhost.example.com:8080',
  ]) {
    assert.equal(isLocalHost(host), false, host);
  }
});
