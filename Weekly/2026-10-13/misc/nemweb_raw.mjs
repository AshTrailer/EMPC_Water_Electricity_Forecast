// Raw line dump of the first CSV entry in a NEMWEB zip, to fix the row grammar.
import { extractZip } from './nemweb_peek.mjs';

const url = process.argv[2];
const n = Number(process.argv[3] || 12);
const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
const buf = Buffer.from(await res.arrayBuffer());
const e = extractZip(buf)[0];
const txt = e.data.toString('utf8');
const lines = txt.split(/\r?\n/);
console.log(`entry ${e.name}  lines ${lines.length}`);
for (let i = 0; i < n; i++) console.log(`[${i}] ${lines[i].slice(0, 300)}`);
console.log('...');
for (let i = lines.length - n; i < lines.length; i++) console.log(`[${i}] ${lines[i].slice(0, 200)}`);
const first = new Map();
for (const l of lines) { const c = l.slice(0, 2); first.set(c, (first.get(c) || 0) + 1); }
console.log('first-two-chars histogram:', [...first.entries()].slice(0, 20));
