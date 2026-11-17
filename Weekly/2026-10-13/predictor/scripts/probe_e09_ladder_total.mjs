// Take one ladder apart: how much capacity it holds, where the cap bites, and
// what it reads at a few quantities.
//
// The rebuilt candidate prices the region ten times too dear at the cleared
// generation, which means the stack is shorter than the fleet that cleared it.
// This prints the total, the number of units whose ten bands were scaled down,
// and the cumulative at a few MW, so the cause is measured rather than guessed.

import { join } from "node:path";
import { readFileSync } from "node:fs";
import { readDay } from "./lib/offers.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_daily");

const cls = new Map();
for (const line of readFileSync(join(ROOT, "AEMO_Data", "duid_unit_class.csv"), "utf8").split(/\r?\n/).slice(1)) {
  if (!line) continue;
  const c = line.split(",");
  if (c[0]) cls.set(c[0], c[4] || "");
}
const isSemi = (d) => (cls.get(d) || "").toLowerCase().includes("semi");

const region = new Map();
for (const f of ["duid_region_registration.csv", "duid_region.csv"]) {
  for (const line of readFileSync(join(ROOT, "AEMO_Data", f), "utf8").split(/\r?\n/).slice(1)) {
    const [d, r] = line.split(",");
    if (d && d !== "-" && r && !region.has(d)) region.set(d, r);
  }
}
const vic = new Set([...region].filter(([, r]) => r === "VIC1").map(([d]) => d));

const DAY = process.argv[2] || "20260908";
const PERIOD = Number(process.argv[3] || 100);
const ORIGIN_SHIFT_MIN = Number(process.argv[4] || 0);

const day = await readDay(join(CACHE, `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${DAY}.zip`), vic);
const origin = day.trading + 5 * (PERIOD - 1) + ORIGIN_SHIFT_MIN;

const segs = [];
let nUnits = 0;
let nCapped = 0;
let lostToCap = 0;
let rawSum = 0;
const details = [];
for (const u of day.units) {
  const dir = u.key.slice(u.key.indexOf("|") + 1);
  if (dir === "LOAD") continue;
  if (isSemi(u.duid)) continue;
  const rows = u.per[PERIOD];
  if (!rows) continue;
  let pick = null;
  for (const r of rows) if (r.t <= origin) pick = r;       // rows are sorted by t
  if (!pick) continue;
  const lad = u.lad.filter((x) => x.t <= pick.t).pop();
  if (!lad) continue;
  nUnits += 1;
  rawSum += pick.sum;
  if (pick.scale < 1) { nCapped += 1; lostToCap += pick.sum - pick.maxAvail; }
  details.push({ duid: u.duid, sum: pick.sum, maxAvail: pick.maxAvail, scale: pick.scale,
    prices: Array.from(lad.prices).slice(0, 3), bands: Array.from(pick.bands) });
  for (let b = 0; b < 10; b += 1) {
    const mw = pick.bands[b] * pick.scale;
    if (mw > 0) segs.push({ p: lad.prices[b], mw });
  }
}
segs.sort((a, b) => a.p - b.p);
let cum = 0;
const curve = [];
for (const s of segs) { cum += s.mw; curve.push({ p: s.p, cum }); }

console.log(`day ${DAY} period ${PERIOD} origin shift ${ORIGIN_SHIFT_MIN} min`);
console.log(`units contributing ${nUnits}, of which scaled down ${nCapped}`);
console.log(`raw band sum ${rawSum.toFixed(0)} MW, lost to the cap ${lostToCap.toFixed(0)} MW, stack total ${cum.toFixed(0)} MW`);
console.log(`lowest price ${curve[0].p}, highest price ${curve[curve.length - 1].p}`);

for (const q of [3000, 4000, 5000, 5461, 6000, 7000]) {
  const hit = curve.find((c) => c.cum >= q);
  console.log(`  at ${q} MW -> ${hit ? "$" + hit.p : "beyond the stack"}`);
}
console.log("\nMW offered at or below a price:");
for (const p of [-50, 0, 20, 50, 100, 200, 500, 1000]) {
  const below = curve.filter((c) => c.p <= p);
  console.log(`  <= ${String(p).padStart(5)} $ -> ${(below.length ? below[below.length - 1].cum : 0).toFixed(0)} MW`);
}

console.log("\nunits with the largest cap loss:");
details.sort((a, b) => (b.sum - b.maxAvail) - (a.sum - a.maxAvail));
for (const d of details.slice(0, 8)) {
  console.log(`  ${d.duid.padEnd(12)} sum ${String(d.sum).padStart(7)} maxAvail ${String(d.maxAvail).padStart(7)} scale ${d.scale.toFixed(3)} first prices ${d.prices.join(",")}`);
}
