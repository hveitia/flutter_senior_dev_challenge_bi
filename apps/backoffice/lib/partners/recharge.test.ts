import { describe, expect, it } from "vitest";
import {
  MAX_AMOUNT_CENTS,
  MIN_AMOUNT_CENTS,
  parseTopUpRequest,
  topUp,
} from "./recharge";

const valid = { number: "0991234567", operator: "claro", amountCents: 500 };

function problems(body: unknown) {
  const result = parseTopUpRequest(body);
  return result.ok ? {} : result.problems;
}

describe("parseTopUpRequest", () => {
  it("reads a complete request", () => {
    expect(parseTopUpRequest(valid)).toEqual({ ok: true, request: valid });
  });

  it("asks for every field that is missing or empty", () => {
    const all = {
      number: "required",
      operator: "required",
      amountCents: "required",
    };

    expect(problems({})).toEqual(all);
    expect(problems({ number: "", operator: "", amountCents: "" })).toEqual(all);
    expect(problems(null)).toEqual(all);
    expect(problems([valid])).toEqual(all);
  });

  it("refuses a number that is not an Ecuadorian mobile", () => {
    for (const number of [
      "099123456",
      "09912345678",
      "0891234567",
      "9912345670",
      "099 123 4567",
      "+593991234567",
      "09912a4567",
      "0991234567\n",
      991234567,
    ]) {
      expect(problems({ ...valid, number }).number).toBe("not-a-mobile-number");
    }
  });

  it("refuses an operator it does not serve", () => {
    for (const operator of ["vodafone", "CLARO", "toString", 3]) {
      expect(problems({ ...valid, operator }).operator).toBe("unknown-operator");
    }
  });

  it("accepts the smallest and the largest amount", () => {
    expect(problems({ ...valid, amountCents: MIN_AMOUNT_CENTS })).toEqual({});
    expect(problems({ ...valid, amountCents: MAX_AMOUNT_CENTS })).toEqual({});
  });

  it("refuses one cent below the minimum and one above the maximum", () => {
    expect(problems({ ...valid, amountCents: MIN_AMOUNT_CENTS - 1 })).toEqual({
      amountCents: "below-minimum",
    });
    expect(problems({ ...valid, amountCents: MAX_AMOUNT_CENTS + 1 })).toEqual({
      amountCents: "above-maximum",
    });
    expect(problems({ ...valid, amountCents: 0 }).amountCents).toBe("below-minimum");
    expect(problems({ ...valid, amountCents: -500 }).amountCents).toBe("below-minimum");
  });

  it("refuses an amount that is not whole cents instead of rounding it", () => {
    for (const amountCents of [499.5, "500", NaN, Infinity, null, [500]]) {
      expect(problems({ ...valid, amountCents }).amountCents).toBe("not-whole-cents");
    }
  });

  it("ignores fields it does not know", () => {
    const result = parseTopUpRequest({ ...valid, cardNumber: "4111111111111111" });

    expect(result).toEqual({ ok: true, request: valid });
  });
});

describe("topUp", () => {
  it("answers with the operator, the amount and a number hidden in the middle", () => {
    expect(topUp({ number: "0991234567", operator: "cnt", amountCents: 1000 })).toEqual({
      operatorLabel: "CNT",
      maskedNumber: "09******67",
      amountCents: 1000,
      currency: "USD",
    });
  });
});
