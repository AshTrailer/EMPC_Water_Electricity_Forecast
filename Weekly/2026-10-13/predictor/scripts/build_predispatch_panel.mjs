// Extract the predispatch regional and interconnector tables from the week packs.
//
// A week pack is a zip of one report per run, and each report is itself a zip of
// one csv. Across five packs that is 7.9 GB of text, of which two tables matter,
// so the csv is scanned with a line walk rather than split, and only matching
// rows are parsed.
//
// PDREGION carries, for every origin and every thirty minute target, the
// published price, the regional demand, the dispatchable generation and the two
// semi scheduled availabilities. The dispatchable generation is the quantity the
// scheduled stack actually serves, so it is the column the stack has to be read
// at. PDINT carries the interconnector flow forecast with import and export
// limits.
//
// Writes research/verify/e09_pd_region.bin and e09_pd_int.bin, both float64.
//
// Usage: node build_predispatch_panel.mjs

import { existsSync, openSync, writeSync, closeSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { entryBuffer, listEntriesFromBuffer } from "./lib/zip_stream.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const PACK_DIR = join(ROOT, "AEMO_Data", "predispatch_weeks");
const OUT = join(ROOT, "Weekly", "2026-10-13", "research", "verify");

const PACKS = [
  "PUBLIC_PREDISPATCH_20260906_20260912.zip",
  "PUBLIC_PREDISPATCH_20260913_20260919.zip",
  "PUBLIC_PREDISPATCH_20260920_20260926.zip",
  "PUBLIC_PREDISPATCH_20260927_20261003.zip",
  "PUBLIC_PREDISPATCH_20261004_20261010.zip",
];

const REGION_CODE = new Map([["VIC1", 1], ["TAS1", 2], ["SA1", 3]]);
const IC_CODE = new Map();

const REGION_COLS = ["origin", "target", "region", "rrp", "demand", "dispatchable",
  "net_interchange", "ss_solar", "ss_wind"];
const INT_COLS = ["origin", "target", "interconnector", "mwflow", "import_limit", "export_limit"];

function stamp(s, at) {
  // "2026/09/06 00:30:00" possibly wrapped in quotes
  const q = s.charCodeAt(at) === 34 ? 1 : 0;
  return Date.UTC(
    Number(s.substr(at + q, 4)), Number(s.substr(at + q + 5, 2)) - 1, Number(s.substr(at + q + 8, 2)),
    Number(s.substr(at + q + 11, 2)), Number(s.substr(at + q + 14, 2)), Number(s.substr(at + q + 17, 2)),
  ) / 60000;
}

// Column positions within the values, read from the PDREGION header printed by
// probe_predispatch_tables: index into the D row is 4 + value index.
const R_ORIGIN = 4;
const R_TARGET = 7;
const R_REGION = 6;
const R_RRP = 8;
const R_DEMAND = 10;
const R_DISPATCHABLE = 11;
const R_NETINT = 13;
const R_SS_SOLAR = 4 + 111;
const R_SS_WIND = 4 + 112;

const I_ORIGIN = 4;
const I_TARGET = 7;
const I_IC = 6;
const I_FLOW = 8;
const I_IMPORT = 4 + 8;
const I_EXPORT = 4 + 9;

const regionRows = new Map();          // "origin|target|region" -> values
const intRows = new Map();             // "origin|target|ic" -> values
let members = 0;
let regionSeen = 0;
let intSeen = 0;
let interventionRows = 0;

const t0 = Date.now();
for (const packName of PACKS) {
  const path = join(PACK_DIR, packName);
  if (!existsSync(path)) { console.log(`${packName}: absent`); continue; }
  const pack = readFileSync(path);
  const membersList = listEntriesFromBuffer(pack);
  let done = 0;
  for (const member of membersList) {
    const inner = entryBuffer(pack, member);
    const files = listEntriesFromBuffer(inner);
    if (files.length === 0) continue;
    const text = entryBuffer(inner, files[0]).toString("latin1");
    let pos = 0;
    const len = text.length;
    while (pos < len) {
      const nl = text.indexOf("\n", pos);
      const end = nl < 0 ? len : nl;
      if (end - pos > 16 && text.charCodeAt(pos) === 68) {
        if (text.startsWith("D,PDREGION,", pos)) {
          const c = text.slice(pos, end).split(",");
          if (c.length > R_SS_WIND) {
            const intervention = c[c.length - 1];
            if (intervention === "1") interventionRows += 1;
            else {
              const region = c[R_REGION];
              const code = REGION_CODE.get(region);
              if (code) {
                const origin = stamp(c[R_ORIGIN], 0);
                const target = stamp(c[R_TARGET], 0);
                regionRows.set(`${origin}|${target}|${code}`, [
                  origin, target, code, Number(c[R_RRP]), Number(c[R_DEMAND]),
                  Number(c[R_DISPATCHABLE]), Number(c[R_NETINT]),
                  Number(c[R_SS_SOLAR]), Number(c[R_SS_WIND]),
                ]);
                regionSeen += 1;
              }
            }
          }
        } else if (text.startsWith("D,PDINT,", pos)) {
          const c = text.slice(pos, end).split(",");
          if (c.length > I_EXPORT) {
            const ic = c[I_IC];
            if (!IC_CODE.has(ic)) IC_CODE.set(ic, IC_CODE.size + 1);
            const origin = stamp(c[I_ORIGIN], 0);
            const target = stamp(c[I_TARGET], 0);
            const code = IC_CODE.get(ic);
            intRows.set(`${origin}|${target}|${code}`, [
              origin, target, code, Number(c[I_FLOW]), Number(c[I_IMPORT]), Number(c[I_EXPORT]),
            ]);
            intSeen += 1;
          }
        }
      }
      if (nl < 0) break;
      pos = nl + 1;
    }
    done += 1;
  }
  members += membersList.length;
  console.log(`${packName}: members ${membersList.length} region rows ${regionRows.size} int rows ${intRows.size} (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
}

function writeBin(name, cols, map) {
  const fd = openSync(join(OUT, name), "w");
  const buf = Buffer.allocUnsafe(8 * cols * 4000);
  let k = 0;
  let n = 0;
  for (const row of map.values()) {
    for (let i = 0; i < cols; i += 1) buf.writeDoubleLE(Number.isFinite(row[i]) ? row[i] : NaN, 8 * (k * cols + i));
    k += 1;
    n += 1;
    if (k === 4000) { writeSync(fd, buf.subarray(0, 8 * cols * k)); k = 0; }
  }
  if (k) writeSync(fd, buf.subarray(0, 8 * cols * k));
  closeSync(fd);
  return n;
}

const nRegion = writeBin("e09_pd_region.bin", REGION_COLS.length, regionRows);
const nInt = writeBin("e09_pd_int.bin", INT_COLS.length, intRows);

writeFileSync(join(OUT, "e09_pd_panel.json"), JSON.stringify({
  packs: PACKS.length,
  members,
  region_rows: nRegion,
  int_rows: nInt,
  region_cols: REGION_COLS,
  int_cols: INT_COLS,
  region_codes: Object.fromEntries(REGION_CODE),
  interconnector_codes: Object.fromEntries(IC_CODE),
  intervention_rows_dropped: interventionRows,
  note: "times are minutes since 1970; PDREGION values come from the report of the origin stamped in column 0",
}, null, 2), "utf8");

console.log(`\nregion rows ${nRegion}, interconnector rows ${nInt}`);
console.log(`interconnectors ${JSON.stringify(Object.fromEntries(IC_CODE))}`);
console.log(`dropped ${interventionRows} intervention rows`);
console.log(`wrote ${join(OUT, "e09_pd_region.bin")} and e09_pd_int.bin`);
