// Replicate the demand placement in Node and find out which cells cannot be
// filled, before trusting any R squared that came out of the MATLAB version.
//
// Usage: node probe_demand_availability.mjs

import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const path =
  "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\AEMO_Data\\window_60d_20260811_20261009_vic1\\predispatch_30min_VIC1.csv";
const EPOCH = Date.parse("2025-01-01T00:00:00");
const T0 = Date.parse("2026-08-11T00:00:00");
const lead = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
for (let v = 60; v <= 10980; v += 30) lead.push(v);
const NCOL = 79;

const rows = [];
const rl = createInterface({ input: createReadStream(path), crlfDelay: Infinity });
let first = true;
for await (const line of rl) {
  if (first) { first = false; continue; }
  const f = line.split(",");
  rows.push({ eff: Date.parse(f[0].replace(" ", "T")), tgt: Date.parse(f[2].replace(" ", "T")), dem: +f[6], pid: +f[3] });
}
const effList = [...new Set(rows.map((r) => r.eff))].sort((a, b) => a - b);
const runIndex = new Map(effList.map((e, i) => [e, i]));
const dem = new Map();
const maxPid = new Array(effList.length).fill(0);
for (const r of rows) {
  const k = runIndex.get(r.eff);
  const col = (r.tgt - r.eff) / 60000 / 30;
  dem.set(k * NCOL + col, r.dem);
  if (r.pid > maxPid[k]) maxPid[k] = r.pid;
}
console.log(`runs ${effList.length}, horizon in periods min ${Math.min(...maxPid)} max ${Math.max(...maxPid)}`);
const short = maxPid.filter((p) => p < 48).length;
console.log(`runs reaching less than 24 h: ${short} of ${effList.length}`);

// last run at or before a time
function runAt(ms) {
  let lo = 0, hi = effList.length - 1, best = -1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (effList[mid] <= ms) { best = mid; lo = mid + 1; } else hi = mid - 1;
  }
  return best;
}

const bandCols = [];
for (let j = 0; j < lead.length; j++) if (lead[j] >= 360 && lead[j] <= 1440) bandCols.push(j);

const avail = new Map();
const spreadByDay = [];
for (const j of bandCols) {
  let ok = 0, tot = 0;
  for (let d = 1; d <= 60; d++) {
    const vals = [];
    for (let s = 0; s < 288; s++) {
      const tgt = T0 + (d - 1) * 86400000 + s * 5 * 60000;
      const org = tgt - lead[j] * 60000;
      const k = runAt(org);
      tot++;
      if (k < 0) continue;
      const col = (tgt - effList[k]) / 60000 / 30;
      const c0 = Math.floor(col), fr = col - c0;
      const a = dem.get(k * NCOL + c0);
      if (a === undefined) continue;
      const b = dem.get(k * NCOL + c0 + 1);
      const v = b === undefined ? a : a + fr * (b - a);
      ok++;
      vals.push(v);
    }
    if (vals.length > 200) {
      const lo = Math.min(...vals), hi = Math.max(...vals);
      spreadByDay.push((hi - lo) / Math.abs(lo));
    }
  }
  avail.set(lead[j], { ok, tot, share: ok / tot });
}
console.log("\nlead  available");
for (const j of bandCols) {
  const a = avail.get(lead[j]);
  console.log(`  ${String(lead[j] / 60).padStart(5)} h  ${(100 * a.share).toFixed(1)}%  (${a.ok}/${a.tot})`);
}
const all = [...avail.values()].reduce((s, a) => s + a.ok, 0) / ([...avail.values()].reduce((s, a) => s + a.tot, 0));
console.log(`\nband coverage ${(100 * all).toFixed(2)}%`);
console.log(`within-slot spread across slots, median ${(100 * spreadByDay.sort((a, b) => a - b)[spreadByDay.length >> 1]).toFixed(2)}%`);

// one cell, traced end to end
const j = bandCols[12];
const tgt = T0 + 30 * 86400000 + 216 * 5 * 60000;
const org = tgt - lead[j] * 60000;
const k = runAt(org);
console.log(`\ntrace: slot 217 day 31 lead ${lead[j] / 60} h`);
console.log(`  target ${new Date(tgt).toISOString().slice(0, 16)}  origin ${new Date(org).toISOString().slice(0, 16)}`);
console.log(`  run ${new Date(effList[k]).toISOString().slice(0, 16)}  maxPid ${maxPid[k]}  horizon ${(maxPid[k] - 1) / 2} h`);
const col = (tgt - effList[k]) / 60000 / 30;
console.log(`  horizon needed ${col} columns (${col / 2} h)`);
