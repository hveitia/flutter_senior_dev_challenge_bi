// Tests for the data the seed tool writes. They need no emulator.
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { buildSeed } from './seed-data.mjs';

// A Saturday morning, before one of the "today" movements of the design.
const NOW = new Date(2026, 9, 3, 9, 0, 0);
const seed = buildSeed(NOW);

function account(id) {
  return seed.accounts.find((candidate) => candidate.id === id);
}

function movementsOf(accountId) {
  return seed.movements.filter(
    (movement) => movement.data.accountId === accountId,
  );
}

describe('accounts', () => {
  test('match the balances of the design', () => {
    assert.equal(account('savings').data.availableCents, 357035);
    assert.equal(account('savings').data.number, '22004821');
    assert.equal(account('checking').data.availableCents, 125000);
    assert.equal(account('checking').data.number, '22001093');
  });

  test('carry every field the app reads', () => {
    for (const { data } of seed.accounts) {
      assert.deepEqual(Object.keys(data).sort(), [
        'availableCents',
        'currency',
        'kind',
        'ledgerCents',
        'name',
        'number',
        'updatedAt',
      ]);
      assert.equal(data.currency, 'USD');
    }
  });
});

describe('movements', () => {
  test('are about thirty, across both accounts', () => {
    assert.ok(seed.movements.length >= 28 && seed.movements.length <= 34);
    assert.ok(movementsOf('savings').length > 0);
    assert.ok(movementsOf('checking').length > 0);
    assert.equal(
      movementsOf('savings').length + movementsOf('checking').length,
      seed.movements.length,
    );
  });

  test('add up to the booked balance of their account', () => {
    for (const { id, data } of seed.accounts) {
      const total = movementsOf(id).reduce(
        (sum, movement) => sum + movement.data.amountCents,
        0,
      );
      assert.equal(total, data.ledgerCents, id);
    }
  });

  test('are whole cents, never fractions', () => {
    for (const { data } of seed.movements) {
      assert.ok(Number.isInteger(data.amountCents), data.description);
    }
  });

  test('include the movements shown in the design', () => {
    // The four newest movements of the savings account, as the design
    // lists them.
    const newest = movementsOf('savings')
      .slice(0, 4)
      .map((movement) => [
        movement.data.description,
        movement.data.amountCents,
      ]);

    assert.deepEqual(newest, [
      ['Nómina de septiembre', 185000],
      ['Supermercado', -6480],
      ['Café de la mañana', -450],
      ['Transferencia recibida', 12000],
    ]);
  });

  test('are never dated in the future', () => {
    for (const { data } of seed.movements) {
      assert.ok(data.postedAt <= NOW, data.description);
    }
  });

  test('have unique ids that do not change between runs', () => {
    const ids = seed.movements.map((movement) => movement.id);
    assert.equal(new Set(ids).size, ids.length);

    const again = buildSeed(new Date(2026, 9, 9, 18, 30, 0));
    assert.deepEqual(
      again.movements.map((movement) => movement.id),
      ids,
    );
  });

  test('have unique references', () => {
    const references = seed.movements.map(
      (movement) => movement.data.reference,
    );
    assert.equal(new Set(references).size, references.length);
  });

  test('use only categories, channels and statuses the app knows', () => {
    const categories = new Set([
      'salary', 'transfer', 'groceries', 'dining', 'transport', 'services',
      'entertainment', 'health', 'cash', 'other',
    ]);
    const channels = new Set([
      'debit_card', 'transfer', 'payroll', 'atm', 'app', 'other',
    ]);

    for (const { data } of seed.movements) {
      assert.ok(categories.has(data.category), data.category);
      assert.ok(channels.has(data.channel), data.channel);
      assert.equal(data.status, 'completed');
    }
  });
});
