import assert from 'node:assert/strict';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { checkSite } from './check-site.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const site = path.join(here, '..', 'public');

/** A page that passes every check, to break one thing at a time. */
function page({ head = '', body = '' } = {}) {
  return `<!doctype html>
<html lang="es">
  <head>
    <meta name="robots" content="noindex, nofollow">
    <title>Página de prueba</title>
    <meta name="description" content="Una página de prueba para el comprobador.">
    ${head}
  </head>
  <body>
    <h1>Prueba</h1>
    <a href="avisos.html">Avisos</a>
    ${body}
  </body>
</html>`;
}

/** Writes a throwaway site and returns what the checker says about it. */
function problemsOf(files) {
  const root = mkdtempSync(path.join(tmpdir(), 'showroom-'));
  try {
    const all = { 'avisos.html': page(), ...files };
    for (const [name, content] of Object.entries(all)) {
      mkdirSync(path.dirname(path.join(root, name)), { recursive: true });
      writeFileSync(path.join(root, name), content);
    }
    return checkSite(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

const has = (problems, fragment) =>
  problems.some((problem) => problem.includes(fragment));

test('a sound page has no problems', () => {
  assert.deepEqual(problemsOf({ 'index.html': page() }), []);
});

test('a link to a page that does not exist is reported', () => {
  const problems = problemsOf({
    'index.html': page({ body: '<a href="falta.html">Falta</a>' }),
  });
  assert.ok(has(problems, 'falta.html does not resolve'));
});

test('a link to an anchor that does not exist is reported', () => {
  const problems = problemsOf({
    'index.html': page({ body: '<a href="avisos.html#nada">Nada</a>' }),
  });
  assert.ok(has(problems, 'missing anchor'));
});

test('an image without alt text, size or file is reported', () => {
  const problems = problemsOf({
    'index.html': page({
      body: '<img src="a.webp"><img src="" alt="Una captura de la pantalla">',
    }),
  });
  assert.ok(has(problems, 'lacks a real alt text'));
  assert.ok(has(problems, 'lacks width and height'));
  assert.ok(has(problems, 'a.webp does not resolve'));
  assert.ok(has(problems, 'an image slot is empty'));
});

test('a page without the noindex meta or the notices link is reported', () => {
  const bare = `<!doctype html><html lang="es"><head><title>Sin avisos</title>
<meta name="description" content="Una página sin avisos ni noindex."></head>
<body><h1>Sin avisos</h1></body></html>`;
  const problems = problemsOf({ 'index.html': bare });
  assert.ok(has(problems, 'missing the noindex meta'));
  assert.ok(has(problems, 'does not link to the notices'));
});

test('an email address or a password is reported', () => {
  const address = ['persona', 'example.com'].join('@');
  const problems = problemsOf({
    'index.html': page({
      body: `<p>${address}</p><p>Contraseña: abc</p><p>Xy_12345z</p>`,
    }),
  });
  assert.ok(has(problems, 'contains an email address'));
  assert.ok(has(problems, 'a password after its label'));
  assert.ok(has(problems, 'looks like a password'));
});

test('inline styles and scripts are reported, since the content policy forbids them', () => {
  const problems = problemsOf({
    'index.html': page({
      body: '<p style="color: red">Rojo</p><script>var a = 1;</script>',
    }),
  });
  assert.ok(has(problems, 'inline styles'));
  assert.ok(has(problems, 'inline scripts'));
});

test('the delivery site has no problems', () => {
  assert.deepEqual(checkSite(site), []);
});

test('the recorded demo is a plain link on the home page and in the steps, never an embedded player', () => {
  const video = 'https://youtu.be/ZUzv-hzOfw4';
  for (const name of ['index.html', 'documentacion.html']) {
    const html = readFileSync(path.join(site, name), 'utf8');
    const link = html.match(
      new RegExp(`<a\\b[^>]*href="${video}"[^>]*>`),
    )?.[0];
    assert.notEqual(link, undefined, `${name} must link to the recorded demo`);
    assert.ok(/target="_blank"/.test(link), `${name}: opens in a new tab`);
    assert.ok(
      /rel="noopener noreferrer"/.test(link),
      `${name}: the link must not pass the opener or the referrer`,
    );
  }
  for (const name of ['index.html', 'documentacion.html', 'avisos.html', '404.html']) {
    const html = readFileSync(path.join(site, name), 'utf8');
    assert.ok(!/<iframe\b/i.test(html), `${name} must not embed a player`);
  }
});

test('the documentation names the onboarding and shows its three steps', () => {
  const html = readFileSync(path.join(site, 'documentacion.html'), 'utf8');
  assert.ok(
    /<h3>Onboarding y autenticación<\/h3>/.test(html),
    'the captures must have a section named after the requirement',
  );
  for (const step of ['datos', 'intereses', 'acceso']) {
    assert.ok(
      html.includes(`assets/img/app-onboarding-${step}.webp`),
      `the onboarding step "${step}" must have its capture`,
    );
  }
  const scope = html.slice(html.indexOf('id="alcance"'));
  assert.ok(
    /<td>Onboarding y autenticación/.test(scope),
    'the scope table must have a row for the onboarding',
  );
});

test('the installer address is empty or a secure address, and lives in one file', () => {
  const config = readFileSync(
    path.join(site, 'assets', 'js', 'config.js'),
    'utf8',
  );
  const address = config.match(/apkUrl:\s*"([^"]*)"/)?.[1];
  assert.notEqual(address, undefined, 'config.js must define apkUrl');
  assert.ok(
    address === '' || address.startsWith('https://'),
    'apkUrl must be empty or start with https://',
  );
  for (const name of ['index.html', 'documentacion.html']) {
    const html = readFileSync(path.join(site, name), 'utf8');
    assert.ok(!/\.apk/.test(html), `${name} must not name an installer itself`);
  }
});
