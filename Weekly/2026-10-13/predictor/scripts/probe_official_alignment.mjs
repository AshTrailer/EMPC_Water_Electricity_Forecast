// Probe the timestamp convention of the three official AEMO forecast products
// against the actual 5-minute price used by the atlas.
//
// The question: an official row stamped T. Does it describe the price interval
// ENDING at T, or the one ending one step later?
//
// The test is paired on the target interval. For one target actual sample A we
// take two candidate rows from the same run and compare both against actual(A):
//   END    the row stamped A
//   START  the row stamped A minus one step
// Whichever candidate the product actually generated for A wins.
//
// Usage: node probe_official_alignment.mjs

import { readFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const AEMO = join(ROOT, "AEMO_Data");
const W60 = join(AEMO, "window_60d_20260811_20261009");

function readCsv(path) {
  const txt = readFileSync(path, "latin1");
  const lines = txt.split(/\r?\n/).filter((l) => l.length > 0);
  const head = lines[0].split(",");
  return lines.slice(1).map((l) => {
    const c = l.split(",");
    const o = {};
    for (let i = 0; i < head.length; i += 1) o[head[i]] = c[i];
    return o;
  });
}

function shift(stamp, minutes) {
  const d = new Date(`${stamp.replace(" ", "T")}Z`);       // NEM time read as UTC
  d.setUTCMinutes(d.getUTCMinutes() + minutes);
  return d.toISOString().slice(0, 19).replace("T", " ");
}

// ---- actual price, 5-minute grid, keyed by SETTLEMENTDATE ----------------
const price = new Map();
for (const mon of ["202608", "202609", "202610"]) {
  for (const r of readCsv(join(AEMO, `PRICE_AND_DEMAND_${mon}_VIC1.csv`))) {
    if (r.REGION !== "VIC1") continue;
    price.set(r.SETTLEMENTDATE.replace(/\//g, "-"), Number(r.RRP));
  }
}
console.log(`actual price points in window ${price.size}`);

function stats(pairs) {
  if (pairs.length === 0) return null;
  let s = 0, b = 0;
  for (const [pred, act] of pairs) { s += (pred - act) ** 2; b += pred - act; }
  return { n: pairs.length, rmse: Math.sqrt(s / pairs.length), bias: b / pairs.length };
}

function line(tag, pEnd, pStart) {
  const e = stats(pEnd), s = stats(pStart);
  const fmt = (x) => (x === null ? "n/a" : `${x.rmse.toFixed(3)} (bias ${x.bias.toFixed(3)}, n ${x.n})`);
  console.log(`${tag.padEnd(30)} row@A ${fmt(e)}   row@A-step ${fmt(s)}`);
}

// ---- P5MIN ---------------------------------------------------------------
// Row offsets inside a run are 0..55 minutes. Take the row at offset k from the
// run at eff = A - k, so both hypotheses compare the same run and the same lead.
const p5 = readCsv(join(W60, "p5min_vic1_partial", "p5min_20260811_20261009.csv"));
const p5run = new Map();
for (const r of p5) {
  if (r.region_id !== "VIC1") continue;
  if (!p5run.has(r.effective_time)) p5run.set(r.effective_time, new Map());
  p5run.get(r.effective_time).set(r.interval_datetime, Number(r.rrp));
}
console.log(`p5min runs ${p5run.size}`);
for (const k of [5, 30, 55]) {
  const pEnd = [], pStart = [];
  for (const [eff, rows] of p5run) {
    const A = shift(eff, k);
    const act = price.get(A);
    if (act === undefined) continue;
    const rEnd = rows.get(A);                    // stamped A
    const rStart = rows.get(shift(A, -5));       // stamped A - 5
    if (rEnd !== undefined) pEnd.push([rEnd, act]);
    if (rStart !== undefined) pStart.push([rStart, act]);
  }
  line(`P5MIN offset ${k} min`, pEnd, pStart);
}

// ---- PREDISPATCH and PD7DAY, 30-minute products --------------------------
function gridProbe(file, offsets, stepMin) {
  const rows = readCsv(join(W60, file));
  const run = new Map();
  for (const r of rows) {
    if (r.region_id !== "VIC1") continue;
    if (!run.has(r.effective_time)) run.set(r.effective_time, new Map());
    run.get(r.effective_time).set(r.target_datetime, Number(r.rrp));
  }
  console.log(`${file}: runs ${run.size}`);
  for (const k of offsets) {
    const pEnd = [], pStart = [];
    for (const [eff, mp] of run) {
      const A = shift(eff, k);
      const act = price.get(A);
      if (act === undefined) continue;
      const a = mp.get(A), b = mp.get(shift(A, -stepMin));
      if (a !== undefined) pEnd.push([a, act]);
      if (b !== undefined) pStart.push([b, act]);
    }
    line(`${file.replace("_VIC1.csv", "")} offset ${k} min`, pEnd, pStart);
  }
}
gridProbe("predispatch_30min_VIC1.csv", [30, 120, 480, 1440, 2280], 30);
gridProbe("pd7day_30min_VIC1.csv", [30, 1440, 4320, 8640], 30);

// ---- how many 30-minute targets a run actually reaches -------------------
for (const file of ["predispatch_30min_VIC1.csv", "pd7day_30min_VIC1.csv"]) {
  const rows = readCsv(join(W60, file));
  const span = new Map();
  for (const r of rows) {
    if (r.region_id !== "VIC1") continue;
    const lead = (Date.parse(`${r.target_datetime.replace(" ", "T")}Z`) -
      Date.parse(`${r.effective_time.replace(" ", "T")}Z`)) / 60000;
    const prev = span.get(r.effective_time) || 0;
    if (lead > prev) span.set(r.effective_time, lead);
  }
  const leads = [...span.values()];
  const byClock = new Map();
  for (const [eff, lead] of span) {
    const clock = eff.slice(11, 16);
    if (!byClock.has(clock)) byClock.set(clock, lead);
  }
  console.log(`${file}: max lead min ${Math.min(...leads)} to ${Math.max(...leads)}, runs ${span.size}, distinct clock slots ${byClock.size}`);
}
