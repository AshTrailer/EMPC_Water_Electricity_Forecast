/**
 * Merge the P5MIN parts for the 60 day window into one canonical file.
 *
 * The two files left by the earlier round overlap: p5min_20260922_20261006.csv
 * actually starts on 2026-08-25 and therefore contains p5min_20260825_20260921.csv
 * whole. Merging on (effective_time, interval_datetime) removes the duplication,
 * and any key whose values disagree between parts is reported rather than
 * silently resolved.
 *
 *   node merge_p5min_vic1.mjs            dry run, reports only
 *   node merge_p5min_vic1.mjs --apply    writes the merged file and removes parts
 */
import { readFileSync, writeFileSync, readdirSync, unlinkSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const DIR = "C:/Ash/Projects/EMPC_Water_Electricity_Forecast/AEMO_Data/" +
   "window_60d_20260811_20261009/p5min_vic1_partial";
const OUT = join(DIR, "p5min_20260811_20261009.csv");
const HEAD = "effective_time,region_id,interval_datetime,rrp,total_demand,intervention";
const apply = process.argv.includes("--apply");

const files = readdirSync(DIR).filter((f) => /^p5min_\d{8}_\d{8}\.csv$/.test(f)).sort();
if (files.length === 0) { console.error("nothing to merge"); process.exit(1); }

const idx = (t) => Date.parse(t.replace(" ", "T") + "Z");
const byKey = new Map();
let read = 0, clash = 0;
const clashSamples = [];

for (const f of files) {
   const lines = readFileSync(join(DIR, f), "utf8").replace(/\r\n/g, "\n").split("\n");
   if (lines[0] !== HEAD) { console.error(`${f}: unexpected header`); process.exit(1); }
   for (const l of lines.slice(1)) {
      if (!l) continue;
      const r = l.split(",");
      if (r.length !== 6) { console.error(`${f}: bad row ${l}`); process.exit(1); }
      const key = r[0] + "|" + r[2];
      read++;
      const prev = byKey.get(key);
      if (prev === undefined) { byKey.set(key, r); continue; }
      if (prev[3] !== r[3] || prev[4] !== r[4]) {
         clash++;
         if (clashSamples.length < 5) clashSamples.push({ key, a: prev.slice(3), b: r.slice(3) });
      }
   }
}

const rows = [...byKey.values()].sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 :
   (idx(a[2]) - idx(b[2]))));

// structure checks on the merged set
const perEff = new Map();
for (const r of rows) perEff.set(r[0], (perEff.get(r[0]) || 0) + 1);
const short = [...perEff.entries()].filter(([, n]) => n !== 12);
const effs = [...perEff.keys()].sort();
let gaps = [];
for (let i = 1; i < effs.length; i++) {
   const step = (idx(effs[i]) - idx(effs[i - 1])) / 60000;
   if (step !== 5) gaps.push(`${effs[i - 1]} -> ${effs[i]} is ${step} min`);
}

console.log(`parts            ${files.length}: ${files.join(" ")}`);
console.log(`rows read        ${read}`);
console.log(`unique keys      ${byKey.size}`);
console.log(`duplicate rows   ${read - byKey.size}`);
console.log(`value clashes    ${clash}`);
for (const c of clashSamples) console.log(`   ${c.key}  ${c.a} vs ${c.b}`);
console.log(`publication pts  ${effs.length}`);
console.log(`first            ${effs[0]}`);
console.log(`last             ${effs[effs.length - 1]}`);
console.log(`points not 12    ${short.length}${short.length ? " " + JSON.stringify(short.slice(0, 5)) : ""}`);
console.log(`gaps             ${gaps.length}${gaps.length ? " " + gaps.slice(0, 5).join(" | ") : ""}`);

const ok = clash === 0 && short.length === 0 && gaps.length === 0;
if (!ok) { console.log("\nNOT MERGING: the checks above must be clean first."); process.exit(1); }
if (!apply) { console.log(`\nwould write ${OUT} with ${rows.length} rows`); process.exit(0); }

mkdirSync(DIR, { recursive: true });
writeFileSync(OUT, HEAD + "\n" + rows.map((r) => r.join(",")).join("\n") + "\n", "utf8");
for (const f of files) {
   if (join(DIR, f) === OUT) continue;
   unlinkSync(join(DIR, f));
}
console.log(`\nwrote ${OUT}`);
console.log(`removed ${files.length} part files, kept only the merged one`);
