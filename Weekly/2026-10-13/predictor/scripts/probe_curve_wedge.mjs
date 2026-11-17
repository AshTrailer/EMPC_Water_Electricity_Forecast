// How far the local merit order is displaced from regional demand.
//
// If Victoria cleared inside its own offer stack, the cumulative MW offered at or
// below the published price would equal Victoria demand. It does not. The
// difference is the quantity the region was supplying elsewhere, net exports plus
// losses, or the quantity it was importing. That number decides whether the level
// channel of E08 can be built from Victoria offers alone.
//
// Usage: node probe_curve_wedge.mjs 20260914 20260916

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { readDay, downloadDay, stampDash, atOrBefore, BANDS } from "./lib/offers.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_daily");
const from = process.argv[2] || "20260914";
const to = process.argv[3] || "20260916";

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

// Publications: effective time, period id, published price and demand.
const runs = new Map();
for (const l of readFileSync(join(ROOT, "AEMO_Data", "window_60d_20260811_20261009_vic1", "predispatch_30min_VIC1.csv"), "utf8").split(/\r?\n/).slice(1)) {
  if (!l) continue;
  const c = l.split(",");
  const eff = stampDash(c[0]);
  if (!runs.has(eff)) runs.set(eff, new Map());
  runs.get(eff).set(Number(c[3]), { rrp: Number(c[4]), demand: Number(c[6]) });
}

const days = [];
for (let d = Number(from); ; ) {
  days.push(String(d));
  if (String(d) === to) break;
  const n = new Date(Date.UTC(Math.floor(d / 10000), Math.floor((d % 10000) / 100) - 1, d % 100) + 86400000);
  d = n.getUTCFullYear() * 10000 + (n.getUTCMonth() + 1) * 100 + n.getUTCDate();
}

const rows = [];
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

      const seg = [];
      const segScaled = [];
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
            seg.push({ price: lad.prices[b], mw });
            segScaled.push({ price: lad.prices[b], mw: mw * pick.scale });
          }
        }
      }
      if (seg.length === 0) continue;
      seg.sort((a, b) => a.price - b.price);
      segScaled.sort((a, b) => a.price - b.price);
      let cum = 0;
      let atPublished = 0;
      let atDemand = 0;
      let pm = NaN;
      for (const s of seg) {
        cum += s.mw;
        if (s.price <= p.rrp) atPublished = cum;
        if (atDemand === 0 && cum >= p.demand) {
          atDemand = cum;
          pm = s.price;
        }
      }
      if (atDemand === 0) {
        atDemand = cum;
        pm = seg[seg.length - 1].price;
      }
      let cum2 = 0;
      let atPublished2 = 0;
      let atDemand2 = 0;
      let pm2 = NaN;
      for (const s of segScaled) {
        cum2 += s.mw;
        if (s.price <= p.rrp) atPublished2 = cum2;
        if (atDemand2 === 0 && cum2 >= p.demand) {
          atDemand2 = cum2;
          pm2 = s.price;
        }
      }
      if (atDemand2 === 0) {
        atDemand2 = cum2;
        pm2 = segScaled[segScaled.length - 1].price;
      }
      const hour = Math.floor(((target - dayStart) % 1440) / 60);
      rows.push({
        hour,
        wedge: atPublished - p.demand, total: cum, rrp: p.rrp, demand: p.demand, pm,
        wedge2: atPublished2 - p.demand, total2: cum2, pm2,
        target,
      });
    }
  }
  console.log(`${dayName}: ${rows.length} rows (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
}

function q(a, f) {
  const s = Array.from(a).sort((x, y) => x - y);
  return s[Math.min(s.length - 1, Math.floor(f * s.length))];
}

const wedge = rows.map((r) => r.wedge);
console.log(`\nrows ${rows.length}`);
console.log(`cumulative MW at the published price minus demand`);
console.log(`  mean ${(wedge.reduce((a, b) => a + b, 0) / wedge.length).toFixed(0)}  p5 ${q(wedge, 0.05).toFixed(0)}  p25 ${q(wedge, 0.25).toFixed(0)}  median ${q(wedge, 0.5).toFixed(0)}  p75 ${q(wedge, 0.75).toFixed(0)}  p95 ${q(wedge, 0.95).toFixed(0)}`);
console.log(`  share positive ${(100 * wedge.filter((x) => x > 0).length / wedge.length).toFixed(1)}%`);
console.log(`  share within 500 MW of zero ${(100 * wedge.filter((x) => Math.abs(x) <= 500).length / wedge.length).toFixed(1)}%`);

const wedge2 = rows.map((r) => r.wedge2);
console.log(`\nafter renormalising each unit ladder to its maximum availability`);
console.log(`  total MW median ${q(rows.map((r) => r.total), 0.5).toFixed(0)} before, ${q(rows.map((r) => r.total2), 0.5).toFixed(0)} after`);
console.log(`  wedge median ${q(wedge, 0.5).toFixed(0)} before, ${q(wedge2, 0.5).toFixed(0)} after`);
console.log(`  curve price median ${q(rows.map((r) => r.pm), 0.5).toFixed(0)} before, ${q(rows.map((r) => r.pm2), 0.5).toFixed(0)} after`);
console.log(`\nby hour of target`);
for (let h = 0; h < 24; h += 2) {
  const sub = rows.filter((r) => r.hour >= h && r.hour < h + 2);
  if (sub.length === 0) continue;
  const w = sub.map((r) => r.wedge);
  const pmd = sub.map((r) => r.pm);
  const rrp = sub.map((r) => r.rrp);
  const w2 = sub.map((r) => r.wedge2);
  console.log(`  ${String(h).padStart(2)}-${String(h + 2).padStart(2)}h  wedge ${q(w, 0.5).toFixed(0).padStart(6)} then ${q(w2, 0.5).toFixed(0).padStart(6)}  curve price ${q(pmd, 0.5).toFixed(0).padStart(6)}  published ${q(rrp, 0.5).toFixed(0).padStart(6)}  n ${sub.length}`);
}
