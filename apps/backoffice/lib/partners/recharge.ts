/**
 * The mobile top-up of "Aliado Recargas", a simulated partner.
 *
 * Pure: it validates a request and describes the top-up it would register.
 * No operator is called and no money moves.
 */

export const OPERATORS = {
  claro: "Claro",
  movistar: "Movistar",
  cnt: "CNT",
  tuenti: "Tuenti",
} as const;

export type OperatorId = keyof typeof OPERATORS;

/** One dollar. */
export const MIN_AMOUNT_CENTS = 100;

/** Fifty dollars. */
export const MAX_AMOUNT_CENTS = 5000;

/** An Ecuadorian mobile number: ten digits starting with 09. */
const MOBILE_NUMBER = /^09\d{8}$/;

/** Digits of the number left visible, at each end, in a confirmation. */
const VISIBLE_DIGITS = 2;

export type TopUpField = "number" | "operator" | "amountCents";

/** Stable codes: the page turns them into text. */
export type TopUpProblem =
  | "required"
  | "not-a-mobile-number"
  | "unknown-operator"
  | "not-whole-cents"
  | "below-minimum"
  | "above-maximum";

export interface TopUpRequest {
  number: string;
  operator: OperatorId;
  amountCents: number;
}

export type TopUpParse =
  | { ok: true; request: TopUpRequest }
  | { ok: false; problems: Partial<Record<TopUpField, TopUpProblem>> };

export interface TopUp {
  operatorLabel: string;
  /** The number with its middle hidden: `09******67`. */
  maskedNumber: string;
  amountCents: number;
  currency: "USD";
}

function isOperator(value: unknown): value is OperatorId {
  return typeof value === "string" && Object.hasOwn(OPERATORS, value);
}

/**
 * Reads the body of a top-up request. Every field is checked here, on the
 * server: what the page validated is only a courtesy to the customer.
 *
 * The amount arrives in whole cents. A decimal amount is refused rather
 * than rounded: money is never guessed.
 */
export function parseTopUpRequest(body: unknown): TopUpParse {
  const fields =
    typeof body === "object" && body !== null && !Array.isArray(body)
      ? (body as Record<string, unknown>)
      : {};
  const problems: Partial<Record<TopUpField, TopUpProblem>> = {};

  const number = fields.number;
  if (number === undefined || number === "") problems.number = "required";
  else if (typeof number !== "string" || !MOBILE_NUMBER.test(number)) {
    problems.number = "not-a-mobile-number";
  }

  const operator = fields.operator;
  if (operator === undefined || operator === "") problems.operator = "required";
  else if (!isOperator(operator)) problems.operator = "unknown-operator";

  const amountCents = fields.amountCents;
  if (amountCents === undefined || amountCents === "") {
    problems.amountCents = "required";
  } else if (typeof amountCents !== "number" || !Number.isInteger(amountCents)) {
    problems.amountCents = "not-whole-cents";
  } else if (amountCents < MIN_AMOUNT_CENTS) {
    problems.amountCents = "below-minimum";
  } else if (amountCents > MAX_AMOUNT_CENTS) {
    problems.amountCents = "above-maximum";
  }

  if (Object.keys(problems).length > 0) return { ok: false, problems };

  return {
    ok: true,
    request: {
      number: number as string,
      operator: operator as OperatorId,
      amountCents: amountCents as number,
    },
  };
}

/** What a registered top-up says back. The full number is never echoed. */
export function topUp(request: TopUpRequest): TopUp {
  const hidden = "*".repeat(request.number.length - VISIBLE_DIGITS * 2);

  return {
    operatorLabel: OPERATORS[request.operator],
    maskedNumber:
      request.number.slice(0, VISIBLE_DIGITS) +
      hidden +
      request.number.slice(-VISIBLE_DIGITS),
    amountCents: request.amountCents,
    currency: "USD",
  };
}
