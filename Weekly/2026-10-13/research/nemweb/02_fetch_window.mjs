// 02: Download EVERY PREDISPATCHIS and PREDISPATCH report whose effective stamp
// falls in the requested NEM-time window.
//
// Window: 2026-10-12 00:00 .. 2026-10-13 03:00 NEM => effective stamps
// 202610120000 .. 202610130300 inclusive.
//
// HTTPS via Node global fetch. Resumable: existing non-empty files are skipped.
import { writeFileSync, mkdirSync, existsSync, statSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const OUT = 'C:\\Ash\\_research_20261013\\nemweb';
const ROOT = 'https://www.nemweb.com.au/Reports/CURRENT/';
const HEADERS = { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-research/1.0' };
const FROM = '202610120000';
const TO = '202610130300';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const JOBS = [
  { dir: 'PredispatchIS_Reports', prefix: 'PUBLIC_PREDISPATCHIS_', out: 'predispatchis' },
  { dir: 'Predispatch_Reports', prefix: 'PUBLIC_PREDISPATCH_', out: 'predispatch' },
];

const summary = {};

for (const job of JOBS) {
  const listingHtml = await (await fetch(`${ROOT}${job.dir}/`, { headers: HEADERS })).text();
  const all = [...listingHtml.matchAll(/href="([^"]+\.zip)"/gi)]
    .map((m) => m[1].split('/').pop());
  // the effective stamp is the first 12-digit field after the product prefix
  const picked = [];
  for (const n of all) {
    if (!n.toUpperCase().startsWith(job.prefix)) continue;
    const rest = n.slice(job.prefix.length);
    const m = rest.match(/^(\d{12})/);
    if (!m) continue;
    const eff = m[1];
    if (eff >= FROM && eff <= TO) picked.push({ name: n, eff });
  }
  picked.sort((a, b) => (a.eff < b.eff ? -1 : a.eff > b.eff ? 1 : 0));
  console.log(`\n=== ${job.dir}: ${all.length} zips listed, ${picked.length} inside [${FROM}, ${TO}]`);
  console.log(`    first eff=${picked[0]?.eff ?? '-'}  last eff=${picked[picked.length - 1]?.eff ?? '-'}`);

  const dir = join(OUT, job.out);
  mkdirSync(dir, { recursive: true });
  let downloaded = 0, cached = 0, failed = 0, bytes = 0;
  const manifest = [];

  for (const item of picked) {
    const dest = join(dir, item.name);
    if (existsSync(dest) && statSync(dest).size > 0) {
      cached += 1;
      bytes += statSync(dest).size;
      manifest.push({ ...item, bytes: statSync(dest).size, status: 'cached' });
      continue;
    }
    try {
      const r = await fetch(`${ROOT}${job.dir}/${encodeURIComponent(item.name)}`, { headers: HEADERS });
      if (!r.ok) {
        console.log(`  ${item.name} HTTP ${r.status}`);
        failed += 1;
        manifest.push({ ...item, status: `HTTP ${r.status}` });
        continue;
      }
      const buf = Buffer.from(await r.arrayBuffer());
      writeFileSync(dest, buf);
      downloaded += 1;
      bytes += buf.length;
      manifest.push({ ...item, bytes: buf.length, status: 'downloaded' });
    } catch (e) {
      console.log(`  ${item.name} ERROR ${e.message}`);
      failed += 1;
      manifest.push({ ...item, status: `ERROR ${e.message}` });
    }
    await sleep(700);
  }

  writeFileSync(join(OUT, `manifest_${job.out}.json`),
    JSON.stringify({ dir: job.dir, from: FROM, to: TO, listed: all.length,
                     picked: picked.length, manifest }, null, 1), 'utf8');
  summary[job.out] = { listed: all.length, picked: picked.length, downloaded,
                       cached, failed, bytes };
  console.log(`    downloaded=${downloaded} cached=${cached} failed=${failed} bytes=${bytes} (${(bytes / 1e6).toFixed(1)} MB)`);
}

// what is the newest effective stamp actually available right now?
const now = new Date();
console.log(`\nfetch finished at ${now.toISOString()}`);
for (const job of JOBS) {
  const listingHtml = await (await fetch(`${ROOT}${job.dir}/`, { headers: HEADERS })).text();
  const stamps = [...listingHtml.matchAll(/href="([^"]+\.zip)"/gi)]
    .map((m) => m[1].split('/').pop())
    .filter((n) => n.toUpperCase().startsWith(job.prefix))
    .map((n) => (n.slice(job.prefix.length).match(/^(\d{12})/) || [])[1])
    .filter(Boolean).sort();
  console.log(`${job.dir}: newest effective stamp now = ${stamps[stamps.length - 1]} (of ${stamps.length})`);
  await sleep(400);
}
writeFileSync(join(OUT, 'fetch_summary.json'), JSON.stringify(summary, null, 1), 'utf8');
