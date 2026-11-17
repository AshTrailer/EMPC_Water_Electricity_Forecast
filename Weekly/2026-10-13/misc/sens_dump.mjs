// Print the 43 scenario prices for one VIC1 period and a couple of neighbours.
import { extractZip } from './nemweb_peek.mjs';

const url = process.argv[2];
const buf = Buffer.from(await (await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } })).arrayBuffer());
const txt = extractZip(buf)[0].data.toString('utf8');
let head = null;
const rows = [];
for (const line of txt.split(/\r?\n/)) {
  const f = line.split(',');
  if (f[1] !== 'PREDISPATCH' || f[2] !== 'PRICESENSITIVITIES') continue;
  if (f[0] === 'I') { head = f.slice(4).map(s => s.replace(/^"|"$/g, '')); continue; }
  if (f[0] !== 'D') continue;
  const o = {};
  for (let i = 0; i < head.length; i++) o[head[i]] = (f[4 + i] ?? '').replace(/^"|"$/g, '');
  if (o.REGIONID === 'VIC1') rows.push(o);
}
console.log(`VIC1 periods ${rows.length}  columns ${head.length}`);
const show = process.argv[3] ? Number(process.argv[3]) : 6;
const idx = [0, Math.floor(rows.length / 4), Math.floor(rows.length / 2), rows.length - 1].slice(0, show);
const scen = Array.from({ length: 43 }, (_, i) => `RRPEEP${i + 1}`);
console.log('scenario : ' + scen.map((_, i) => String(i + 1).padStart(10)).join(''));
for (const i of idx) {
  const r = rows[i];
  console.log(`\n--- period ${r.PERIODID}  DATETIME ${r.DATETIME}  INTERVENTION ${r.INTERVENTION}`);
  console.log(scen.map(s => (r[s] === undefined || r[s] === '' ? 'NA' : Number(r[s]).toFixed(2)).padStart(10)).join(''));
  const vals = scen.map(s => Number(r[s])).filter(Number.isFinite);
  console.log(`  populated ${vals.length}/43   min ${Math.min(...vals).toFixed(2)}  max ${Math.max(...vals).toFixed(2)}`);
}
