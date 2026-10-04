/**
 * The document every partner mini app is served as.
 *
 * A partner page is plain HTML with one inline style and one inline script,
 * both allowed by a nonce. It shares nothing with the console: no React, no
 * bundle and no design tokens of the bank. It is meant to look like somebody
 * else's page, because it is one.
 */

const ESCAPES: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};

/** Makes [text] safe to place in HTML content or a quoted attribute. */
export function escapeHtml(text: string): string {
  return text.replace(/[&<>"']/g, (character) => ESCAPES[character] ?? character);
}

/**
 * The partner's own look: system font, square corners, a slate button.
 * Sizes are relative, so the page follows the text size of the device.
 */
const STYLE = String.raw`
:root { color-scheme: light; }
* { box-sizing: border-box; }
body {
  margin: 0; padding: 20px 16px 32px;
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  font-size: 1rem; line-height: 1.45; color: #1e293b; background: #ffffff;
}
.eyebrow { margin: 0 0 12px; font-size: 0.75rem; letter-spacing: 0.08em;
  text-transform: uppercase; color: #475569; }
h1 { margin: 0 0 4px; font-size: 1.375rem; line-height: 1.25; }
.lead { margin: 0 0 20px; color: #475569; }
label { display: block; margin: 16px 0 6px; font-weight: 600; font-size: 0.9375rem; }
input, select {
  width: 100%; min-height: 48px; padding: 10px 12px;
  font: inherit; color: inherit; background: #ffffff;
  border: 1px solid #64748b; border-radius: 4px;
}
input:focus-visible, select:focus-visible, button:focus-visible, a:focus-visible {
  outline: 3px solid #0f172a; outline-offset: 2px;
}
[aria-invalid="true"] { border-color: #b91c1c; border-width: 2px; }
.problem { margin: 6px 0 0; font-size: 0.875rem; color: #b91c1c; }
.problem::before { content: "\26A0\FE0E  "; }
button {
  width: 100%; min-height: 48px; margin-top: 24px; padding: 12px 16px;
  font: inherit; font-weight: 600; color: #ffffff; background: #334155;
  border: 0; border-radius: 4px;
}
button[disabled] { background: #64748b; }
button.plain { margin-top: 12px; color: #1e293b; background: #ffffff;
  border: 1px solid #334155; }
.note { margin: 20px 0 0; font-size: 0.875rem; color: #475569; }
.result { margin-top: 24px; padding: 16px; border: 1px solid #64748b;
  border-radius: 4px; background: #f8fafc; }
.result h2 { margin: 0 0 8px; font-size: 1.0625rem; }
.result p { margin: 4px 0; }
.amount { font-size: 1.5rem; font-weight: 700; }
a { color: #1d4ed8; }
[hidden] { display: none !important; }
`;

/**
 * The page's side of the contract with the host app.
 *
 * It learns the context the host sends (language and segment, nothing that
 * identifies the customer) and offers the two things a page may say back:
 * that it is done, or that it wants to be closed. Outside the app there is
 * no host, and both do nothing.
 */
const HOST_BRIDGE = String.raw`
var partner = (function () {
  'use strict';
  var context = { locale: 'es-EC', segment: null };

  window.addEventListener('message', function (event) {
    if (event.origin !== window.location.origin) return;
    var data = event.data;
    if (!data || data.type !== 'context' || data.version !== 1) return;
    if (typeof data.locale === 'string') context.locale = data.locale;
    if (typeof data.segment === 'string') context.segment = data.segment;
  });

  function post(message) {
    var host = window.BancaDigitalHost;
    if (host && typeof host.postMessage === 'function') {
      host.postMessage(JSON.stringify(message));
    }
  }

  return {
    context: context,
    completed: function (reference) {
      post({ type: 'completed', reference: reference });
    },
    close: function () { post({ type: 'close' }); },
    money: function (cents) {
      var whole = Math.floor(cents / 100).toString().replace(/\B(?=(\d{3})+$)/g, ',');
      var rest = (cents % 100).toString();
      return '$' + whole + '.' + (rest.length < 2 ? '0' + rest : rest);
    },
    send: function (path, body) {
      return fetch(path, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'omit',
        body: JSON.stringify(body)
      }).then(function (response) {
        return response.json().then(function (answer) {
          return { status: response.status, answer: answer };
        });
      });
    }
  };
})();
`;

export interface PartnerPage {
  /** The title of the document, and of the page for a screen reader. */
  title: string;
  /** Trusted markup of the page: it never contains anything a visitor sent. */
  body: string;
  /** The page's own script. It runs after the bridge and may use `partner`. */
  script: string;
  nonce: string;
}

export function renderPage(page: PartnerPage): string {
  const nonce = escapeHtml(page.nonce);

  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(page.title)}</title>
<style nonce="${nonce}">${STYLE}</style>
</head>
<body>
${page.body}
<script nonce="${nonce}">${HOST_BRIDGE}
${page.script}</script>
</body>
</html>
`;
}
