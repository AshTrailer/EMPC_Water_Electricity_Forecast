// Sweep every NEMWEB CURRENT report directory, peek at one sample, and record the
// tables and columns each product actually carries. Read-only.
import { writeFileSync } from 'node:fs';
import { extractZip } from './nemweb_peek.mjs';

const OUTDIR = 'C:\\Ash\\_research_20261013\\sweep';
const MAXBYTES = Number(process.env.SWEEP_MAXBYTES || 12 * 1024 * 1024);

const listing = await (await fetch('https://www.nemweb.com.au/Reports/CURRENT/', { headers: { 'User-Agent': 'Mozilla/5.0' } })).text();
const dirs = [...new Set([...listing.matchAll(/HREF="\/Reports\/CURRENT\/([^"\/]+)\/?"/gi)].map(m => m[1]))].sort();
console.log(`directories: ${dirs.length}`);

const results = [];
for (const d of dirs) {
  const base = `https://www.nemweb.com.au/Reports/CURRENT/${d}/`;
  const rec = { dir: d, status: '', files: 0, newest: '', bytes: 0, entries: 0, tables: [] };
  try {
    const html = await (await fetch(base, { headers: { 'User-Agent': 'Mozilla/5.0' } })).text();
    const hrefs = [...html.matchAll(/<A HREF="([^"]+)"[^>]*>([^<]*)<\/A>/gi)]
      .map(m => m[1]).filter(h => !h.endsWith('/') && !h.includes('DUPLICATE'));
    rec.files = hrefs.length;
    if (!hrefs.length) { rec.status = 'no files'; results.push(rec); continue; }
    rec.newest = hrefs[hrefs.length - 1];
    const url = `https://www.nemweb.com.au${rec.newest}`;
    const head = await fetch(url, { method: 'HEAD', headers: { 'User-Agent': 'Mozilla/5.0' } });
    rec.bytes = Number(head.headers.get('content-length') || 0);
    if (rec.bytes > MAXBYTES) { rec.status = `skipped ${(rec.bytes / 1048576).toFixed(1)} MB`; results.push(rec); continue; }
    const buf = Buffer.from(await (await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } })).arrayBuffer());
    let entries = extractZip(buf);
    // nested packages: descend one level
    if (entries.length && /\.zip$/i.test(entries[0].name)) entries = extractZip(entries[0].data);
    rec.entries = entries.length;
    const csv = entries.find(e => /\.csv$/i.test(e.name)) || entries[0];
    const seen = new Map();
    for (const line of csv.data.toString('utf8').split(/\r?\n/)) {
      if (line[0] !== 'I') continue;
      const f = line.split(',');
      const key = `${f[1]}|${f[2]}`;
      if (!seen.has(key)) seen.set(key, f.slice(4).map(s => s.replace(/^"|"$/g, '')));
    }
    rec.tables = [...seen.entries()].map(([k, cols]) => ({ table: k, cols }));
    rec.status = 'ok';
  } catch (e) {
    rec.status = `ERROR ${String(e.message).slice(0, 60)}`;
  }
  const flat = rec.tables.flatMap(t => t.cols.map(c => `${t.table}:${c}`));
  const hit = (re) => flat.filter(s => re.test(s)).slice(0, 10);
  rec.price = hit(/RRP|PRICE|PREDICT/i);
  rec.ahead = hit(/INTERVAL_DATETIME|DATETIME|PERIODID|TRADINGDATE|SETTLEMENTDATE/i);
  rec.fund = hit(/UIGF|SOLAR|WIND|SEMISCHED|DEMAND|AVAILAB|INTERMITTENT|STORAGE/i);
  console.log(`${d.padEnd(34)} ${String(rec.files).padStart(5)} files  ${(rec.bytes / 1024).toFixed(0).padStart(6)} KB  tables ${rec.tables.length}  ${rec.status}`);
  results.push(rec);
}
writeFileSync(`${OUTDIR}\\sweep.json`, JSON.stringify(results, null, 1), 'utf8');

const withPrice = results.filter(r => r.price && r.price.length);
console.log(`\n=== products whose sample carries a price-like column: ${withPrice.length} ===`);
for (const r of withPrice) {
  console.log(`\n${r.dir}   (${r.files} files, newest ${r.newest}, ${(r.bytes / 1024).toFixed(0)} KB)`);
  console.log(`  price cols : ${r.price.join(' | ')}`);
  console.log(`  fund  cols : ${r.fund.join(' | ')}`);
  for (const t of r.tables) console.log(`    ${t.table}  (${t.cols.length} cols)`);
}
