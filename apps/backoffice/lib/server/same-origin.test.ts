import { describe, expect, it } from "vitest";
import { isSameOrigin } from "./same-origin";

function request(headers: Record<string, string>): Request {
  return new Request("https://console.example.com/api/session", {
    method: "POST",
    headers,
  });
}

describe("isSameOrigin", () => {
  it("accepts a request sent by the console's own pages", () => {
    expect(
      isSameOrigin(
        request({
          origin: "https://console.example.com",
          host: "console.example.com",
        }),
      ),
    ).toBe(true);
  });

  it("rejects a request sent by a page on another site", () => {
    expect(
      isSameOrigin(
        request({ origin: "https://evil.example.net", host: "console.example.com" }),
      ),
    ).toBe(false);
  });

  it("rejects a request that does not say where it comes from", () => {
    expect(isSameOrigin(request({ host: "console.example.com" }))).toBe(false);
  });

  it("rejects an origin that is not a URL", () => {
    expect(
      isSameOrigin(request({ origin: "null", host: "console.example.com" })),
    ).toBe(false);
  });

  it("compares the port as part of the host", () => {
    expect(
      isSameOrigin(
        request({ origin: "http://localhost:3000", host: "localhost:3000" }),
      ),
    ).toBe(true);
    expect(
      isSameOrigin(
        request({ origin: "http://localhost:4000", host: "localhost:3000" }),
      ),
    ).toBe(false);
  });

  it("accepts the console's own pages behind a hosting platform's proxy", () => {
    // Firebase App Hosting serves the container from a `*.hosted.app` domain:
    // the container sees its internal host, the browser sent the public one.
    expect(
      isSameOrigin(
        request({
          origin: "https://backoffice--flutter-challenge-bi.us-east4.hosted.app",
          host: "backoffice-abc123-uk.a.run.app",
          "x-forwarded-host": "backoffice--flutter-challenge-bi.us-east4.hosted.app",
        }),
      ),
    ).toBe(true);
  });

  it("rejects another site even when the proxy forwards the console's host", () => {
    expect(
      isSameOrigin(
        request({
          origin: "https://evil.example.com",
          host: "backoffice-abc123-uk.a.run.app",
          "x-forwarded-host": "backoffice--flutter-challenge-bi.us-east4.hosted.app",
        }),
      ),
    ).toBe(false);
  });

  it("uses the forwarded host when the console sits behind a proxy", () => {
    expect(
      isSameOrigin(
        request({
          origin: "https://console.example.com",
          host: "internal:8080",
          "x-forwarded-host": "console.example.com",
        }),
      ),
    ).toBe(true);
  });
});
