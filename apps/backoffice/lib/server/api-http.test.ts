import { describe, expect, it } from "vitest";
import {
  failure,
  handleApi,
  MAX_BODY_BYTES,
  readJsonObject,
  type ApiLogEntry,
  type ApiRuntime,
} from "./api-http";

function post(body: BodyInit | null, headers: Record<string, string> = {}): Request {
  return new Request("http://localhost:3000/api/transfers", {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body,
  });
}

/** A body sent in pieces, with no length announced. */
function streamed(chunks: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  return new ReadableStream({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(encoder.encode(chunk));
      controller.close();
    },
  });
}

function runtime(times: number[] = [1_000, 1_042]): ApiRuntime & { entries: ApiLogEntry[] } {
  const entries: ApiLogEntry[] = [];
  let tick = 0;
  return {
    entries,
    log: (entry) => entries.push(entry),
    now: () => times[Math.min(tick++, times.length - 1)] ?? 0,
    newRequestId: () => "req-1",
  };
}

describe("failure", () => {
  it.each([
    ["invalid-request", 400],
    ["invalid-json", 400],
    ["unauthorized", 401],
    ["transfer-not-found", 404],
    ["idempotency-key-reused", 409],
    ["payload-too-large", 413],
    ["unsupported-media-type", 415],
    ["transfer-rejected", 422],
    ["profile-required", 422],
    ["internal", 500],
    ["unavailable", 503],
  ] as const)("answers %s with status %i", (code, status) => {
    expect(failure(code)).toEqual({ status, body: { error: code }, outcome: code });
  });

  it("carries the details the app needs next to the code", () => {
    expect(failure("invalid-request", { fields: ["amountCents"] })).toEqual({
      status: 400,
      body: { error: "invalid-request", fields: ["amountCents"] },
      outcome: "invalid-request",
    });
  });
});

describe("readJsonObject", () => {
  it("reads a JSON object", async () => {
    expect(await readJsonObject(post('{"amountCents":15010}'))).toEqual({
      ok: true,
      body: { amountCents: 15010 },
    });
  });

  it("accepts a content type that states its charset", async () => {
    const request = post("{}", { "content-type": "application/json; charset=utf-8" });

    expect(await readJsonObject(request)).toEqual({ ok: true, body: {} });
  });

  it.each([
    ["a form", "application/x-www-form-urlencoded"],
    ["plain text", "text/plain"],
  ])("refuses %s", async (_name, contentType) => {
    const request = post('{"amountCents":1}', { "content-type": contentType });

    expect(await readJsonObject(request)).toEqual({
      ok: false,
      error: "unsupported-media-type",
    });
  });

  it.each([
    ["text that is not JSON", "amountCents=15010"],
    ["JSON cut short", '{"amountCents":'],
    ["a list", "[1,2,3]"],
    ["a bare number", "15010"],
    ["null", "null"],
    ["an empty body", ""],
  ])("refuses %s", async (_name, body) => {
    expect(await readJsonObject(post(body))).toEqual({
      ok: false,
      error: "invalid-json",
    });
  });

  it("refuses bytes that are not UTF-8 text", async () => {
    const request = post(new Uint8Array([0x7b, 0x22, 0xff, 0xfe, 0x22, 0x7d]));

    expect(await readJsonObject(request)).toEqual({ ok: false, error: "invalid-json" });
  });

  it("accepts a body of exactly the limit", async () => {
    const padding = "a".repeat(MAX_BODY_BYTES - '{"concept":""}'.length);

    expect(await readJsonObject(post(`{"concept":"${padding}"}`))).toMatchObject({
      ok: true,
    });
  });

  it("refuses a body one byte over the limit", async () => {
    const padding = "a".repeat(MAX_BODY_BYTES - '{"concept":""}'.length + 1);

    expect(await readJsonObject(post(`{"concept":"${padding}"}`))).toEqual({
      ok: false,
      error: "payload-too-large",
    });
  });

  it("refuses an announced length over the limit without reading the body", async () => {
    const request = post("{}", { "content-length": String(MAX_BODY_BYTES + 1) });

    expect(await readJsonObject(request)).toEqual({
      ok: false,
      error: "payload-too-large",
    });
    expect(request.bodyUsed).toBe(false);
  });

  it("stops reading a body that grows past the limit without announcing it", async () => {
    const request = new Request("http://localhost:3000/api/transfers", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: streamed(['{"concept":"', "a".repeat(MAX_BODY_BYTES), '"}']),
      duplex: "half",
    } as RequestInit);

    expect(await readJsonObject(request)).toEqual({
      ok: false,
      error: "payload-too-large",
    });
  });

  it("counts bytes, not characters", async () => {
    // Each "ñ" is two bytes: this text fits in characters but not in bytes.
    const text = "ñ".repeat(MAX_BODY_BYTES / 2);

    expect(await readJsonObject(post(`{"concept":"${text}"}`))).toEqual({
      ok: false,
      error: "payload-too-large",
    });
  });
});

describe("handleApi", () => {
  it("answers with the status and body the route decided", async () => {
    const response = await handleApi(
      "transfers",
      async () => ({ status: 200, body: { transfer: { id: "t-1" } }, outcome: "completed" }),
      runtime(),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ transfer: { id: "t-1" } });
  });

  it("names the request in the answer and forbids caching it", async () => {
    const response = await handleApi(
      "transfers",
      async () => failure("unauthorized"),
      runtime(),
    );

    expect(response.headers.get("x-request-id")).toBe("req-1");
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("gives the route the request id it will answer with", async () => {
    let seen = "";

    await handleApi(
      "transfers",
      async (requestId) => {
        seen = requestId;
        return failure("unauthorized");
      },
      runtime(),
    );

    expect(seen).toBe("req-1");
  });

  it("logs one line with the outcome and the time taken, and nothing else", async () => {
    const world = runtime([1_000, 1_042]);

    await handleApi(
      "transfers",
      async () => ({
        status: 200,
        body: { transfer: { amountCents: 15_010, fromAccountId: "savings" } },
        outcome: "completed",
      }),
      world,
    );

    expect(world.entries).toEqual([
      {
        level: "info",
        requestId: "req-1",
        route: "transfers",
        status: 200,
        outcome: "completed",
        durationMs: 42,
      },
    ]);
  });

  it("answers an unexpected error with a generic code and logs only its kind", async () => {
    const world = runtime();

    const response = await handleApi(
      "transfers",
      async () => {
        throw new TypeError("users/uid-valentina/accounts/savings is broken");
      },
      world,
    );

    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({ error: "internal" });
    expect(world.entries).toEqual([
      {
        level: "error",
        requestId: "req-1",
        route: "transfers",
        status: 500,
        outcome: "internal:TypeError",
        durationMs: 42,
      },
    ]);
  });

  it.each([
    ["the database is unreachable", 14],
    ["the database took too long", 4],
    ["the transaction lost too many races", 10],
  ])("asks the app to try again when %s", async (_name, code) => {
    const world = runtime();

    const response = await handleApi(
      "transfers",
      async () => {
        throw Object.assign(new Error("database"), { code });
      },
      world,
    );

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "unavailable" });
    expect(world.entries[0]).toMatchObject({
      level: "error",
      status: 503,
      outcome: `unavailable:${code}`,
    });
  });
});
