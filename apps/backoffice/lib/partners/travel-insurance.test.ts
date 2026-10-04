import { describe, expect, it } from "vitest";
import {
  MAX_DAYS_AHEAD,
  MAX_TRAVELERS,
  MAX_TRIP_DAYS,
  parseQuoteRequest,
  quote,
  utcDay,
  type QuoteRequest,
} from "./travel-insurance";

const TODAY = utcDay(new Date("2026-10-03T15:00:00Z"));

const valid = {
  region: "europe",
  departure: "2026-11-10",
  return: "2026-11-19",
  travelers: 2,
};

function parsed(body: unknown): QuoteRequest {
  const result = parseQuoteRequest(body, TODAY);
  if (!result.ok) throw new Error(JSON.stringify(result.problems));
  return result.request;
}

function problems(body: unknown) {
  const result = parseQuoteRequest(body, TODAY);
  return result.ok ? {} : result.problems;
}

describe("parseQuoteRequest", () => {
  it("reads a complete request", () => {
    const request = parsed(valid);

    expect(request.region).toBe("europe");
    expect(request.returnDay - request.departureDay).toBe(9);
    expect(request.travelers).toBe(2);
    expect(request.segment).toBeNull();
  });

  it("asks for every field that is missing or empty", () => {
    expect(problems({})).toEqual({
      region: "required",
      departure: "required",
      return: "required",
      travelers: "required",
    });
    expect(
      problems({ region: "", departure: "", return: "", travelers: "" }),
    ).toEqual({
      region: "required",
      departure: "required",
      return: "required",
      travelers: "required",
    });
  });

  it("treats a body that is not an object as an empty one", () => {
    for (const body of [null, undefined, "europe", 7, ["europe"]]) {
      expect(Object.keys(problems(body))).toHaveLength(4);
    }
  });

  it("refuses a region it does not sell", () => {
    expect(problems({ ...valid, region: "mars" })).toEqual({
      region: "unknown-region",
    });
    expect(problems({ ...valid, region: "toString" })).toEqual({
      region: "unknown-region",
    });
  });

  it("refuses dates that are not dates", () => {
    for (const departure of ["10/11/2026", "2026-13-01", "2026-02-31", 20261110]) {
      expect(problems({ ...valid, departure }).departure).toBe("not-a-date");
    }
  });

  it("accepts a trip that starts today or yesterday, not earlier", () => {
    expect(problems({ ...valid, departure: "2026-10-03", return: "2026-10-05" })).toEqual({});
    expect(problems({ ...valid, departure: "2026-10-02", return: "2026-10-05" })).toEqual({});
    expect(problems({ ...valid, departure: "2026-10-01", return: "2026-10-05" })).toEqual({
      departure: "in-the-past",
    });
  });

  it("refuses a trip that starts more than a year ahead", () => {
    const limit = new Date((TODAY + MAX_DAYS_AHEAD) * 86_400_000);
    const beyond = new Date((TODAY + MAX_DAYS_AHEAD + 1) * 86_400_000);
    const iso = (date: Date) => date.toISOString().slice(0, 10);

    expect(
      problems({ ...valid, departure: iso(limit), return: iso(limit) }),
    ).toEqual({});
    expect(
      problems({ ...valid, departure: iso(beyond), return: iso(beyond) }).departure,
    ).toBe("too-far-ahead");
  });

  it("refuses a return before the departure", () => {
    expect(problems({ ...valid, return: "2026-11-09" })).toEqual({
      return: "before-departure",
    });
  });

  it("accepts a one-day trip", () => {
    expect(problems({ ...valid, return: valid.departure })).toEqual({});
  });

  it("refuses a trip longer than the limit, and accepts one of exactly it", () => {
    // 10 November plus 89 days is 7 February: 90 days with both ends.
    expect(problems({ ...valid, return: "2027-02-07" })).toEqual({});
    expect(problems({ ...valid, return: "2027-02-08" })).toEqual({
      return: "trip-too-long",
    });
    expect(MAX_TRIP_DAYS).toBe(90);
  });

  it("refuses a number of travelers out of range or not whole", () => {
    for (const travelers of [0, -1, MAX_TRAVELERS + 1, 1.5, "2", null, NaN]) {
      expect(problems({ ...valid, travelers }).travelers).toBe("out-of-range");
    }
    expect(problems({ ...valid, travelers: MAX_TRAVELERS })).toEqual({});
  });

  it("keeps a segment that is a plain identifier and ignores anything else", () => {
    expect(parsed({ ...valid, segment: "family" }).segment).toBe("family");
    for (const segment of ["", "my segment", "<script>", 7, null, "a".repeat(33)]) {
      expect(parsed({ ...valid, segment }).segment).toBeNull();
    }
  });
});

describe("quote", () => {
  it("charges days, both ends included, times travelers times the rate", () => {
    // 10 to 19 November is 10 days; Europe is 4.80 a day.
    expect(quote(parsed(valid))).toEqual({
      regionLabel: "Europa",
      days: 10,
      travelers: 2,
      dailyRateCents: 480,
      discountPercent: 0,
      totalCents: 9600,
      currency: "USD",
    });
  });

  it("charges one day for a trip that leaves and returns the same day", () => {
    const result = quote(parsed({ ...valid, region: "southAmerica", return: valid.departure, travelers: 1 }));

    expect(result.days).toBe(1);
    expect(result.totalCents).toBe(250);
  });

  it("takes ten percent off from four travelers on", () => {
    const three = quote(parsed({ ...valid, travelers: 3 }));
    const four = quote(parsed({ ...valid, travelers: 4 }));

    expect(three.discountPercent).toBe(0);
    expect(three.totalCents).toBe(14_400);
    // 10 days x 4 x 4.80 = 192.00, less 19.20.
    expect(four.discountPercent).toBe(10);
    expect(four.totalCents).toBe(17_280);
  });

  it("takes five percent off for the family segment, on top of the group", () => {
    const family = quote(parsed({ ...valid, segment: "family" }));
    const familyGroup = quote(parsed({ ...valid, travelers: 4, segment: "family" }));

    // 96.00 less 4.80.
    expect(family.totalCents).toBe(9120);
    // 192.00 less 15 percent, 28.80.
    expect(familyGroup.discountPercent).toBe(15);
    expect(familyGroup.totalCents).toBe(16_320);
  });

  it("rounds a discount down to whole cents", () => {
    // 1 day x 1 x 2.50 = 250 cents; 5 percent is 12.5, rounded down to 12.
    const result = quote(
      parsed({ region: "southAmerica", departure: "2026-11-10", return: "2026-11-10", travelers: 1, segment: "family" }),
    );

    expect(result.totalCents).toBe(238);
    expect(Number.isInteger(result.totalCents)).toBe(true);
  });

  it("prices the longest trip for the largest group without losing cents", () => {
    const result = quote(
      parsed({ region: "restOfWorld", departure: "2026-11-10", return: "2027-02-07", travelers: MAX_TRAVELERS }),
    );

    // 90 x 6 x 5.60 = 3,024.00, less 10 percent.
    expect(result.totalCents).toBe(272_160);
  });
});
