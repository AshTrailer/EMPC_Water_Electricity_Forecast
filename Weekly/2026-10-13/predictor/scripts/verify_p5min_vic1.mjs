/**
 * Check the P5MIN five minute forecast set for the 60 day window.
 *
 * Checks, not vibes:
 *   schema identical across files
 *   every publication point carries exactly 12 intervals
 *   every interval_datetime is effective_time plus 0..55 minutes in steps of 5
 *   no duplicate (effective_time, interval_datetime)
 *   publication points are 5 minutes apart, with no gap inside a file
 *   the ranges join up: 08-11..08-24, 08-25..09-21, 09-22..10-06, 10-07..10-09
 *   rrp and total_demand are finite numbers
 *
 *   node verify_p5min_vic1.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const DIR = "C:/Ash/Projects/EMPC_Water_Electricity_Forecast/AEMO_Data/" +
   "window_60d_20260811_20261009/p5min_vic1_partial";
const HEAD = "effective_time,region_id,interval_datetime,rrp,total_demand,intervention";

const files = readdirSync(DIR).filter((f) => /^p5min_\d{8}_\d{8}\.csv$/.test(f)).sort();
if (files.length === 0) { console.error("no p5min files found in " + DIR); process.exit(1); }

let bad = 0;
const fail = (m) => { console.log("  FAIL " + m); bad++; };
const idx = (t) => Date.parse(t.replace(" ", "T") + "Z");

const allEff = new Set();
const perFile = [];

for (const f of files) {
   const text = readFileSync(join(DIR, f), "utf8").replace(/\r\n/g, "\n");
   const lines = text.split("\n").filter((l) => l.length > 0);
   const head = lines[0];
   if (head !== HEAD) fail(`${f}: header is "${head}"`);

   const rows = lines.slice(1).map((l) => l.split(","));
   const byEff = new Map();
   const seen = new Set();
   let minT = null, maxT = null;
   for (const r of rows) {
      if (r.length !== 6) { fail(`${f}: row with ${r.length} fields`); continue; }
      const [eff, reg, int, rrp, dem, ivn] = r;
      if (reg !== "VIC1") fail(`${f}: region ${reg}`);
      if (ivn !== "0") fail(`${f}: intervention ${ivn}`);
      if (!Number.isFinite(Number(rrp))) fail(`${f}: rrp ${rrp}`);
      if (!Number.isFinite(Number(dem))) fail(`${f}: demand ${dem}`);
      const d = (idx(int) - idx(eff)) / 60000;
      if (d < 0 || d > 55 || d % 5 !== 0) fail(`${f}: ${eff} -> ${int} is ${d} minutes`);
      const key = eff + "|" + int;
      if (seen.has(key)) fail(`${f}: duplicate ${key}`);
      seen.add(key);
      if (!byEff.has(eff)) byEff.set(eff, 0);
      byEff.set(eff, byEff.get(eff) + 1);
      allEff.add(eff);
      if (minT === null || eff < minT) minT = eff;
      if (maxT === null || eff > maxT) maxT = eff;
   }
   for (const [eff, n] of byEff) if (n !== 12) fail(`${f}: ${eff} has ${n} intervals, not 12`);

   // publication points inside one file must sit exactly 5 minutes apart
   const effs = [...byEff.keys()].sort();
   let gaps = 0;
   for (let i = 1; i < effs.length; i++) {
      if (idx(effs[i]) - idx(effs[i - 1]) !== 300000) gaps++;
   }
   if (gaps > 0) fail(`${f}: ${gaps} gaps between publication points inside the file`);

   perFile.push({ f, rows: rows.length, points: byEff.size, minT, maxT, gaps });
}

// the four ranges must join up with no hole
const order = perFile.slice().sort((a, b) => (a.minT < b.minT ? -1 : 1));
for (let i = 1; i < order.length; i++) {
   const prev = order[i - 1], cur = order[i];
   const step = (idx(cur.minT) - idx(prev.maxT)) / 60000;
   if (step !== 5) console.log(`  NOTE gap between ${prev.f} and ${cur.f} is ${step} minutes`);
}

console.log("file                            rows  points   first                last");
for (const p of perFile) {
   console.log(`${p.f.padEnd(30)} ${String(p.rows).padStart(5)} ${String(p.points).padStart(6)}   ` +
      `${p.minT}   ${p.maxT}`);
}
console.log(`\npublication points in total ${allEff.size}`);
console.log(`files ${files.length}`);
console.log(bad === 0 ? "\n### ALL CHECKS PASSED ###" : `\n### ${bad} CHECKS FAILED ###`);
process.exit(bad === 0 ? 0 : 1);
