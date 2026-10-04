// Checks a static site folder and returns the problems found, one line each.
// It has no dependencies: the pages are simple enough to read with patterns.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';

// Written in parts so this file does not contain the names it looks for.
const VENDOR_NAMES = [
  ['cl', 'aude'],
  ['anth', 'ropic'],
  ['open', 'ai'],
  ['chat', 'gpt'],
  ['cop', 'ilot'],
  ['gem', 'ini'],
].map((parts) => parts.join(''));

const EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/;
const PASSWORD_AFTER_LABEL = /contraseña:\s*\S/i;
// Lower case, upper case, a digit and a symbol in one run of eight or more.
const PASSWORD_LIKE =
  /(?=\S*[a-z])(?=\S*[A-Z])(?=\S*\d)(?=\S*[#@$!%*?&_])\S{8,}/;

function filesIn(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? filesIn(full) : [full];
  });
}

function attributes(tag) {
  const found = {};
  for (const match of tag.matchAll(/([\w-]+)(?:="([^"]*)")?/g)) {
    found[match[1]] = match[2] ?? '';
  }
  return found;
}

function visibleText(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/g, ' ')
    .replace(/<style[\s\S]*?<\/style>/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&[a-z]+;/g, ' ');
}

function isExternal(reference) {
  return /^(https?:|mailto:|tel:)/.test(reference);
}

/** Problems in the text of any file: names, addresses and secrets. */
function textProblems(label, text) {
  const problems = [];
  const lower = text.toLowerCase();
  for (const name of VENDOR_NAMES) {
    if (new RegExp(`\\b${name}\\b`).test(lower)) {
      problems.push(`${label}: names an AI tool or vendor`);
    }
  }
  if (EMAIL.test(text)) problems.push(`${label}: contains an email address`);
  if (PASSWORD_AFTER_LABEL.test(text)) {
    problems.push(`${label}: contains a password after its label`);
  }
  return problems;
}

/**
 * Returns every problem found in the site rooted at [root].
 */
export function checkSite(root) {
  const problems = [];
  const files = filesIn(root);
  const pages = files.filter((file) => file.endsWith('.html'));

  const resolve = (page, reference) => {
    const clean = reference.split('#')[0].split('?')[0];
    if (clean === '') return page;
    return clean.startsWith('/')
      ? path.join(root, clean)
      : path.join(path.dirname(page), clean);
  };

  const idsOf = (file) =>
    new Set(
      [...readFileSync(file, 'utf8').matchAll(/\sid="([^"]+)"/g)].map(
        (match) => match[1],
      ),
    );

  for (const page of pages) {
    const label = path.relative(root, page);
    const html = readFileSync(page, 'utf8');

    if (!/<html lang="es">/.test(html)) {
      problems.push(`${label}: the page does not declare Spanish`);
    }
    if (!/<meta name="robots" content="noindex, nofollow">/.test(html)) {
      problems.push(`${label}: missing the noindex meta`);
    }
    if (!/<title>[^<]{5,}<\/title>/.test(html)) {
      problems.push(`${label}: missing a title`);
    }
    if (!/<meta name="description" content="[^"]{20,}">/.test(html)) {
      problems.push(`${label}: missing a description`);
    }
    if ((html.match(/<h1[\s>]/g) ?? []).length !== 1) {
      problems.push(`${label}: must have exactly one h1`);
    }
    if (!/href="\/?avisos\.html"/.test(html)) {
      problems.push(`${label}: does not link to the notices`);
    }
    if (/\sstyle="/.test(html) || /<style[\s>]/.test(html)) {
      problems.push(`${label}: inline styles break the content policy`);
    }
    if (/<script(?![^>]*\ssrc=)[^>]*>/.test(html)) {
      problems.push(`${label}: inline scripts break the content policy`);
    }

    for (const match of html.matchAll(/<(a|link|script|img)\s([^>]*)>/g)) {
      const tag = match[1];
      const attrs = attributes(match[2]);
      const reference = tag === 'a' || tag === 'link' ? attrs.href : attrs.src;

      if (tag === 'img') {
        if (!reference) {
          problems.push(`${label}: an image slot is empty`);
          continue;
        }
        if (!attrs.alt || attrs.alt.trim().length < 10) {
          problems.push(`${label}: ${reference} lacks a real alt text`);
        }
        if (!attrs.width || !attrs.height) {
          problems.push(`${label}: ${reference} lacks width and height`);
        }
      }
      if (reference === undefined || reference === '') continue;
      if (isExternal(reference)) {
        if (reference.startsWith('mailto:')) {
          problems.push(`${label}: contains an email link`);
        }
        continue;
      }

      const target = resolve(page, reference);
      if (!existsSync(target) || !statSync(target).isFile()) {
        problems.push(`${label}: ${reference} does not resolve`);
        continue;
      }
      if (statSync(target).size === 0) {
        problems.push(`${label}: ${reference} is an empty file`);
      }
      const fragment = reference.split('#')[1];
      if (fragment && !idsOf(target).has(fragment)) {
        problems.push(`${label}: ${reference} points to a missing anchor`);
      }
    }

    const text = visibleText(html);
    problems.push(...textProblems(label, html));
    if (PASSWORD_LIKE.test(text)) {
      problems.push(`${label}: contains something that looks like a password`);
    }
  }

  for (const file of files) {
    if (!/\.(css|js|txt|svg|json)$/.test(file)) continue;
    if (/-OFL\.txt$/.test(file)) continue; // Font licenses name their authors.
    problems.push(
      ...textProblems(path.relative(root, file), readFileSync(file, 'utf8')),
    );
  }

  return problems;
}
