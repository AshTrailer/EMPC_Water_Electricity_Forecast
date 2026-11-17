// Decide the P5MIN timestamp convention with a two-dimensional test.
//
// For every run, row j (j = 0..55 minutes past the effective time) is compared
// against the actual price sample at effective time plus l, for every l in the
// same range. If the row timestamp is the END of the interval the row describes,
// the smallest error sits on the diagonal j = l. If it is the START, the row
// describes the interval one step later, so the smallest error sits on l = j + 5.
//
// Usage: node probe_p5min_phase.mjs

import { readFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const AEMO = join(ROOT, "AEMO_Data");
const W60 = join(AEMO, "window_60d_20260811_20261009");

function readCsv(path) {
  const lines = readFileSync(path, "latin1").split(/\r?\n/).filter((l) => l.length > 0);
  const head = lines[0].split(",");
  return lines.slice(1).map((l) => {
    const c = l.split(",");
    const o = {};
    for (let i = 0; i < head.length; i += 1) o[head[i]] = c[i];
    return o;
  });
}
function shift(stamp, minutes) {
  const d = new Date(`${stamp.replace(" ", "T")}Z`);
  d.setUTCMinutes(d.getUTCMinutes() + minutes);
  return d.toISOString().slice(0, 19).replace("T", " ");
}

const price = new Map();
for (const mon of ["202608", "202609", "202610"]) {
  for (const r of readCsv(join(AEMO, `PRICE_AND_DEMAND_${mon}_VIC1.csv`))) {
    if (r.REGION === "VIC1") price.set(r.SETTLEMENTDATE.replace(/\//g, "-"), Number(r.RRP));
  }
}

const rows = readCsv(join(W60, "p5min_vic1_partial", "p5min_20260811_20261009.csv"));
const run = new Map();
for (const r of rows) {
  if (r.region_id !== "VIC1") continue;
  if (!run.has(r.effective_time)) run.set(r.effective_time, new Map());
  run.get(r.effective_time).set(r.interval_datetime, Number(r.rrp));
}

const OFF = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
const n = new Map(), s = new Map();
for (const [eff, mp] of run) {
  for (const j of OFF) {
    const pred = mp.get(shift(eff, j));
    if (pred === undefined) continue;
    for (const l of OFF) {
      const act = price.get(shift(eff, l));
      if (act === undefined) continue;
      const k = `${j}|${l}`;
      n.set(k, (n.get(k) || 0) + 1);
      s.set(k, (s.get(k) || 0) + (pred - act) ** 2);
    }
  }
}

const rmse = (j, l) => {
  const k = `${j}|${l}`;
  const c = n.get(k) || 0;
  return c === 0 ? NaN : Math.sqrt(s.get(k) / c);
};

console.log("RMSE by (row offset j, actual offset l), P5MIN against VIC1 actual");
console.log("j\\l " + OFF.map((l) => String(l).padStart(8)).join(""));
for (const j of OFF) {
  console.log(String(j).padStart(3) + " " + OFF.map((l) => {
    const v = rmse(j, l);
    return (Number.isNaN(v) ? "n/a" : v.toFixed(2)).padStart(8);
  }).join(""));
}

console.log("\nbest actual offset for each row offset");
for (const j of OFF) {
  let best = null;
  for (const l of OFF) {
    const v = rmse(j, l);
    if (!Number.isNaN(v) && (best === null || v < best.v)) best = { l, v };
  }
  console.log(`  row ${String(j).padStart(2)} min -> best actual offset ${String(best.l).padStart(2)} min, RMSE ${best.v.toFixed(3)}`);
}

console.log("\npaired comparison at every (row offset, actual offset)");
let diag = 0, plus = 0;
for (const j of OFF) {
  const a = rmse(j, j), b = rmse(j, j + 5);
  if (Number.isNaN(a) || Number.isNaN(b)) continue;
  if (a < b) diag += 1; else plus += 1;
  console.log(`  row ${String(j).padStart(2)}: rmse at l=j ${a.toFixed(3)}  at l=j+5 ${Number.isNaN(b) ? "n/a" : b.toFixed(3)}`);
}
console.log(`diagonal wins ${diag}, plus-five wins ${plus}`);
