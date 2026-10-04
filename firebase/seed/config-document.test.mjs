// Tests for the document the publish tool writes. They need no emulator.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, test } from 'node:test';

import {
  CONTRACT_EXAMPLE,
  MAX_LATENCY_MS,
  buildConfigDocument,
  toFirestoreFields,
} from './config-document.mjs';

const example = JSON.parse(readFileSync(CONTRACT_EXAMPLE, 'utf8'));

describe('the document to publish', () => {
  test('is the contract example when nothing is overridden', () => {
    assert.deepEqual(buildConfigDocument(example, {}), example);
  });

  test('does not change the example it was built from', () => {
    const before = structuredClone(example);

    buildConfigDocument(example, {
      latencyMs: 5000,
      movementsUnavailable: true,
      configVersion: 99,
    });

    assert.deepEqual(example, before);
  });

  test('carries the faults of the resilience lab that were asked for', () => {
    const document = buildConfigDocument(example, {
      latencyMs: 5000,
      movementsUnavailable: true,
    });

    assert.deepEqual(document.resilience, {
      latencyMs: 5000,
      movementsUnavailable: true,
      partnerInsuranceUnavailable: false,
    });
    assert.deepEqual(document.segments, example.segments);
  });

  test('takes the version it is told to publish', () => {
    assert.equal(
      buildConfigDocument(example, { configVersion: 21 }).configVersion,
      21,
    );
  });

  test('refuses a latency the contract does not allow', () => {
    for (const latencyMs of [-1, 2.5, MAX_LATENCY_MS + 1, Number.NaN]) {
      assert.throws(
        () => buildConfigDocument(example, { latencyMs }),
        RangeError,
        String(latencyMs),
      );
    }
  });

  test('refuses a version that is not a whole number from zero up', () => {
    for (const configVersion of [-1, 1.5, Number.NaN]) {
      assert.throws(
        () => buildConfigDocument(example, { configVersion }),
        RangeError,
        String(configVersion),
      );
    }
  });
});

describe('the document as the Firestore REST API expects it', () => {
  test('keeps the type of every value, at any depth', () => {
    assert.deepEqual(
      toFirestoreFields({
        configVersion: 14,
        ratio: 1.5,
        label: 'Estoy empezando',
        visible: true,
        nothing: null,
        destinations: ['accounts', 'services'],
        resilience: { latencyMs: 0, movementsUnavailable: false },
      }),
      {
        configVersion: { integerValue: '14' },
        ratio: { doubleValue: 1.5 },
        label: { stringValue: 'Estoy empezando' },
        visible: { booleanValue: true },
        nothing: { nullValue: null },
        destinations: {
          arrayValue: {
            values: [{ stringValue: 'accounts' }, { stringValue: 'services' }],
          },
        },
        resilience: {
          mapValue: {
            fields: {
              latencyMs: { integerValue: '0' },
              movementsUnavailable: { booleanValue: false },
            },
          },
        },
      },
    );
  });

  test('writes an empty list and an empty object as such', () => {
    assert.deepEqual(toFirestoreFields({ modules: [], props: {} }), {
      modules: { arrayValue: { values: [] } },
      props: { mapValue: { fields: {} } },
    });
  });

  test('converts the whole contract example without leaving a value out', () => {
    const fields = toFirestoreFields(example);

    assert.deepEqual(Object.keys(fields).sort(), Object.keys(example).sort());
    assert.equal(
      fields.segments.mapValue.fields.starting.mapValue.fields.modules
        .arrayValue.values.length,
      example.segments.starting.modules.length,
    );
  });

  test('refuses a value JSON cannot hold', () => {
    assert.throws(() => toFirestoreFields({ when: new Date() }), TypeError);
    assert.throws(() => toFirestoreFields({ run: () => {} }), TypeError);
  });
});
