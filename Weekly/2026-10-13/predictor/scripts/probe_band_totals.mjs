// Are the Victoria volumes being summed correctly, and is the unit set right?
//
// The total offered MW comes out near 19.5 GW, which is more than the region can
// physically hold, and reading the curve at demand lands far below the published
// price. Two candidates: band availabilities that do not sum to the unit's
// maximum availability, or units assigned to Victoria that are not Victorian.
// Both are settled by printing the largest units and their band structure.

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";
import { stampSlash } from "./lib/offers.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const day = process.argv[2] || "20260915";
const period = Number(process.argv[3] || 217);
const file = join(ROOT, "AEMO_Data", "offers_daily", `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}.zip`);

const region = new Map();
for (const f of ["duid_region_registration.csv", "duid_region.csv"]) {
  const p = join(ROOT, "AEMO_Data", f);
  if (!existsSync(p)) continue;
  for (const line of readFileSync(p, "utf8").split(/\r?\n/).slice(1)) {
    const [d, r] = line.split(",");
    if (d && d !== "-" && r && !region.has(d)) region.set(d, r);
  }
}

const csv = listEntries(file).find((e) => /\.csv$/i.test(e.name));
const byUnit = new Map();     // "duid|dir" -> {maxavail, bands, t}
const priceOf = new Map();    // "duid|dir|t" -> Float64Array
const rl = createInterface({ input: openEntry(file, csv), crlfDelay: Infinity });
for await (const line of rl) {
  if (line.charCodeAt(0) !== 68) continue;
  const c = line.split(",");
  const p = Number(c[8]);
  if (p !== period) continue;
  const duid = c[4];
  if (region.get(duid) !== "VIC1") continue;
  const table = c[2];
  if (table === "BIDOFFERPERIOD_SPARSE") {
    const dir = c[29];
    const bands = [];
    for (let k = 0; k < 10; k += 1) bands.push(Number(c[18 + k]) || 0);
    byUnit.set(`${duid}|${dir}`, { maxavail: Number(c[10]), bands, t: stampSlash(c[7]) });
  } else if (table === "BIDDAYOFFER") {
    const dir = c[35];
    const pr = [];
    for (let k = 0; k < 10; k += 1) pr.push(Number(c[12 + k]));
    priceOf.set(`${duid}|${dir}|${stampSlash(c[7])}`, pr);
  }
}

console.log(`period ${period}: ${byUnit.size} unit-direction rows in Victoria`);
const rows = [...byUnit.entries()].map(([k, v]) => {
  const sum = v.bands.reduce((a, b) => a + b, 0);
  const pr = priceOf.get(`${k}|${v.t}`) || [];
  return { k, ...v, sum, p1: pr[0], p10: pr[9], pr };
});
rows.sort((a, b) => b.sum - a.sum);

console.log(`\nlargest 25 by total band MW`);
console.log(`  ${"unit".padEnd(22)} ${"maxAvail".padStart(9)} ${"bandSum".padStart(8)} ${"band1 MW".padStart(9)} ${"band2 MW".padStart(9)} ${"p1".padStart(9)} ${"p10".padStart(9)}`);
for (const r of rows.slice(0, 25)) {
  console.log(`  ${r.k.padEnd(22)} ${String(r.maxavail).padStart(9)} ${String(r.sum).padStart(8)} ${String(r.bands[0]).padStart(9)} ${String(r.bands[1]).padStart(9)} ${String(r.p1 ?? "").padStart(9)} ${String(r.p10 ?? "").padStart(9)}`);
}

const bad = rows.filter((r) => Math.abs(r.sum - r.maxavail) > 0.5);
console.log(`\nunits whose band sum differs from MAXAVAIL by more than 0.5 MW: ${bad.length} of ${rows.length}`);
for (const r of bad.slice(0, 8)) console.log(`  ${r.k} maxAvail ${r.maxavail} bandSum ${r.sum}`);

const total = rows.reduce((a, r) => a + r.sum, 0);
const totalMax = rows.reduce((a, r) => a + r.maxavail, 0);
console.log(`\ntotal band MW ${total.toFixed(0)}, total MAXAVAIL ${totalMax.toFixed(0)}`);
