// 04: ROOFTOP_PV lives one level deeper than the brief assumed. Fetch the newest
// sample from each of its four nested subdirectories, in CURRENT and (for
// FORECAST) ARCHIVE.
import { writeFileSync, mkdirSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';

const OUT = 'C:\\Ash\\_research_20261013\\nemweb';
const HEADERS = { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-research/1.0' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
mkdirSync(join(OUT, 'samples'), { recursive: true });

const TARGETS = [
  ['CURRENT', 'ROOFTOP_PV/FORECAST', 'rooftop_forecast_current'],
  ['CURRENT', 'ROOFTOP_PV/FORECAST_AREA', 'rooftop_forecast_area_current'],
  ['CURRENT', 'ROOFTOP_PV/ACTUAL', 'rooftop_actual_current'],
  ['CURRENT', 'ROOFTOP_PV/ACTUAL_AREA', 'rooftop_actual_area_current'],
  ['ARCHIVE', 'ROOFTOP_PV/FORECAST', 'rooftop_forecast_archive'],
  ['ARCHIVE', 'ROOFTOP_PV/FORECAST_AREA', 'rooftop_forecast_area_archive'],
];

const rows = [];
for (const [base, sub, label] of TARGETS) {
  const baseUrl = base === 'CURRENT'
    ? 'https://www.nemweb.com.au/Reports/CURRENT/'
    : 'https://www.nemweb.com.au/Reports/ARCHIVE/';
  // each path segment must be encoded separately; keep the separator
  const url = baseUrl + sub.split('/').map(encodeURIComponent).join('/') + '/';
  const r = await fetch(url, { headers: HEADERS });
  const html = await r.text();
  const items = [...html.matchAll(/href="([^"]+)"/gi)].map((m) => m[1])
    .map((h) => h.split('/').pop())
    .filter((n) => n && n !== '../' && !n.startsWith('?'));
  const zips = items.filter((n) => /\.zip$/i.test(n)).sort();
  const newest = zips[zips.length - 1];
  const rec = { base, sub, label, status: r.status, zips: zips.length, newest };
  console.log(`${label.padEnd(32)} ${base}/${sub}: zips=${zips.length} newest=${newest ?? '-'}`);
  if (newest) {
    const dest = join(OUT, 'samples', label, newest);
    mkdirSync(join(OUT, 'samples', label), { recursive: true });
    if (existsSync(dest) && statSync(dest).size > 0) {
      rec.bytes = statSync(dest).size;
      rec.state = 'cached';
    } else {
      const rr = await fetch(url + encodeURIComponent(newest), { headers: HEADERS });
      if (!rr.ok) {
        rec.state = `HTTP ${rr.status}`;
      } else {
        const buf = Buffer.from(await rr.arrayBuffer());
        writeFileSync(dest, buf);
        rec.bytes = buf.length;
        rec.state = 'downloaded';
      }
    }
    console.log(`   ${rec.state} ${rec.bytes ?? 0} bytes`);
  }
  rows.push(rec);
  await sleep(600);
}

writeFileSync(join(OUT, 'rooftop_manifest.json'), JSON.stringify(rows, null, 1), 'utf8');
console.log('wrote rooftop_manifest.json');
