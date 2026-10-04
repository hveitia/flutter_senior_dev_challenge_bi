import { readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { MAX_BODY_BYTES } from "@/lib/partners/http";
import { responseHeaderRules } from "@/lib/http/response-headers";
import { GET as rechargePage } from "./recharge/route";
import { POST as topUp } from "./recharge/top-up/route";
import { POST as quote } from "./travel-insurance/quote/route";
import { GET as insurancePage } from "./travel-insurance/route";

/** A reference as the host app accepts it: a short plain code. */
const HOST_REFERENCE = /^[A-Za-z0-9-]{1,40}$/;

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("https://partners.example.com/partners/x", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function isoDay(offsetDays: number): string {
  return new Date(Date.now() + offsetDays * 86_400_000).toISOString().slice(0, 10);
}

const pages = [
  { name: "travel insurance", get: insurancePage, heading: "Viaja con tranquilidad" },
  { name: "recharge", get: rechargePage, heading: "Recargas" },
];

describe.each(pages)("the $name page", ({ get, heading }) => {
  it("is an HTML document in Spanish with its form", async () => {
    const response = get();
    const html = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toBe("text/html; charset=utf-8");
    expect(html).toContain('<html lang="es">');
    expect(html).toContain(`<h1>${heading}</h1>`);
    expect(html).toContain("<form");
  });

  it("allows only its own inline script and style, by a nonce", async () => {
    const response = get();
    const policy = response.headers.get("Content-Security-Policy") ?? "";
    const html = await response.text();
    const nonce = /script-src 'nonce-([0-9a-f]{32})'/.exec(policy)?.[1];

    expect(nonce).toBeDefined();
    expect(policy).toContain("default-src 'none'");
    expect(policy).toContain(`style-src 'nonce-${nonce}'`);
    expect(policy).toContain("connect-src 'self'");
    expect(policy).toContain("form-action 'none'");
    expect(policy).toContain("base-uri 'none'");
    expect(policy).toContain("frame-ancestors 'none'");
    expect(policy).not.toContain("unsafe");
    expect(html).toContain(`<script nonce="${nonce}">`);
    expect(html).toContain(`<style nonce="${nonce}">`);
    // One script and one style, both inline: nothing is fetched from elsewhere.
    expect(html.match(/<script/g)).toHaveLength(1);
    expect(html.match(/<style/g)).toHaveLength(1);
    expect(html).not.toMatch(/<(script|link|img|iframe)[^>]*\s(src|href)=/);
  });

  it("gets a new nonce on every request", () => {
    const first = get().headers.get("Content-Security-Policy");
    const second = get().headers.get("Content-Security-Policy");

    expect(first).not.toBe(second);
  });

  it("is never cached, sets no cookie and leaks no referrer", () => {
    const response = get();

    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("Referrer-Policy")).toBe("no-referrer");
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(response.headers.get("Set-Cookie")).toBeNull();
  });

  it("talks to the host only through the one channel of the contract", async () => {
    const html = await get().text();

    expect(html).toContain("window.BancaDigitalHost");
    expect(html).toContain("event.origin !== window.location.origin");
    expect(html).not.toContain("innerHTML");
    expect(html).not.toContain("document.cookie");
    expect(html).not.toContain("localStorage");
  });
});

describe("POST /partners/travel-insurance/quote", () => {
  const trip = {
    region: "europe",
    departure: isoDay(30),
    return: isoDay(39),
    travelers: 2,
  };

  it("prices a trip from the partner's rates and gives it a reference", async () => {
    const response = await quote(post(trip));
    const answer = await response.json();

    expect(response.status).toBe(200);
    expect(answer.quote).toMatchObject({
      regionLabel: "Europa",
      days: 10,
      travelers: 2,
      totalCents: 9600,
      currency: "USD",
    });
    expect(answer.reference).toMatch(/^SV-[0-9A-F]{8}$/);
    expect(answer.reference).toMatch(HOST_REFERENCE);
  });

  it("ignores a price sent by the page", async () => {
    const response = await quote(post({ ...trip, totalCents: 1, dailyRateCents: 0 }));

    expect((await response.json()).quote.totalCents).toBe(9600);
  });

  it("applies the family discount when the host sent that segment", async () => {
    const response = await quote(post({ ...trip, segment: "family" }));

    expect((await response.json()).quote.totalCents).toBe(9120);
  });

  it("answers 422 with a code per field for a request it cannot price", async () => {
    const response = await quote(post({ ...trip, region: "mars", travelers: 9 }));

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({
      error: "invalid",
      problems: { region: "unknown-region", travelers: "out-of-range" },
    });
  });

  it("refuses a trip that already started days ago", async () => {
    const response = await quote(post({ ...trip, departure: isoDay(-3) }));

    expect((await response.json()).problems.departure).toBe("in-the-past");
  });
});

describe("POST /partners/recharge/top-up", () => {
  const request = { number: "0991234567", operator: "movistar", amountCents: 500 };

  it("registers a top-up, hides the number and gives it a reference", async () => {
    const response = await topUp(post(request));
    const answer = await response.json();

    expect(response.status).toBe(200);
    expect(answer.topUp).toEqual({
      operatorLabel: "Movistar",
      maskedNumber: "09******67",
      amountCents: 500,
      currency: "USD",
    });
    expect(answer.reference).toMatch(/^RC-[0-9A-F]{8}$/);
    expect(JSON.stringify(answer)).not.toContain("0991234567");
  });

  it("answers 422 with a code per field for a request it cannot accept", async () => {
    const response = await topUp(post({ number: "123", operator: "x", amountCents: 1 }));

    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({
      error: "invalid",
      problems: {
        number: "not-a-mobile-number",
        operator: "unknown-operator",
        amountCents: "below-minimum",
      },
    });
  });
});

describe.each([
  { name: "quote", handler: quote },
  { name: "top-up", handler: topUp },
])("the $name endpoint, whatever it is sent", ({ handler }) => {
  it("refuses a body that is not declared as JSON", async () => {
    const response = await handler(post("region=europe", { "Content-Type": "text/plain" }));

    expect(response.status).toBe(415);
    expect(await response.json()).toEqual({ error: "unsupported-media-type" });
  });

  it("refuses a body that is not JSON", async () => {
    const response = await handler(post("{not json"));

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "not-json" });
  });

  it("refuses a body larger than the limit without parsing it", async () => {
    const response = await handler(post({ padding: "x".repeat(MAX_BODY_BYTES) }));

    expect(response.status).toBe(413);
    expect(await response.json()).toEqual({ error: "too-large" });
  });

  it("refuses a declared length above the limit without reading the body", async () => {
    const request = post({}, { "Content-Length": String(MAX_BODY_BYTES + 1) });

    const response = await handler(request);

    expect(response.status).toBe(413);
    expect(request.bodyUsed).toBe(false);
  });

  it("refuses a declared length that is not a number", async () => {
    const response = await handler(post({}, { "Content-Length": "many" }));

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "bad-length" });
  });

  it("stops reading a body that grows past the limit, whatever it declared", async () => {
    let chunksRead = 0;
    const chunk = new TextEncoder().encode("x".repeat(1024));
    const endless = new ReadableStream<Uint8Array>({
      pull(controller) {
        chunksRead += 1;
        controller.enqueue(chunk);
      },
    });
    const request = new Request("https://partners.example.com/partners/x", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: endless,
      // Required by the runtime for a streamed request body.
      duplex: "half",
    } as RequestInit);

    const response = await handler(request);

    expect(response.status).toBe(413);
    // The limit is two chunks; a few more may be buffered, never an
    // endless stream.
    expect(chunksRead).toBeLessThan(8);
  });

  it("answers 422, not 500, for JSON that is not an object", async () => {
    for (const body of ["null", "[]", '"text"', "7"]) {
      expect((await handler(post(body))).status).toBe(422);
    }
  });

  it("is never cached and sets no cookie", async () => {
    const response = await handler(post({}));

    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(response.headers.get("Set-Cookie")).toBeNull();
  });
});

describe("the travel insurance page", () => {
  it("says which discount exists and for whom", async () => {
    const html = await insurancePage().text();

    expect(html).toContain("5 % de descuento");
    expect(html).toContain("segmento Familia");
  });
});

describe("the headers the server adds to every partner route", () => {
  it("ask for no referrer, after the console's own rule so it wins", () => {
    const rules = responseHeaderRules();
    const partners = rules.findIndex((rule) => rule.source === "/partners/:path*");
    const everything = rules.findIndex((rule) => rule.source === "/:path*");

    expect(everything).toBeGreaterThanOrEqual(0);
    // The framework applies matching rules in order and the last value of
    // a header stands.
    expect(partners).toBeGreaterThan(everything);
    expect(rules[partners]?.headers).toContainEqual({
      key: "Referrer-Policy",
      value: "no-referrer",
    });
  });
});

describe("the partner code", () => {
  /** Every source file under a directory, tests left out. */
  function sources(directory: string): string[] {
    return readdirSync(directory).flatMap((name) => {
      const file = path.join(directory, name);
      if (statSync(file).isDirectory()) return sources(file);
      return /\.tsx?$/.test(name) && !name.includes(".test.") ? [file] : [];
    });
  }

  it("shares nothing with the console: no admin modules, session or Firebase", () => {
    const here = path.dirname(fileURLToPath(import.meta.url));
    const root = path.join(here, "..", "..");
    const files = [
      ...sources(path.join(root, "app", "partners")),
      ...sources(path.join(root, "lib", "partners")),
    ];
    expect(files.length).toBeGreaterThan(6);

    for (const file of files) {
      const imports = [...readFileSync(file, "utf8").matchAll(/from\s+"([^"]+)"/g)].map(
        (match) => match[1] ?? "",
      );
      for (const imported of imports) {
        const isOwn = imported.startsWith("@/lib/partners/") || imported.startsWith("./");
        expect(isOwn, `${path.relative(root, file)} imports ${imported}`).toBe(true);
      }
    }
  });
});
