// How far ahead does one PREDISPATCH publication actually reach, and what does
// that leave available at the origin for each lead?
//
// Timestamps are compared as minutes from a fixed epoch built from the string
// parts, not through Date.parse: the host zone has daylight saving and two
// instants in the window collapse onto one millisecond, which silently merges
// two runs.
//
// Usage: node probe_demand_horizon.mjs

import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const path =
  "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\AEMO_Data\\window_60d_20260811_20261009_vic1\\predispatch_30min_VIC1.csv";
const lead = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
for (let v = 60; v <= 10980; v += 30) lead.push(v);
const NCOL = 79;

const toMin = (s) => {
  const [d, t] = s.split(" ");
  const [y, mo, da] = d.split("-").map(Number);
  const [h, mi, se] = t.split(":").map(Number);
  return Date.UTC(y, mo - 1, da, h, mi, se) / 60000;
};

const rows = [];
const rl = createInterface({ input: createReadStream(path), crlfDelay: Infinity });
let first = true;
for await (const line of rl) {
  if (first) { first = false; continue; }
  const f = line.split(",");
  rows.push({ eff: toMin(f[0]), tgt: toMin(f[2]), dem: +f[6], pid: +f[3] });
}
const effMin = [...new Set(rows.map((r) => r.eff))].sort((a, b) => a - b);
const idx = new Map(effMin.map((e, i) => [e, i]));
const dem = new Map();
const maxPid = new Array(effMin.length).fill(0);
for (const r of rows) {
  const k = idx.get(r.eff);
  dem.set(k * NCOL + (r.tgt - r.eff) / 30, r.dem);
  if (r.pid > maxPid[k]) maxPid[k] = r.pid;
}
console.log(`runs ${effMin.length}`);

const T0 = toMin("2026-08-11 00:00:00");
const hod = (m) => ((m - T0) % 1440 + 1440) % 1440;
const byHour = new Map();
for (let k = 0; k < effMin.length; k++) {
  const h = Math.floor(hod(effMin[k]) / 60);
  if (!byHour.has(h)) byHour.set(h, []);
  byHour.get(h).push(maxPid[k]);
}
console.log("\nhour of day  runs  horizon periods min/median/max   last target hour of day");
for (const h of [...byHour.keys()].sort((a, b) => a - b)) {
  const v = byHour.get(h).sort((a, b) => a - b);
  const lastTgt = ((h * 60 + 30 * (v[v.length >> 1] - 1)) % 1440) / 60;
  console.log(`  ${String(h).padStart(2)}       ${String(v.length).padStart(4)}   ${String(v[0]).padStart(3)} / ${String(v[v.length >> 1]).padStart(3)} / ${String(v[v.length - 1]).padStart(3)}            ${lastTgt.toFixed(1)}`);
}

function runAt(ms) {
  let lo = 0, hi = effMin.length - 1, best = -1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (effMin[mid] <= ms) { best = mid; lo = mid + 1; } else hi = mid - 1;
  }
  return best;
}

const band = [];
for (let j = 0; j < lead.length; j++) if (lead[j] >= 360 && lead[j] <= 1440) band.push(j);
const stat = new Map();
for (const j of band) {
  let strict = 0, loose = 0, tot = 0;
  for (let d = 1; d <= 60; d++) {
    for (let s = 0; s < 288; s++) {
      const tgt = T0 + (d - 1) * 1440 + s * 5;
      const org = tgt - lead[j];
      const k = runAt(org);
      tot++;
      if (k < 0) continue;
      const colf = (tgt - effMin[k]) / 30;
      const c0 = Math.floor(colf), fr = colf - c0;
      const a = dem.get(k * NCOL + c0);
      if (a === undefined) continue;
      const b = dem.get(k * NCOL + c0 + 1);
      if (fr === 0 || b !== undefined) { strict++; loose++; }
      else loose++;
    }
  }
  stat.set(lead[j], { strict, loose, tot });
}
console.log("\nlead    with next column   with fallback to base");
for (const j of band) {
  const a = stat.get(lead[j]);
  console.log(`  ${String(lead[j] / 60).padStart(5)} h   ${(100 * a.strict / a.tot).toFixed(1).padStart(6)}%   ${(100 * a.loose / a.tot).toFixed(1).padStart(6)}%`);
}
const s = [...stat.values()];
console.log(`\nband mean  strict ${(100 * s.reduce((x, a) => x + a.strict, 0) / s.reduce((x, a) => x + a.tot, 0)).toFixed(2)}%   with fallback ${(100 * s.reduce((x, a) => x + a.loose, 0) / s.reduce((x, a) => x + a.tot, 0)).toFixed(2)}%`);
