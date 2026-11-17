// Dump the aggregate Victoria offer curve at one origin and target.
//
// The curve read lands about six hundred dollars below the published price, which
// is too far to be a rounding or a folding error. This prints the breakpoints and
// the largest contributors so the cause can be named: either the volumes are
// being summed wrongly, or the intersection with regional demand is not where the
// market clears.
//
// Usage: node probe_curve_dump.mjs 20260915 12:00 18:00

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { readDay, stampSlash, stampDash, atOrBefore, BANDS, PERIODS } from "./lib/offers.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_daily");

const day = process.argv[2] || "20260915";
const originHm = process.argv[3] || "12:00";
const targetHm = process.argv[4] || "18:00";

const region = new Map();
for (const f of ["duid_region_registration.csv", "duid_region.csv"]) {
  const p = join(ROOT, "AEMO_Data", f);
  if (!existsSync(p)) continue;
  for (const line of readFileSync(p, "utf8").split(/\r?\n/).slice(1)) {
    const [d, r] = line.split(",");
    if (d && d !== "-" && r && !region.has(d)) region.set(d, r);
  }
}
const vic = new Set([...region].filter(([, r]) => r === "VIC1").map(([d]) => d));

const file = join(CACHE, `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}.zip`);
if (!existsSync(file)) {
  console.log(`missing ${file}`);
  process.exit(1);
}
const { units, stats } = await readDay(file, vic);
const dayStart = Date.UTC(+day.slice(0, 4), +day.slice(4, 6) - 1, +day.slice(6, 8)) / 60000;
const origin = dayStart + Number(originHm.slice(0, 2)) * 60 + Number(originHm.slice(3, 5));
const target = dayStart + Number(targetHm.slice(0, 2)) * 60 + Number(targetHm.slice(3, 5));
const period = Math.floor((target - dayStart) / 5) + 1;

console.log(`day ${day} origin ${originHm} target ${targetHm} period ${period}`);
console.log(`units ${stats.units} price lodgements ${stats.priceRows} volume rows ${stats.availRows}`);

const seg = [];
let unitTotals = [];
for (const u of units) {
  if (u.dir === "LOAD") continue;
  const rows = u.per[period];
  if (!rows) continue;
  const pick = atOrBefore(rows, origin);
  if (!pick) continue;
  const lad = atOrBefore(u.lad, pick.t);
  if (!lad) continue;
  let sum = 0;
  for (let b = 0; b < BANDS; b += 1) {
    const mw = pick.bands[b];
    sum += mw;
    if (mw > 0) seg.push({ price: lad.prices[b], mw, duid: u.duid, dir: u.dir, band: b + 1, lodgement: pick.t, priceAt: lad.t });
  }
  unitTotals.push({ duid: u.duid, dir: u.dir, mw: sum, p1: lad.prices[0], p10: lad.prices[BANDS - 1], n: rows.length });
}

seg.sort((a, b) => a.price - b.price);
let cum = 0;
const curve = [];
for (const s of seg) {
  cum += s.mw;
  curve.push({ price: s.price, cum });
}

console.log(`\naggregate segments ${seg.length}, total ${cum.toFixed(0)} MW`);
console.log(`unit totals: ${unitTotals.length} units`);
unitTotals.sort((a, b) => b.mw - a.mw);
console.log(`largest 15 units by offered MW:`);
for (const u of unitTotals.slice(0, 15)) {
  console.log(`  ${u.duid.padEnd(10)} ${String(u.dir).padEnd(14)} mw ${String(u.mw).padStart(6)}  p1 ${u.p1.toFixed(0).padStart(7)}  p10 ${u.p10.toFixed(0).padStart(7)}  lodgements ${u.n}`);
}

console.log(`\ncurve breakpoints where the cumulative MW crosses a decade:`);
let next = 0;
for (const c of curve) {
  if (c.cum >= next) {
    console.log(`  at ${String(Math.round(c.cum)).padStart(6)} MW the marginal price is ${c.price.toFixed(2)}`);
    next += 2000;
  }
}

// Published values for the same instant.
const p = join(ROOT, "AEMO_Data", "window_60d_20260811_20261009_vic1", "predispatch_30min_VIC1.csv");
let shown = 0;
for (const l of readFileSync(p, "utf8").split(/\r?\n/).slice(1)) {
  if (!l) continue;
  const c = l.split(",");
  const eff = stampDash(c[0]);
  if (eff !== origin) continue;
  const tgt = stampDash(c[2]);
  if (tgt < origin || tgt > origin + 60) continue;
  console.log(`  published at ${c[2]}: rrp ${c[4]}, total_demand ${c[6]}`);
  if (++shown >= 3) break;
}
