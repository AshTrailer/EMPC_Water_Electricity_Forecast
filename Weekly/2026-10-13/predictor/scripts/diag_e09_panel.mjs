// Five region price panel for the E09 premise measurement.
//
// Victoria's own supply curve cannot set a price that the neighbouring region
// sets, and E08 left that as the open question. This reads the monthly price and
// demand files for all five regions and reports, per five minute interval, how
// often Victoria's price equals a neighbour's and where it ranks among the five.
// Nothing is assumed about the offer stack here; this only establishes which
// region's price Victoria is carrying.
//
// Usage: node diag_e09_panel.mjs

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const OUT = join(ROOT, "Weekly", "2026-10-13", "research", "verify");
const REGIONS = ["VIC1", "NSW1", "SA1", "QLD1", "TAS1"];
const MONTHS = ["202608", "202609", "202610"];

const WINDOW_FROM = Date.UTC(2026, 7, 11, 0, 0) / 60000;
const WINDOW_TO = Date.UTC(2026, 9, 10, 0, 0) / 60000;
const SCORED_FROM = Date.UTC(2026, 8, 8, 0, 0) / 60000;

function minute(s) {
  const b = s.charCodeAt(0) === 34 ? 1 : 0;
  return Date.UTC(
    Number(s.substr(b, 4)), Number(s.substr(b + 5, 2)) - 1, Number(s.substr(b + 8, 2)),
    Number(s.substr(b + 11, 2)), Number(s.substr(b + 14, 2)), Number(s.substr(b + 17, 2)),
  ) / 60000;
}

// ------------------------------------------------------------------- reader
const price = new Map();          // minute -> { VIC1: rrp, ... }
const demand = new Map();
let rowsIn = 0;
let dupes = 0;
for (const m of MONTHS) {
  for (const r of REGIONS) {
    const p = join(ROOT, "AEMO_Data", `PRICE_AND_DEMAND_${m}_${r}.csv`);
    const lines = readFileSync(p, "utf8").split(/\r?\n/);
    const head = lines[0].split(",");
    const ci = head.indexOf("SETTLEMENTDATE");
    const ri = head.indexOf("RRP");
    const di = head.indexOf("TOTALDEMAND");
    if (ci < 0 || ri < 0 || di < 0) throw new Error(`${p}: unexpected header ${lines[0]}`);
    for (let i = 1; i < lines.length; i += 1) {
      const l = lines[i];
      if (!l) continue;
      const c = l.split(",");
      const t = minute(c[ci]);
      if (!price.has(t)) price.set(t, {});
      if (price.get(t)[r] !== undefined) dupes += 1;
      price.get(t)[r] = Number(c[ri]);
      if (!demand.has(t)) demand.set(t, {});
      demand.get(t)[r] = Number(c[di]);
      rowsIn += 1;
    }
  }
}

const times = [...price.keys()].sort((a, b) => a - b);
const full = times.filter((t) => REGIONS.every((r) => Number.isFinite(price.get(t)[r])));
const inWindow = full.filter((t) => t >= WINDOW_FROM && t < WINDOW_TO);
const inScored = full.filter((t) => t >= SCORED_FROM && t < WINDOW_TO);

console.log(`rows read ${rowsIn}, duplicate keys ${dupes}`);
console.log(`interval grid ${times.length}, all five regions present ${full.length}`);
console.log(`window ${inWindow.length}, scored ${inScored.length}`);
console.log(`first ${new Date(times[0] * 60000).toISOString()} last ${new Date(times[times.length - 1] * 60000).toISOString()}`);

// ---------------------------------------------------------------- statistics
const TOL = [0.1, 0.5, 1, 2, 5, 10];

function quant(sorted, q) {
  if (sorted.length === 0) return NaN;
  const x = (sorted.length - 1) * q;
  const lo = Math.floor(x);
  const hi = Math.ceil(x);
  return lo === hi ? sorted[lo] : sorted[lo] + (sorted[hi] - sorted[lo]) * (x - lo);
}

function analyse(label, sub) {
  const n = sub.length;
  const vic = sub.map((t) => price.get(t).VIC1);
  const mean = (a) => a.reduce((s, x) => s + x, 0) / a.length;
  const sortedVic = [...vic].sort((a, b) => a - b);
  const out = {
    label,
    n,
    price_median: Object.fromEntries(REGIONS.map((r) => [r, quant(sub.map((t) => price.get(t)[r]).sort((a, b) => a - b), 0.5)])),
    price_mean: Object.fromEntries(REGIONS.map((r) => [r, Number(mean(sub.map((t) => price.get(t)[r])).toFixed(3))])),
    demand_median: Object.fromEntries(REGIONS.map((r) => [r, quant(sub.map((t) => demand.get(t)[r]).sort((a, b) => a - b), 0.5)])),
    equal_share: {},
    spread_abs_median: {},
    rank: {},
    corr: {},
  };
  const mv = mean(vic);
  const sdv = Math.sqrt(mean(vic.map((x) => (x - mv) ** 2)));
  for (const r of REGIONS) {
    if (r === "VIC1") continue;
    const other = sub.map((t) => price.get(t)[r]);
    out.equal_share[r] = Object.fromEntries(TOL.map((tol) => {
      const k = vic.filter((x, i) => Math.abs(x - other[i]) <= tol).length;
      return [String(tol), Number((100 * k / n).toFixed(3))];
    }));
    out.spread_abs_median[r] = quant(vic.map((x, i) => Math.abs(x - other[i])).sort((a, b) => a - b), 0.5);
    const mo = mean(other);
    const sdo = Math.sqrt(mean(other.map((x) => (x - mo) ** 2)));
    let s = 0;
    for (let i = 0; i < n; i += 1) s += (vic[i] - mv) * (other[i] - mo);
    out.corr[r] = sdo > 0 && sdv > 0 ? Number((s / (n * sdv * sdo)).toFixed(4)) : NaN;
  }
  // rank of Victoria among the five, ties counted as a tie only inside 0.1
  let lowest = 0;
  let highest = 0;
  let interior = 0;
  let allEqual = 0;
  let tieLowest = 0;
  for (const t of sub) {
    const v = price.get(t).VIC1;
    const others = REGIONS.filter((r) => r !== "VIC1").map((r) => price.get(t)[r]);
    const minOther = Math.min(...others);
    const maxOther = Math.max(...others);
    const isLow = v < minOther - 0.1;
    const isHigh = v > maxOther + 0.1;
    const isTieLow = Math.abs(v - minOther) <= 0.1 && v <= maxOther + 0.1;
    if (isLow) lowest += 1;
    else if (isHigh) highest += 1;
    else interior += 1;
    if (isTieLow) tieLowest += 1;
    if (otherSpread(price.get(t)) <= 0.1) allEqual += 1;
  }
  out.rank = {
    lowest_pct: Number((100 * lowest / n).toFixed(3)),
    highest_pct: Number((100 * highest / n).toFixed(3)),
    interior_pct: Number((100 * interior / n).toFixed(3)),
    tied_lowest_pct: Number((100 * tieLowest / n).toFixed(3)),
    all_five_within_0_1_pct: Number((100 * allEqual / n).toFixed(3)),
  };
  return out;
}

function otherSpread(rec) {
  const vals = REGIONS.map((r) => rec[r]);
  return Math.max(...vals) - Math.min(...vals);
}

const win = analyse("window", inWindow);
const sco = analyse("scored", inScored);
for (const s of [win, sco]) {
  console.log(`\n===== ${s.label} n=${s.n} =====`);
  console.log(`median price  ${JSON.stringify(s.price_median)}`);
  console.log(`median demand ${JSON.stringify(s.demand_median)}`);
  console.log(`rank ${JSON.stringify(s.rank)}`);
  for (const r of REGIONS) {
    if (r === "VIC1") continue;
    console.log(`  vs ${r}: equal% ${JSON.stringify(s.equal_share[r])} |spread| med ${s.spread_abs_median[r]} corr ${s.corr[r]}`);
  }
}

// -------------------------------------------------------------- hourly panel
// A small table for the figure: hourly mean price per region over the window.
const hourly = new Map();
for (const t of inWindow) {
  const h = Math.floor((t - WINDOW_FROM) / 60);
  if (!hourly.has(h)) hourly.set(h, { n: 0, sum: Object.fromEntries(REGIONS.map((r) => [r, 0])) });
  const rec = hourly.get(h);
  rec.n += 1;
  for (const r of REGIONS) rec.sum[r] += price.get(t)[r];
}
const hourlyRows = [...hourly.keys()].sort((a, b) => a - b).map((h) => {
  const rec = hourly.get(h);
  const row = [WINDOW_FROM + h * 60];
  for (const r of REGIONS) row.push(Number((rec.sum[r] / rec.n).toFixed(4)));
  return row;
});

writeFileSync(join(OUT, "e09_panel.json"), JSON.stringify({
  rows_read: rowsIn,
  duplicate_keys: dupes,
  intervals: full.length,
  window_n: inWindow.length,
  scored_n: inScored.length,
  window: win,
  scored: sco,
  regions: REGIONS,
  hourly_from: WINDOW_FROM,
  hourly: hourlyRows,
  note: "times are minutes since 1970; the hourly block is the mean RRP of each hour in the window",
}, null, 2), "utf8");
console.log(`\nwrote ${join(OUT, "e09_panel.json")}`);
