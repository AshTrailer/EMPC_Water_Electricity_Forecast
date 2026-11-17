// Is total_demand in the PREDISPATCH file really stable across the runs that
// forecast the same target? If it is not, the demand cube is being built from
// the wrong column and no downstream number means anything.
//
// Usage: node probe_demand_stability.mjs

import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const path =
  "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\AEMO_Data\\window_60d_20260811_20261009_vic1\\predispatch_30min_VIC1.csv";

const rl = createInterface({ input: createReadStream(path), crlfDelay: Infinity });
let header = null;
const rows = [];
for await (const line of rl) {
  if (header === null) {
    header = line.split(",");
    continue;
  }
  const f = line.split(",");
  rows.push({
    eff: f[0],
    tgt: f[2],
    pid: +f[3],
    rrp: +f[4],
    dem: +f[6],
    run: +f[7],
    file: f[9],
  });
}
console.log(`header: ${header.join(",")}`);
console.log(`rows: ${rows.length}`);

const effs = [...new Set(rows.map((r) => r.eff))].sort();
console.log(`distinct effective_time: ${effs.length}`);
const gaps = new Map();
for (let i = 1; i < effs.length; i++) {
  const d = (Date.parse(effs[i].replace(" ", "T")) - Date.parse(effs[i - 1].replace(" ", "T"))) / 60000;
  gaps.set(d, (gaps.get(d) || 0) + 1);
}
console.log(`effective_time spacing (minutes -> count): ${JSON.stringify([...gaps])}`);
console.log(`first ${effs[0]}  last ${effs[effs.length - 1]}`);

// one target seen from many runs
const byTgt = new Map();
for (const r of rows) {
  if (!byTgt.has(r.tgt)) byTgt.set(r.tgt, []);
  byTgt.get(r.tgt).push(r);
}
const multi = [...byTgt.entries()].filter(([, v]) => v.length > 8).sort((a, b) => a[1].length - b[1].length);
console.log(`targets seen by more than 8 runs: ${multi.length}`);

for (const probe of [multi[multi.length >> 1], multi[Math.floor(multi.length * 0.25)], multi[multi.length - 1]]) {
  const [tgt, v] = probe;
  const d = v.map((r) => r.dem);
  const span = ((Math.max(...d) - Math.min(...d)) / Math.min(...d)) * 100;
  console.log(`\ntarget ${tgt}: ${v.length} runs, demand ${Math.min(...d).toFixed(2)} to ${Math.max(...d).toFixed(2)} (span ${span.toFixed(2)}%)`);
  v.slice(0, 6).forEach((r) => console.log(`   eff ${r.eff} pid ${r.pid} dem ${r.dem} rrp ${r.rrp} run ${r.run}`));
  v.slice(-3).forEach((r) => console.log(`   eff ${r.eff} pid ${r.pid} dem ${r.dem} rrp ${r.rrp} run ${r.run}`));
}

// the horizon a run reaches, in 30-minute periods
const perRun = new Map();
for (const r of rows) {
  const k = r.eff;
  if (!perRun.has(k)) perRun.set(k, []);
  perRun.get(k).push(r.pid);
}
const sizes = [...perRun.values()].map((v) => Math.max(...v));
console.log(`\nperiods per run: min ${Math.min(...sizes)} max ${Math.max(...sizes)} median ${sizes.sort((a, b) => a - b)[sizes.length >> 1]}`);
