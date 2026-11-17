// Extract one table for one region from a NEMWEB zip and print a compact table.
// usage: node nemweb_extract.mjs <url> <TABLE> <REGION> [colsCsv]
import { extractZip } from './nemweb_peek.mjs';

const [url, table, region, colsArg] = process.argv.slice(2);
const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
const buf = Buffer.from(await res.arrayBuffer());
const txt = extractZip(buf)[0].data.toString('utf8');
const lines = txt.split(/\r?\n/);

let head = null;
const rows = [];
for (const line of lines) {
  const f = line.split(',');
  if (f[1] !== table.split('|')[0] || f[2] !== table.split('|')[1]) continue;
  if (f[0] === 'I') { head = f.slice(4).map(s => s.replace(/^"|"$/g, '')); continue; }
  if (f[0] !== 'D') continue;
  const o = {};
  for (let i = 0; i < head.length; i++) o[head[i]] = (f[4 + i] ?? '').replace(/^"|"$/g, '');
  if (!region || o.REGIONID === region) rows.push(o);
}
console.log(`url ${url}`);
console.log(`table ${table}  region ${region}  rows ${rows.length}  cols ${head ? head.length : 0}`);
if (!rows.length) { console.log('no rows'); process.exit(0); }
const cols = colsArg ? colsArg.split(',') : head;
console.log(`columns present: ${head.join(',')}`);
console.log('');
console.log(cols.join(','));
for (const r of rows) console.log(cols.map(c => r[c]).join(','));
