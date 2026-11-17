// Crude PDF text extraction: inflate FlateDecode streams and pull (...)Tj / TJ strings.
import { inflateSync, inflateRawSync } from 'node:zlib';

const url = process.argv[2];
const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
console.log('status', res.status, res.headers.get('content-type'));
const buf = Buffer.from(await res.arrayBuffer());
console.log('bytes', buf.length);

const chunks = [];
let i = 0;
while (true) {
  const s = buf.indexOf('stream', i);
  if (s < 0) break;
  let a = s + 6;
  if (buf[a] === 0x0d) a++;
  if (buf[a] === 0x0a) a++;
  const e = buf.indexOf('endstream', a);
  if (e < 0) break;
  const raw = buf.subarray(a, e);
  for (const fn of [inflateSync, inflateRawSync]) {
    try { chunks.push(fn(raw).toString('latin1')); break; } catch { /* try next */ }
  }
  i = e + 9;
}
console.log('inflated streams', chunks.length);
const text = chunks.join('\n');
const out = [];
const re = /\((?:\\.|[^\\()])*\)/g;
for (const m of text.matchAll(/(BT[\s\S]{0,20000}?ET)/g)) {
  const seg = m[1];
  const parts = [...seg.matchAll(re)].map(x => x[0].slice(1, -1)
    .replace(/\\([()\\])/g, '$1').replace(/\\n/g, ' ').replace(/\\r/g, ' '));
  if (parts.length) out.push(parts.join(''));
}
console.log('--- text blocks', out.length, '---');
console.log(out.join('\n').slice(0, 12000));
