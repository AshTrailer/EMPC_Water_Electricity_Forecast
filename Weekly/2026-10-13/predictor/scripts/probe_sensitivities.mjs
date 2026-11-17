// Probe how PREDISPATCH_SENSITIVITIES is published: CURRENT cadence, ARCHIVE
// packing, and what one file actually contains.
//
// E02 needs one file per dispatch run across 2026-08-11 to 2026-10-09, which is
// 2880 runs if the product is per-run. Whether that is 2880 requests or a dozen
// month packs decides the cost of the channel, so it is measured first.
//
// Usage: node probe_sensitivities.mjs [--get]

import { writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const OUT = join(ROOT, "AEMO_Data", "_probe_sens");
const BASE = "https://nemweb.com.au/Reports";
const want = process.argv.includes("--get");

if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });

const dirs = [
  `${BASE}/CURRENT/Predispatch_Sensitivities/`,
  `${BASE}/ARCHIVE/Predispatch_Sensitivities/`,
  `${BASE}/CURRENT/Predispatch_Sensitivities/`.replace("CURRENT", "ARCHIVE"),
];

const seen = new Set();
const report = {};
for (const dir of dirs) {
  if (seen.has(dir)) continue;
  seen.add(dir);
  let html;
  try {
    const r = await fetch(dir);
    if (!r.ok) {
      console.log(`${dir} -> HTTP ${r.status}`);
      continue;
    }
    html = await r.text();
  } catch (e) {
    console.log(`${dir} -> ${e.message}`);
    continue;
  }
  const zips = [...new Set(html.match(/[A-Za-z0-9_.-]+\.zip/g) || [])].sort();
  console.log(`\n${dir}`);
  console.log(`  ${zips.length} zip links`);
  if (zips.length) {
    console.log(`  first ${zips[0]}`);
    console.log(`  last  ${zips[zips.length - 1]}`);
    const byMonth = {};
    for (const z of zips) {
      const m = (z.match(/_(\d{8})/) || [])[1];
      if (!m) continue;
      const key = m.slice(0, 6);
      byMonth[key] = (byMonth[key] || 0) + 1;
    }
    console.log(`  per month: ${JSON.stringify(byMonth)}`);
    report[dir] = { n: zips.length, first: zips[0], last: zips[zips.length - 1] };
    if (want && dir.includes("CURRENT")) {
      const target = zips[zips.length - 1];
      const path = join(OUT, target);
      if (!existsSync(path)) {
        const rr = await fetch(dir + target);
        const buf = Buffer.from(await rr.arrayBuffer());
        writeFileSync(path, buf);
        console.log(`  wrote ${path}, ${buf.length} bytes`);
      } else {
        console.log(`  already have ${path}`);
      }
    }
  }
}
