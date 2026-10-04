/**
 * The travel insurance quote of "Aliado Seguros", a simulated partner.
 *
 * Pure: it reads nothing and stores nothing. The route handler gives it the
 * request body and today's date; the page only shows what this answers.
 */

/** Daily rate per traveler, in cents of a dollar, by destination region. */
export const REGIONS = {
  southAmerica: { label: "Sudamérica", dailyRateCents: 250 },
  northAmerica: { label: "Norteamérica y el Caribe", dailyRateCents: 420 },
  europe: { label: "Europa", dailyRateCents: 480 },
  restOfWorld: { label: "Resto del mundo", dailyRateCents: 560 },
} as const;

export type RegionId = keyof typeof REGIONS;

export const MAX_TRAVELERS = 6;
export const MAX_TRIP_DAYS = 90;

/** How far ahead a trip may start. */
export const MAX_DAYS_AHEAD = 365;

/** The segment the family discount is for, as the host app names it. */
export const FAMILY_SEGMENT = "family";
export const FAMILY_DISCOUNT_PERCENT = 5;

const MS_PER_DAY = 86_400_000;
const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const SEGMENT = /^[a-zA-Z][a-zA-Z0-9]{0,31}$/;

export type QuoteField = "region" | "departure" | "return" | "travelers";

/** Stable codes: the page turns them into text. */
export type QuoteProblem =
  | "required"
  | "unknown-region"
  | "not-a-date"
  | "in-the-past"
  | "too-far-ahead"
  | "before-departure"
  | "trip-too-long"
  | "out-of-range";

export interface QuoteRequest {
  region: RegionId;
  /** Day the trip starts, as whole days since the epoch in UTC. */
  departureDay: number;
  returnDay: number;
  travelers: number;
  /** The customer's segment when the host app sent a usable one. */
  segment: string | null;
}

export type QuoteParse =
  | { ok: true; request: QuoteRequest }
  | { ok: false; problems: Partial<Record<QuoteField, QuoteProblem>> };

export interface Quote {
  regionLabel: string;
  days: number;
  travelers: number;
  dailyRateCents: number;
  discountPercent: number;
  totalCents: number;
  currency: "USD";
}

/** Whole days since the epoch of a calendar date, or null if it is not one. */
function dayOf(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const match = ISO_DATE.exec(value);
  if (!match) return null;

  const [year, month, day] = [Number(match[1]), Number(match[2]), Number(match[3])];
  const time = Date.UTC(year, month - 1, day);
  const date = new Date(time);
  // `Date.UTC` rolls 31 February over to March; a real date round-trips.
  const isReal =
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
  return isReal ? time / MS_PER_DAY : null;
}

/** Today as whole days since the epoch, by the calendar of UTC. */
export function utcDay(now: Date): number {
  return Math.floor(now.getTime() / MS_PER_DAY);
}

function isRegion(value: unknown): value is RegionId {
  return typeof value === "string" && Object.hasOwn(REGIONS, value);
}

/**
 * Reads the body of a quote request. Every field is checked here, on the
 * server: what the page validated is only a courtesy to the customer.
 *
 * A trip may start yesterday by the calendar of UTC, because a customer
 * west of it can still be on the previous day.
 */
export function parseQuoteRequest(body: unknown, today: number): QuoteParse {
  const fields =
    typeof body === "object" && body !== null && !Array.isArray(body)
      ? (body as Record<string, unknown>)
      : {};
  const problems: Partial<Record<QuoteField, QuoteProblem>> = {};

  const region = fields.region;
  if (region === undefined || region === "") problems.region = "required";
  else if (!isRegion(region)) problems.region = "unknown-region";

  const departureDay = dayOf(fields.departure);
  if (fields.departure === undefined || fields.departure === "") {
    problems.departure = "required";
  } else if (departureDay === null) problems.departure = "not-a-date";
  else if (departureDay < today - 1) problems.departure = "in-the-past";
  else if (departureDay > today + MAX_DAYS_AHEAD) {
    problems.departure = "too-far-ahead";
  }

  const returnDay = dayOf(fields.return);
  if (fields.return === undefined || fields.return === "") {
    problems.return = "required";
  } else if (returnDay === null) problems.return = "not-a-date";
  else if (departureDay !== null && returnDay < departureDay) {
    problems.return = "before-departure";
  } else if (
    departureDay !== null &&
    returnDay - departureDay + 1 > MAX_TRIP_DAYS
  ) {
    problems.return = "trip-too-long";
  }

  const travelers = fields.travelers;
  if (travelers === undefined || travelers === "") {
    problems.travelers = "required";
  } else if (
    typeof travelers !== "number" ||
    !Number.isInteger(travelers) ||
    travelers < 1 ||
    travelers > MAX_TRAVELERS
  ) {
    problems.travelers = "out-of-range";
  }

  if (Object.keys(problems).length > 0) return { ok: false, problems };

  const segment = fields.segment;
  return {
    ok: true,
    request: {
      region: region as RegionId,
      departureDay: departureDay as number,
      returnDay: returnDay as number,
      travelers: travelers as number,
      // Anything that is not a plain identifier is ignored, not refused:
      // the quote does not depend on the host sending it.
      segment:
        typeof segment === "string" && SEGMENT.test(segment) ? segment : null,
    },
  };
}

/**
 * Prices a trip: days, both ends included, times travelers times the daily
 * rate of the region, less the family discount. Whole cents throughout; a discount
 * is rounded down, in the partner's favor by less than a cent.
 */
export function quote(request: QuoteRequest): Quote {
  const region = REGIONS[request.region];
  const days = request.returnDay - request.departureDay + 1;
  const baseCents = days * request.travelers * region.dailyRateCents;

  // The one discount there is. It is stated on the page, and it is all the
  // partner does with what the host app tells it about the customer.
  const discountPercent =
    request.segment === FAMILY_SEGMENT ? FAMILY_DISCOUNT_PERCENT : 0;
  const discountCents = Math.floor((baseCents * discountPercent) / 100);

  return {
    regionLabel: region.label,
    days,
    travelers: request.travelers,
    dailyRateCents: region.dailyRateCents,
    discountPercent,
    totalCents: baseCents - discountCents,
    currency: "USD",
  };
}
