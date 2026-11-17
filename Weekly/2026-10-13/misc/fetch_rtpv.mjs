// Download the archived weekly ROOFTOP_PV_FORECAST packages covering the 120-day
// test window and keep only VIC1 rows. Read-only on everything outside the output dir.
import { writeFileSync, appendFileSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { extractZip } from './nemweb_peek.mjs';

const LIST = 'https://www.nemweb.com.au/Reports/ARCHIVE/ROOFTOP_PV/FORECAST/';
const BASE = 'https://www.nemweb.com.au/Reports/ARCHIVE/ROOFTOP_PV/FORECAST/';
const OUTDIR = process.argv[2] || 'C:\\Ash\\_research_20261013\\rtpv';
const FROM = '20260129', TO = '20260604';

mkdirSync(OUTDIR, { recursive: true });
const outCsv = join(OUTDIR, 'rooftop_pv_forecast_vic1.csv');

const res = await fetch(LIST, { headers: { 'User-Agent': 'Mozilla/5.0' } });
const html = await res.text();
const names = [...html.matchAll(/PUBLIC_ROOFTOP_PV_FORECAST_(\d{8})\.zip/g)].map(m => m[1]);
const uniq = [...new Set(names)].sort().filter(d => d >= FROM && d <= TO);
console.log(`packages found ${uniq.length}: ${uniq.join(' ')}`);

if (!existsSync(outCsv)) {
  writeFileSync(outCsv, 'version_datetime,region_id,interval_datetime,power_mean,power_poe50,power_poe_low,power_poe_high\n', 'utf8');
}
const tmp = join(OUTDIR, '_pkg.zip');

for (const d of uniq) {
  const url = `${BASE}PUBLIC_ROOFTOP_PV_FORECAST_${d}.zip`;
  const r = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  if (!r.ok) { console.log(`${d}: HTTP ${r.status}`); continue; }
  const buf = Buffer.from(await r.arrayBuffer());
  // the weekly package is a zip of per-snapshot zips, each holding one CSV
  const inner = extractZip(buf);
  const chunk = [];
  let snaps = 0;
  for (const e of inner) {
    const stamp = (e.name.match(/_(\d{14})_/) || [])[1] || '';
    const hhmm = stamp.slice(8, 12);
    if (hhmm !== '2330' && hhmm !== '0000') continue;   // keep the two origins we score from
    snaps++;
    const txt = extractZip(e.data)[0].data.toString('utf8');
    for (const line of txt.split(/\r?\n/)) {
      if (line[0] !== 'D') continue;
      const f = line.split(',');
      if (f[1] !== 'ROOFTOP' || f[2] !== 'FORECAST') continue;
      const g = f.slice(4).map(s => s.replace(/^"|"$/g, ''));
      if (g[1] !== 'VIC1') continue;
      chunk.push(`${g[0]},${g[1]},${g[2]},${g[3]},${g[4]},${g[5]},${g[6]}`);
    }
  }
  appendFileSync(outCsv, chunk.join('\n') + (chunk.length ? '\n' : ''), 'utf8');
  console.log(`${d}: zip ${(buf.length / 1048576).toFixed(1)} MB  inner ${inner.length}  kept snaps ${snaps}  vic1 rows ${chunk.length}`);
}
try { rmSync(tmp, { force: true }); } catch {}
console.log('done ->', outCsv);
