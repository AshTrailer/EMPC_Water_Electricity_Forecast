// Measure how far the Victorian offer stack sits from the published price.
//
// E08 rests on one premise: the price is the intersection of the supply curve and
// the demand forecast. That premise is testable without any model. Take the
// aggregate stack at an origin, read it at the demand that same publication
// carries, and compare with the price that publication carries.
//
// Two readings of the ladder are reported. Raw sums every band as published.
// Capped first rescales each unit's ladder to its stated maximum availability,
// because storage in particular reports its full rating in several bands.
//
// A second quantity locates the displacement: the cumulative MW offered at or
// below the published price, minus regional demand. Under the premise it is zero.
// If it is positive it is the quantity the region was supplying elsewhere.
//
// Usage: node diag_e08_stack.mjs 20260911 20260915

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { readDay, downloadDay, stampDash, atOrBefore, BANDS } from "./lib/offers.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_daily");
const OUT = join(ROOT, "Weekly", "2026-10-13", "research", "verify");
if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });

const from = process.argv[2] || "20260911";
const to = process.argv[3] || "20260915";

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

const runs = new Map();
for (const l of readFileSync(join(ROOT, "AEMO_Data", "window_60d_20260811_20261009_vic1", "predispatch_30min_VIC1.csv"), "utf8").split(/\r?\n/).slice(1)) {
  if (!l) continue;
  const c = l.split(",");
  const eff = stampDash(c[0]);
  if (!runs.has(eff)) runs.set(eff, new Map());
  runs.get(eff).set(Number(c[3]), { rrp: Number(c[4]), demand: Number(c[6]), target: stampDash(c[2]) });
}

const days = [];
for (let d = Number(from); ; ) {
  days.push(String(d));
  if (String(d) === to) break;
  const n = new Date(Date.UTC(Math.floor(d / 10000), Math.floor((d % 10000) / 100) - 1, d % 100) + 86400000);
  d = n.getUTCFullYear() * 10000 + (n.getUTCMonth() + 1) * 100 + n.getUTCDate();
}

function quantile(values, f) {
  const s = Float64Array.from(values).sort();
  return s[Math.min(s.length - 1, Math.floor(f * s.length))];
}

function readCurve(seg, demand, rrp) {
  let cum = 0;
  let atPublished = 0;
  let atDemand = 0;
  let pAtDemand = NaN;
  for (const s of seg) {
    cum += s.mw;
    if (s.price <= rrp) atPublished = cum;
    if (atDemand === 0 && cum >= demand) {
      atDemand = cum;
      pAtDemand = s.price;
    }
  }
  if (atDemand === 0) {
    atDemand = cum;
    pAtDemand = seg.length ? seg[seg.length - 1].price : NaN;
  }
  return { total: cum, atPublished, atDemand, pAtDemand };
}

const rows = [];
let sample = null;
const t0 = Date.now();

for (const dayName of days) {
  const file = await downloadDay(CACHE, dayName);
  if (!file) {
    console.log(`${dayName}: absent`);
    continue;
  }
  const { trading, units } = await readDay(file, vic);
  const dayStart = trading;
  const dayEnd = dayStart + 1440;
  const origins = [...runs.keys()].filter((e) => e >= dayStart && e < dayEnd).sort((a, b) => a - b);

  for (const o of origins) {
    const map = runs.get(o);
    for (let step = 1; step <= 468; step += 1) {
      const target = o + 5 * step;
      if (target >= dayEnd) break;
      const period = Math.floor((target - dayStart) / 5) + 1;
      const pid = Math.min(79, Math.ceil((target - o) / 30) + 1);
      const p = map.get(pid);
      if (!p) continue;

      const raw = [];
      const capped = [];
      for (const u of units) {
        if (u.dir === "LOAD") continue;
        const rs = u.per[period];
        if (!rs) continue;
        const pick = atOrBefore(rs, o);
        if (!pick) continue;
        const lad = atOrBefore(u.lad, pick.t);
        if (!lad) continue;
        for (let b = 0; b < BANDS; b += 1) {
          const mw = pick.bands[b];
          if (mw > 0) {
            raw.push({ price: lad.prices[b], mw });
            capped.push({ price: lad.prices[b], mw: mw * pick.scale });
          }
        }
      }
      if (raw.length === 0) continue;
      raw.sort((a, b) => a.price - b.price);
      capped.sort((a, b) => a.price - b.price);

      const A = readCurve(raw, p.demand, p.rrp);
      const B = readCurve(capped, p.demand, p.rrp);
      const hour = Math.floor(((target - dayStart) % 1440) / 60);
      rows.push({
        hour, demand: p.demand, rrp: p.rrp,
        totalRaw: A.total, totalCapped: B.total,
        wedgeRaw: A.atPublished - p.demand, wedgeCapped: B.atPublished - p.demand,
        priceAtDemandRaw: A.pAtDemand, priceAtDemandCapped: B.pAtDemand,
        target,
      });

      // One fully drawn curve for the figure: the evening peak seen from midday.
      if (!sample && dayName === days[Math.floor(days.length / 2)] && Math.floor(((o - dayStart) % 1440) / 60) === 12 && hour >= 18 && hour < 19) {
        let cum = 0;
        const pts = [];
        for (const s of capped) {
          cum += s.mw;
          pts.push([Number(cum.toFixed(1)), Number(s.price.toFixed(2))]);
        }
        sample = {
          origin: o, target, demand: p.demand, rrp: p.rrp,
          price_at_demand: B.pAtDemand,
          curve: pts,
        };
      }
    }
  }
  console.log(`${dayName}: ${rows.length} rows (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
}

const byHour = [];
for (let h = 0; h < 24; h += 1) {
  const sub = rows.filter((r) => r.hour === h);
  if (sub.length === 0) continue;
  byHour.push({
    hour: h,
    n: sub.length,
    published: +quantile(sub.map((r) => r.rrp), 0.5).toFixed(2),
    curve_raw: +quantile(sub.map((r) => r.priceAtDemandRaw), 0.5).toFixed(2),
    curve_capped: +quantile(sub.map((r) => r.priceAtDemandCapped), 0.5).toFixed(2),
    wedge_raw: +quantile(sub.map((r) => r.wedgeRaw), 0.5).toFixed(0),
    wedge_capped: +quantile(sub.map((r) => r.wedgeCapped), 0.5).toFixed(0),
    demand: +quantile(sub.map((r) => r.demand), 0.5).toFixed(0),
  });
}

const scatterIdx = [];
const stride = Math.max(1, Math.floor(rows.length / 1200));
for (let i = 0; i < rows.length; i += stride) {
  scatterIdx.push([+rows[i].rrp.toFixed(2), +rows[i].priceAtDemandCapped.toFixed(2), +rows[i].priceAtDemandRaw.toFixed(2)]);
}

const summary = {
  days: { from, to, count: days.length },
  rows: rows.length,
  total_mw: {
    raw_median: +quantile(rows.map((r) => r.totalRaw), 0.5).toFixed(0),
    capped_median: +quantile(rows.map((r) => r.totalCapped), 0.5).toFixed(0),
  },
  wedge: {
    raw: {
      median: +quantile(rows.map((r) => r.wedgeRaw), 0.5).toFixed(0),
      p10: +quantile(rows.map((r) => r.wedgeRaw), 0.1).toFixed(0),
      p90: +quantile(rows.map((r) => r.wedgeRaw), 0.9).toFixed(0),
      share_within_500: +(100 * rows.filter((r) => Math.abs(r.wedgeRaw) <= 500).length / rows.length).toFixed(1),
    },
    capped: {
      median: +quantile(rows.map((r) => r.wedgeCapped), 0.5).toFixed(0),
      p10: +quantile(rows.map((r) => r.wedgeCapped), 0.1).toFixed(0),
      p90: +quantile(rows.map((r) => r.wedgeCapped), 0.9).toFixed(0),
      share_within_500: +(100 * rows.filter((r) => Math.abs(r.wedgeCapped) <= 500).length / rows.length).toFixed(1),
    },
  },
  price_at_demand: {
    raw: {
      median: +quantile(rows.map((r) => r.priceAtDemandRaw), 0.5).toFixed(2),
      median_error: +quantile(rows.map((r) => r.priceAtDemandRaw - r.rrp), 0.5).toFixed(2),
    },
    capped: {
      median: +quantile(rows.map((r) => r.priceAtDemandCapped), 0.5).toFixed(2),
      median_error: +quantile(rows.map((r) => r.priceAtDemandCapped - r.rrp), 0.5).toFixed(2),
    },
  },
  published_median: +quantile(rows.map((r) => r.rrp), 0.5).toFixed(2),
  demand_median: +quantile(rows.map((r) => r.demand), 0.5).toFixed(0),
  by_hour: byHour,
  scatter: scatterIdx,
  sample,
};

writeFileSync(join(OUT, "e08_stack.json"), JSON.stringify(summary, null, 1), "utf8");

console.log(`\nrows ${rows.length}  published median ${summary.published_median}  demand median ${summary.demand_median}`);
console.log(`total MW median: raw ${summary.total_mw.raw_median}, capped ${summary.total_mw.capped_median}`);
console.log(`price at demand median: raw ${summary.price_at_demand.raw.median} (error ${summary.price_at_demand.raw.median_error}), capped ${summary.price_at_demand.capped.median} (error ${summary.price_at_demand.capped.median_error})`);
console.log(`wedge median: raw ${summary.wedge.raw.median} [${summary.wedge.raw.p10} ${summary.wedge.raw.p90}], capped ${summary.wedge.capped.median} [${summary.wedge.capped.p10} ${summary.wedge.capped.p90}]`);
console.log(`share of rows within 500 MW of the premise: raw ${summary.wedge.raw.share_within_500}%, capped ${summary.wedge.capped.share_within_500}%`);
console.log(`\nby hour`);
for (const h of byHour) {
  console.log(`  ${String(h.hour).padStart(2)}h  published ${String(h.published).padStart(7)}  curve raw ${String(h.curve_raw).padStart(8)}  capped ${String(h.curve_capped).padStart(8)}  wedge ${String(h.wedge_raw).padStart(6)} then ${String(h.wedge_capped).padStart(6)}  demand ${h.demand}`);
}
