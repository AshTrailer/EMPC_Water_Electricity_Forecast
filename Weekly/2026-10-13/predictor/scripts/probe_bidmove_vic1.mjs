// Validate the Victoria offer extract on two days before committing to the window.
//
// Four questions. How many Victoria units the register names and how many of
// them actually bid; whether the ten price bands arrive in ascending order;
// what the aggregate offer curve totals at, against a Victoria load near 5 GW;
// and whether the demand forecast at the origin lands inside a sensible band.

import { createReadStream, createWriteStream, writeFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parseDay, BANDS, PERIODS } from "./lib/bidmove.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_bidmove");
if (!existsSync(CACHE)) mkdirSync(CACHE, { recursive: true });

const days = process.argv.slice(2);
if (days.length === 0) days.push("20261015", "20261016");

// Region map: registration list first, PASA snapshot as the fallback.
const region = new Map();
for (const f of ["duid_region_registration.csv", "duid_region.csv"]) {
  const p = join(ROOT, "AEMO_Data", f);
  if (!existsSync(p)) continue;
  const lines = readFileSync(p, "utf8").split(/\r?\n/);
  for (const line of lines.slice(1)) {
    if (!line) continue;
    const [d, r] = line.split(",");
    if (!d || d === "-" || !r) continue;
    if (!region.has(d)) region.set(d, r);
  }
}
const vic = new Set([...region].filter(([, r]) => r === "VIC1").map(([d]) => d));
console.log(`region map ${region.size} units, Victoria ${vic.size}`);

for (const day of days) {
  const file = join(CACHE, `PUBLIC_BIDMOVE_COMPLETE_${day}.zip`);
  if (!existsSync(file)) {
    const url = "https://nemweb.com.au/Reports/CURRENT/Bidmove_Complete/";
    const html = await (await fetch(url)).text();
    const hit = (html.match(new RegExp(`PUBLIC_BIDMOVE_COMPLETE_${day}_\\d+\\.zip`, "gi")) || [])[0];
    if (!hit) {
      console.log(`${day}: not in CURRENT`);
      continue;
    }
    const buf = Buffer.from(await (await fetch(url + hit)).arrayBuffer());
    writeFileSync(file, buf);
    console.log(`${day}: downloaded ${buf.length} bytes as ${hit}`);
  }

  const t0 = Date.now();
  const { units, stats } = await parseDay(file, vic);
  const secs = ((Date.now() - t0) / 1000).toFixed(1);

  let versions = 0;
  let nonMono = 0;
  const bandMw = new Float64Array(BANDS);
  const priceMin = [];
  const priceMax = [];
  const dirs = new Map();
  let priceZero = 0;
  let bandRows = 0;

  for (const u of units.values()) {
    versions += u.versions.length;
    dirs.set(u.dir, (dirs.get(u.dir) || 0) + 1);
    for (const v of u.versions) {
      let down = false;
      for (let b = 1; b < BANDS; b += 1) if (v.prices[b] < v.prices[b - 1] - 1e-9) down = true;
      if (down) nonMono += 1;
      priceMin.push(v.prices[0]);
      priceMax.push(v.prices[BANDS - 1]);
      for (let b = 0; b < BANDS; b += 1) {
        bandMw[b] += v.avail[b];
        if (v.avail[b] > 0) bandRows += 1;
        if (v.prices[b] === 0) priceZero += 1;
      }
    }
  }

  priceMin.sort((a, b) => a - b);
  priceMax.sort((a, b) => a - b);
  let total = 0;
  for (let b = 0; b < BANDS; b += 1) total += bandMw[b];

  console.log(`\n=== ${day}  ${secs}s  ${JSON.stringify(stats).slice(0, 200)}`);
  console.log(`  units bidding ${units.size}  versions ${versions}  directions ${JSON.stringify([...dirs])}`);
  console.log(`  non-monotone price ladders ${nonMono} of ${versions}`);
  console.log(`  price band 1 median ${priceMin[Math.floor(priceMin.length / 2)]}, band 10 median ${priceMax[Math.floor(priceMax.length / 2)]}`);
  console.log(`  offered MW per band (summed over versions, period 1): ${[...bandMw].map((x) => x.toFixed(0)).join(" ")}`);
  console.log(`  total ${total.toFixed(0)} MW, zero-priced band-entries ${priceZero} of ${versions * BANDS}`);
  console.log(`  units named in Victoria but not bidding: ${[...vic].filter((d) => !units.has(d)).length}`);
}
