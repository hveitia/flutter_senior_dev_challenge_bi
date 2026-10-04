import { describe, expect, it } from "vitest";
import { MAX_CONCEPT_LENGTH, MAX_TRANSFER_CENTS } from "./transfer";
import {
  isTransferId,
  orderFromStored,
  parseTransferBody,
} from "./transfer-request";

const TRANSFER_ID = "4f1c2a9e-7b3d-4e21-9c55-0a1b2c3d4e5f";

const valid = {
  transferId: TRANSFER_ID,
  fromAccountId: "savings",
  toAccountId: "checking",
  amountCents: 15_010,
  concept: "Arriendo de octubre",
};

describe("isTransferId", () => {
  it("accepts a UUID", () => {
    expect(isTransferId(TRANSFER_ID)).toBe(true);
  });

  it.each([
    ["too short to be unique", "abc123"],
    ["longer than a document id should be", "a".repeat(65)],
    ["a path into another document", "../../config/home-aaaaaaaa"],
    ["text with spaces", "4f1c2a9e 7b3d 4e21 9c55"],
    ["not text", 1234567890123456],
    ["nothing", undefined],
  ])("refuses %s", (_name, value) => {
    expect(isTransferId(value)).toBe(false);
  });
});

describe("parseTransferBody", () => {
  it("reads a complete order", () => {
    expect(parseTransferBody(valid)).toEqual({
      ok: true,
      transferId: TRANSFER_ID,
      order: {
        fromAccountId: "savings",
        toAccountId: "checking",
        amountCents: 15_010,
        concept: "Arriendo de octubre",
      },
    });
  });

  it("treats a missing concept as an empty one", () => {
    const withoutConcept: Record<string, unknown> = { ...valid };
    delete withoutConcept.concept;

    expect(parseTransferBody(withoutConcept)).toMatchObject({
      ok: true,
      order: { concept: "" },
    });
  });

  it("trims the concept", () => {
    expect(parseTransferBody({ ...valid, concept: "  Regalo  " })).toMatchObject({
      ok: true,
      order: { concept: "Regalo" },
    });
  });

  it("accepts the longest concept and the largest amount", () => {
    expect(
      parseTransferBody({
        ...valid,
        concept: "a".repeat(MAX_CONCEPT_LENGTH),
        amountCents: MAX_TRANSFER_CENTS,
      }),
    ).toMatchObject({ ok: true });
  });

  it.each([
    ["an amount sent as text", { amountCents: "15010" }, ["amountCents"]],
    ["a fraction of a cent", { amountCents: 150.1 }, ["amountCents"]],
    ["zero", { amountCents: 0 }, ["amountCents"]],
    ["a negative amount", { amountCents: -1 }, ["amountCents"]],
    ["a cent over the limit", { amountCents: MAX_TRANSFER_CENTS + 1 }, ["amountCents"]],
    ["a missing amount", { amountCents: undefined }, ["amountCents"]],
    ["an idempotency key that is too short", { transferId: "abc" }, ["transferId"]],
    ["an account id that is a path", { fromAccountId: "a/b" }, ["fromAccountId"]],
    ["an empty account id", { toAccountId: "" }, ["toAccountId"]],
    ["the same account on both sides", { toAccountId: "savings" }, ["toAccountId"]],
    ["a concept that is not text", { concept: 42 }, ["concept"]],
    [
      "a concept one character too long",
      { concept: "a".repeat(MAX_CONCEPT_LENGTH + 1) },
      ["concept"],
    ],
    ["a concept with a line break", { concept: "uno\ndos" }, ["concept"]],
  ])("names the field for %s", (_name, change, fields) => {
    expect(parseTransferBody({ ...valid, ...change })).toEqual({ ok: false, fields });
  });

  it("names every wrong field at once, in a stable order", () => {
    expect(
      parseTransferBody({ transferId: 7, fromAccountId: null, amountCents: "x" }),
    ).toEqual({
      ok: false,
      fields: ["transferId", "fromAccountId", "toAccountId", "amountCents"],
    });
  });

  it("refuses a field it does not know instead of ignoring it", () => {
    expect(parseTransferBody({ ...valid, uid: "someone-else", status: "completed" })).toEqual({
      ok: false,
      fields: ["uid", "status"],
    });
  });
});

describe("orderFromStored", () => {
  const stored = {
    fromAccountId: "savings",
    toAccountId: "checking",
    amountCents: 15_010,
    concept: "Arriendo",
    status: "pending",
    createdAt: new Date("2026-10-03T14:00:00Z"),
  };

  it("reads the order out of a pending document, ignoring the rest", () => {
    expect(orderFromStored(stored)).toEqual({
      fromAccountId: "savings",
      toAccountId: "checking",
      amountCents: 15_010,
      concept: "Arriendo",
    });
  });

  it("leaves the amount as stored so the decision can refuse it", () => {
    expect(orderFromStored({ ...stored, amountCents: -5 })?.amountCents).toBe(-5);
  });

  it("reads a missing concept as empty", () => {
    const withoutConcept: Record<string, unknown> = { ...stored };
    delete withoutConcept.concept;

    expect(orderFromStored(withoutConcept)?.concept).toBe("");
  });

  it.each([
    ["nothing", null],
    ["a list", []],
    ["a document without accounts", { amountCents: 100 }],
    ["an amount stored as text", { ...stored, amountCents: "15010" }],
    ["an account id stored as a number", { ...stored, fromAccountId: 7 }],
    ["an account id that is a path", { ...stored, toAccountId: "a/b" }],
    ["a concept that is not text", { ...stored, concept: { nested: true } }],
    [
      "a concept longer than the limit",
      { ...stored, concept: "a".repeat(MAX_CONCEPT_LENGTH + 1) },
    ],
    ["a concept with a line break", { ...stored, concept: "Arriendo\noctubre" }],
  ])("cannot read %s", (_name, data) => {
    expect(orderFromStored(data)).toBeNull();
  });

  it("reads the concept the way a request body is read, without the spaces around it", () => {
    expect(orderFromStored({ ...stored, concept: "  Arriendo  " })).toMatchObject({
      concept: "Arriendo",
    });
  });
});
