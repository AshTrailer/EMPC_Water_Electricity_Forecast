// 01: Enumerate EVERY subdirectory of NEMWEB Reports/CURRENT/ and, for each,
// record whether it holds data, how many files, and the newest file.
//
// Fetching is HTTPS via Node's global fetch, as required.
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const OUT = 'C:\\Ash\\_research_20261013\\nemweb';
const ROOT = 'https://www.nemweb.com.au/Reports/CURRENT/';
const HEADERS = { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-research/1.0' };

mkdirSync(OUT, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const rootHtml = await (await fetch(ROOT, { headers: HEADERS })).text();
const allHrefs = [...rootHtml.matchAll(/href="([^"]+)"/gi)].map((m) => m[1]);
// the IIS listing writes subdirectories WITHOUT a trailing slash, e.g.
//   /Reports/CURRENT/DispatchIS_Reports
// so keep every href under /Reports/CURRENT/ that is not a file and not the
// parent link, then take the first path segment as the directory name.
const dirs = [...new Set(allHrefs
  .filter((h) => /^\/Reports\/CURRENT\/[^/]+$/i.test(h))
  .map((h) => h.split('/').pop()))]
  .filter((d) => d && !/\.(zip|csv|txt|json|xml|html?)$/i.test(d))
  .sort();

console.log(`CURRENT root hrefs: ${allHrefs.length}, distinct subdirectories: ${dirs.length}`);
console.log(`root html bytes: ${rootHtml.length}`);

const rows = [];
for (const d of dirs) {
  const url = `${ROOT}${encodeURIComponent(d)}/`;
  let status = 0;
  let files = [];
  try {
    const r = await fetch(url, { headers: HEADERS });
    status = r.status;
    const html = await r.text();
    files = [...html.matchAll(/href="([^"]+)"/gi)].map((m) => m[1])
      .map((h) => h.split('/').pop())
      .filter((n) => n && !n.startsWith('?') && n !== '../' && n !== '..');
  } catch (e) {
    rows.push({ dir: d, status: -1, error: e.message, n: 0 });
    console.log(`${d.padEnd(40)} ERROR ${e.message}`);
    await sleep(400);
    continue;
  }
  const zips = files.filter((f) => /\.zip$/i.test(f));
  const csvs = files.filter((f) => /\.csv$/i.test(f));
  const newest = zips.length ? zips.slice().sort().slice(-1)[0] : null;
  const oldest = zips.length ? zips.slice().sort()[0] : null;
  rows.push({ dir: d, status, n: zips.length, n_csv: csvs.length, oldest, newest,
              hasData: zips.length > 0 });
  console.log(`${d.padEnd(40)} status=${status} zips=${String(zips.length).padStart(5)} csv=${String(csvs.length).padStart(4)} newest=${newest ?? '-'}`);
  await sleep(400);
}

writeFileSync(join(OUT, 'current_dirs.json'),
  JSON.stringify({ root: ROOT, fetched_at: new Date().toISOString(), dirs: rows }, null, 1),
  'utf8');

const withData = rows.filter((r) => r.hasData).length;
console.log('');
console.log(`dirs enumerated: ${rows.length}, with data: ${withData}, empty: ${rows.length - withData}`);
console.log('wrote current_dirs.json');
