#!/usr/bin/env node
// Builds data/wordblocks.json from the hand-edited text files in data/,
// injects it into index.html, and copies it into the Flutter app's assets.
//
//   node tools/build-data.mjs           build everything
//   node tools/build-data.mjs --check   fail if any generated file is out of date (for CI)
//
// Source files (UTF-8, one record per line, fields separated by "|", lines starting with # are ignored):
//   data/categories.txt  id|name
//   data/morphemes.txt   id|type(pre|root|suf)|forms|meaning|origin|category
//   data/words.txt       word|parts|meaning|literal|example
//                        parts: space-separated morpheme ids; write id=text when the
//                        spelling inside the word differs from the id (e.g. "de struct=stroy")
//   data/stories.txt     morphemeId|story|scene   (either may be empty)
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const CHECK = process.argv.includes('--check');
const errors = [];
const warnings = [];

function rows(file, nFields) {
  const text = readFileSync(join(ROOT, 'data', file), 'utf8');
  return text.split('\n').map((line, i) => ({ line, n: i + 1 }))
    .filter(({ line }) => line.trim() && !line.startsWith('#'))
    .map(({ line, n }) => {
      const f = line.split('|');
      if (f.length !== nFields) errors.push(`${file}:${n} expected ${nFields} fields, got ${f.length}`);
      return { f: f.map(s => s.trim()), where: `${file}:${n}` };
    });
}

const categories = rows('categories.txt', 2).map(({ f }) => ({ id: f[0], name: f[1] }));
const catIds = new Set(categories.map(c => c.id));

const morphemes = [];
const M = new Map();
for (const { f, where } of rows('morphemes.txt', 6)) {
  const [id, type, forms, meaning, origin, category] = f;
  if (M.has(id)) errors.push(`${where} duplicate morpheme id "${id}"`);
  if (!['pre', 'root', 'suf'].includes(type)) errors.push(`${where} type must be pre, root or suf`);
  if (!catIds.has(category)) errors.push(`${where} unknown category "${category}"`);
  const m = { id, type, forms, meaning, origin, category };
  M.set(id, m); morphemes.push(m);
}

for (const { f, where } of rows('stories.txt', 3)) {
  const [id, story, scene] = f;
  const m = M.get(id);
  if (!m) { errors.push(`${where} story for unknown morpheme "${id}"`); continue; }
  if (story) m.story = story;
  if (scene) m.scene = scene;
}

const words = [];
const seen = new Set();
const used = new Set();
for (const { f, where } of rows('words.txt', 5)) {
  const [word, partSpec, meaning, literal, example] = f;
  if (seen.has(word)) errors.push(`${where} duplicate word "${word}"`);
  seen.add(word);
  const parts = partSpec.split(/\s+/).map(tok => {
    const [id, text] = tok.split('=');
    if (!M.has(id)) errors.push(`${where} unknown morpheme "${id}" in ${word}`);
    used.add(id);
    return { id, text: text || id };
  });
  const joined = parts.map(p => p.text).join('');
  if (joined !== word) errors.push(`${where} parts spell "${joined}", not "${word}"`);
  if (!parts.some(p => M.get(p.id)?.type === 'root')) warnings.push(`${where} ${word} has no root`);
  words.push({ word, parts, meaning, literal, example });
}
for (const m of morphemes) if (!used.has(m.id)) warnings.push(`morpheme "${m.id}" is not used by any word`);

warnings.forEach(w => console.warn('warning:', w));
if (errors.length) {
  errors.forEach(e => console.error('error:', e));
  console.error(`\n${errors.length} error(s); nothing written.`);
  process.exit(1);
}

const data = { version: 1, categories, morphemes, words };
const json = JSON.stringify(data, null, 1) + '\n';

const targets = [];
targets.push([join(ROOT, 'data', 'wordblocks.json'), json]);

const htmlPath = join(ROOT, 'index.html');
const html = readFileSync(htmlPath, 'utf8');
const BEGIN = '/* WORDBLOCKS_DATA_BEGIN */', END = '/* WORDBLOCKS_DATA_END */';
const a = html.indexOf(BEGIN), b = html.indexOf(END);
if (a < 0 || b < a) { console.error('error: data markers not found in index.html'); process.exit(1); }
targets.push([htmlPath, html.slice(0, a + BEGIN.length) + 'const DATA=' + JSON.stringify(data) + ';' + html.slice(b)]);

const flutterAsset = join(ROOT, 'flutter_app', 'assets', 'wordblocks.json');
if (existsSync(dirname(flutterAsset))) targets.push([flutterAsset, json]);

let stale = 0;
for (const [path, content] of targets) {
  const current = existsSync(path) ? readFileSync(path, 'utf8') : null;
  if (current === content) continue;
  if (CHECK) { console.error(`out of date: ${path.slice(ROOT.length + 1)}`); stale++; }
  else writeFileSync(path, content);
}
if (CHECK && stale) { console.error('Run: node tools/build-data.mjs'); process.exit(1); }

const count = t => morphemes.filter(m => m.type === t).length;
console.log(`${CHECK ? 'Up to date' : 'Built'}: ${count('pre')} prefixes, ${count('root')} roots, ${count('suf')} suffixes, ${words.length} words, ${categories.length} categories.`);
