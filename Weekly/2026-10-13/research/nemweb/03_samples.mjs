// 03: Locate ROOFTOP_PV / intermittent / forecast directories in both CURRENT and
// ARCHIVE, then download one newest sample from each directory of interest.
//
// Several names in the brief do not exist verbatim on NEMWEB (P5MIN_Reports,
// DISPATCHIS_Reports, STPASA_Reports, MTPASA_Reports, BIDMOVE_Reports,
// CONSTRAINT_Reports, INTERMITTENTGEN_Reports, ROOFTOP_PV_FORECAST_Reports,
// PD7DAYIS_Reports). This maps them to the real directory names and records
// which have no counterpart at all.
import { writeFileSync, mkdirSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';

const OUT = 'C:\\Ash\\_research_20261013\\nemweb';
const HEADERS = { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-research/1.0' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
mkdirSync(join(OUT, 'samples'), { recursive: true });

async function listing(base, dir) {
  const url = `${base}${encodeURIComponent(dir)}/`;
  const r = await fetch(url, { headers: HEADERS });
  const html = await r.text();
  const items = [...html.matchAll(/href="([^"]+)"/gi)].map((m) => m[1])
    .map((h) => h.split('/').pop())
    .filter((n) => n && n !== '../' && n !== '..' && !n.startsWith('?'));
  const subdirs = [...html.matchAll(/href="([^"]+)"/gi)].map((m) => m[1])
    .filter((h) => /^\/Reports\/(CURRENT|ARCHIVE)\/[^/]+\/[^/]+$/i.test(h));
  return { url, status: r.status, items, subdirs, htmlLen: html.length, html };
}

// ---- part 1: where do rooftop / intermittent reports live? -------------------
console.log('=== directory probes ===');
const probes = [
  ['CURRENT', 'https://www.nemweb.com.au/Reports/CURRENT/', 'ROOFTOP_PV'],
  ['ARCHIVE', 'https://www.nemweb.com.au/Reports/ARCHIVE/', 'ROOFTOP_PV'],
];
const probeRows = [];
for (const [base, baseUrl, dir] of probes) {
  const info = await listing(baseUrl, dir);
  const zips = info.items.filter((n) => /\.zip$/i.test(n));
  const csvs = info.items.filter((n) => /\.csv$/i.test(n));
  console.log(`${base}/${dir}: status=${info.status} items=${info.items.length} zips=${zips.length} csv=${csvs.length} subdirs=${info.subdirs.length}`);
  console.log(`   sample items: ${info.items.slice(0, 6).join(' | ')}`);
  if (info.subdirs.length) console.log(`   subdirs: ${[...new Set(info.subdirs)].slice(0, 8).join(' | ')}`);
  probeRows.push({ base, dir, status: info.status, items: info.items.slice(0, 20),
                   zips: zips.length, csvs: csvs.length,
                   subdirs: [...new Set(info.subdirs)] });
  await sleep(500);
}

// also enumerate ARCHIVE root for anything forecast/price/demand/weather-ish
const archHtml = await (await fetch('https://www.nemweb.com.au/Reports/ARCHIVE/', { headers: HEADERS })).text();
const archDirs = [...new Set([...archHtml.matchAll(/href="([^"]+)"/gi)].map((m) => m[1])
  .filter((h) => /^\/Reports\/ARCHIVE\/[^/]+$/i.test(h))
  .map((h) => h.split('/').pop()))].sort();
const interesting = archDirs.filter((d) => /(FORECAST|PRICE|DEMAND|WEATHER|INTERMITTENT|ROOFTOP|PASA|FCST)/i.test(d));
console.log(`\nARCHIVE root dirs: ${archDirs.length}`);
console.log(`ARCHIVE dirs matching forecast/price/demand/weather: ${interesting.join(' | ')}`);
writeFileSync(join(OUT, 'dir_probes.json'),
  JSON.stringify({ probes: probeRows, archiveDirs: archDirs, archiveInteresting: interesting }, null, 1), 'utf8');

// ---- part 2: one newest sample per directory of interest --------------------
const TARGETS = [
  ['CURRENT', 'P5_Reports', 'p5min_current'],
  ['CURRENT', 'DispatchIS_Reports', 'dispatchis_current'],
  ['CURRENT', 'Short_Term_PASA_Reports', 'stpasa_current'],
  ['CURRENT', 'PD7Day', 'pd7day_current'],
  ['CURRENT', 'Medium_Term_PASA_Reports', 'mtpasa_current'],
  ['CURRENT', 'Bidmove_Complete', 'bidmove_current'],
  ['CURRENT', 'Weekly_Constraint_Reports', 'constraint_current'],
  ['CURRENT', 'DISPATCHFCST', 'dispatchfcst_current'],
  ['CURRENT', 'P5MINFCST', 'p5minfcst_current'],
  ['CURRENT', 'PREDISPATCHFCST', 'predispatchfcst_current'],
  ['CURRENT', 'SEVENDAYOUTLOOK_FULL', 'sevenday_full_current'],
  ['CURRENT', 'PDPASA', 'pdpasa_current'],
  ['CURRENT', 'Public_Prices', 'public_prices_current'],
  ['CURRENT', 'HistDemand', 'histdemand_current'],
  ['CURRENT', 'Next_Day_Intermittent_Gen_Scada', 'intermittent_current'],
  ['CURRENT', 'Vwa_Fcas_Prices', 'vwafcas_current'],
  ['ARCHIVE', 'ROOFTOP_PV', 'rooftop_archive'],
  ['ARCHIVE', 'Short_Term_PASA_Reports', 'stpasa_archive'],
];

const samples = [];
for (const [base, dir, label] of TARGETS) {
  const baseUrl = base === 'CURRENT'
    ? 'https://www.nemweb.com.au/Reports/CURRENT/'
    : 'https://www.nemweb.com.au/Reports/ARCHIVE/';
  const info = await listing(baseUrl, dir);
  const zips = info.items.filter((n) => /\.zip$/i.test(n)).sort();
  const newest = zips[zips.length - 1];
  const rec = { base, dir, label, status: info.status, zips: zips.length, newest };
  if (!newest) {
    console.log(`${label.padEnd(28)} ${base}/${dir}: NO ZIP (items=${info.items.length})`);
    samples.push(rec);
    await sleep(500);
    continue;
  }
  const dest = join(OUT, 'samples', label, newest);
  mkdirSync(join(OUT, 'samples', label), { recursive: true });
  if (existsSync(dest) && statSync(dest).size > 0) {
    rec.bytes = statSync(dest).size;
    rec.state = 'cached';
  } else {
    const r = await fetch(`${baseUrl}${encodeURIComponent(dir)}/${encodeURIComponent(newest)}`, { headers: HEADERS });
    if (!r.ok) {
      rec.state = `HTTP ${r.status}`;
    } else {
      const buf = Buffer.from(await r.arrayBuffer());
      writeFileSync(dest, buf);
      rec.bytes = buf.length;
      rec.state = 'downloaded';
    }
  }
  console.log(`${label.padEnd(28)} ${base}/${dir}: ${newest} ${rec.state} ${rec.bytes ?? 0} bytes`);
  samples.push(rec);
  await sleep(600);
}

writeFileSync(join(OUT, 'samples_manifest.json'), JSON.stringify(samples, null, 1), 'utf8');
console.log('\nwrote dir_probes.json and samples_manifest.json');
