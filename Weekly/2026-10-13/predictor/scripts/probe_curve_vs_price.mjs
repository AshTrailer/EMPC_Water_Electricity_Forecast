// Does the aggregate Victoria offer curve reproduce AEMO's own price?
//
// This is the feasibility test for E08. For every publication of one day, the
// curve is built from the versions each unit had lodged by that moment, then
// read at the demand forecast that publication carries. If the curve lands on
// the published price, the stack is the mechanism and can be used. If it lands
// systematically elsewhere, the gap is the interconnector and network effect,
// and that has to be modelled before anything else.
//
// Output: research/verify/curve_vs_price.csv

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseDay, BANDS, PERIODS, stamp } from "./lib/bidmove.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_bidmove");
const OUT = join(ROOT, "Weekly", "2026-10-13", "research", "verify");
if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });
if (!existsSync(CACHE)) mkdirSync(CACHE, { recursive: true });

const day = process.argv[2] || "20261016";

// Victoria units from the register.
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

// Forecast demand and price carried by each publication.
const rows = [];
{
  const p = join(ROOT, "AEMO_Data", "window_60d_20260811_20261009_vic1", "predispatch_30min_VIC1.csv");
  const text = readFileSync(p, "utf8");
  const lines = text.split(/\r?\n/);
  for (let i = 1; i < lines.length; i += 1) {
    const l = lines[i];
    if (!l) continue;
    const c = l.split(",");
    rows.push({
      eff: stamp(c[0].replace(/-/g, "/")),
      target: stamp(c[2].replace(/-/g, "/")),
      pid: Number(c[3]),
      rrp: Number(c[4]),
      dem: Number(c[6]),
      run: c[7],
    });
  }
}

async function ensure(d) {
  const file = join(CACHE, `PUBLIC_BIDMOVE_COMPLETE_${d}.zip`);
  if (existsSync(file)) return file;
  const url = "https://nemweb.com.au/Reports/CURRENT/Bidmove_Complete/";
  const html = await (await fetch(url)).text();
  const hit = (html.match(new RegExp(`PUBLIC_BIDMOVE_COMPLETE_${d}_\\d+\\.zip`, "gi")) || [])[0];
  if (!hit) return null;
  writeFileSync(file, Buffer.from(await (await fetch(url + hit)).arrayBuffer()));
  return file;
}

const file = await ensure(day);
if (!file) {
  console.log(`${day} not available`);
  process.exit(1);
}
const { units } = await parseDay(file, vic);

// Versions per unit already sorted by submission time. Selecting "as of origin"
// is one backward scan.
function latest(u, asOf) {
  const vs = u.versions;
  for (let i = vs.length - 1; i >= 0; i -= 1) if (vs[i].t <= asOf) return vs[i];
  return null;
}

const aggPrice = [];
const aggMw = [];

function buildCurve(asOf, period) {
  aggPrice.length = 0;
  aggMw.length = 0;
  for (const u of units.values()) {
    if (u.dir === "LOAD") continue;
    const v = latest(u, asOf);
    if (!v) continue;
    const base = (period - 1) * BANDS;
    for (let b = 0; b < BANDS; b += 1) {
      const mw = v.avail[base + b];
      if (mw > 0) {
        aggPrice.push(v.prices[b]);
        aggMw.push(mw);
      }
    }
  }
  const idx = aggPrice.map((_, i) => i).sort((a, b) => aggPrice[a] - aggPrice[b]);
  const prices = new Float64Array(idx.length);
  const cum = new Float64Array(idx.length);
  let s = 0;
  for (let i = 0; i < idx.length; i += 1) {
    const j = idx[i];
    s += aggMw[j];
    prices[i] = aggPrice[j];
    cum[i] = s;
  }
  return { prices, cum };
}

function priceAt(curve, demand) {
  const { prices, cum } = curve;
  if (cum.length === 0) return NaN;
  let lo = 0;
  let hi = cum.length - 1;
  if (demand <= cum[0]) return prices[0];
  if (demand >= cum[hi]) return prices[hi];
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (cum[mid] < demand) lo = mid + 1;
    else hi = mid;
  }
  return prices[lo];
}

// One origin per publication of the day, all targets for that origin.
const dayStart = stamp(`${day.slice(0, 4)}/${day.slice(4, 6)}/${day.slice(6, 8)}/00:00:00`);
const origins = [...new Set(rows.filter((r) => r.eff >= dayStart && r.eff < dayStart + 1440).map((r) => r.eff))].sort((a, b) => a - b);
console.log(`${day}: ${origins.length} publications, ${units.size} units`);

const out = ["origin,target,pid,demand,rrp,p_marg,p_prev,cum_at_demand,total_mw,spread"];
let n = 0;
const diffs = [];

for (const o of origins) {
  const mine = rows.filter((r) => r.eff === o);
  for (const r of mine) {
    if (r.target < o) continue;
    const period = ((r.target - dayStart) % 1440) / 5;
    if (!(period >= 0 && period < PERIODS)) continue;
    const pid = Math.floor(period) + 1;
    const curve = buildCurve(o, pid);
    if (curve.cum.length === 0) continue;
    const total = curve.cum[curve.cum.length - 1];
    const p = priceAt(curve, r.dem);
    // Neighbouring bands, so the jump at the point can be seen.
    let k = 0;
    while (k < curve.cum.length - 1 && curve.cum[k] < r.dem) k += 1;
    const pMarg = curve.prices[k];
    const pPrev = k > 0 ? curve.prices[k - 1] : pMarg;
    diffs.push(p - r.rrp);
    out.push(`${o},${r.target},${pid},${r.dem},${r.rrp},${p},${pMarg},${pPrev},${curve.cum[k]},${total},${total - r.dem}`);
    n += 1;
  }
}

writeFileSync(join(OUT, "curve_vs_price.csv"), `${out.join("\n")}\n`, "utf8");

diffs.sort((a, b) => a - b);
const q = (f) => diffs[Math.min(diffs.length - 1, Math.floor(f * diffs.length))];
const mean = diffs.reduce((a, b) => a + b, 0) / diffs.length;
const sd = Math.sqrt(diffs.reduce((a, b) => a + (b - mean) ** 2, 0) / diffs.length);
let agree = 0;
for (const d of diffs) if (Math.abs(d) < 0.01) agree += 1;

console.log(`rows ${n}`);
console.log(`curve price minus published price: mean ${mean.toFixed(2)}  sd ${sd.toFixed(2)}`);
console.log(`  p10 ${q(0.1).toFixed(2)}  p25 ${q(0.25).toFixed(2)}  median ${q(0.5).toFixed(2)}  p75 ${q(0.75).toFixed(2)}  p90 ${q(0.9).toFixed(2)}`);
console.log(`  within 0.01: ${(100 * agree / diffs.length).toFixed(1)}%`);
