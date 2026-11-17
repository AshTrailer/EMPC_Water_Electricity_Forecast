// Fetch the monthly price and demand CSV for every mainland region.
//
// The 60 day window only has Victoria locally. E09 needs the neighbouring
// regions' prices to know whether Victoria sets its own price or inherits one,
// so the same monthly product is pulled for the other four regions. Files land
// under AEMO_Data beside the existing Victoria months and are skipped when
// present.
//
// Usage: node fetch_neighbour_price.mjs [--months 202608,202609,202610]

import { existsSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const DIR = join(ROOT, "AEMO_Data");
const BASE = "https://www.aemo.com.au/aemo/data/nem/priceanddemand/";

const argv = process.argv.slice(2);
const arg = (name, dflt) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : dflt;
};
const months = arg("--months", "202608,202609,202610").split(",");
const regions = ["NSW1", "QLD1", "SA1", "TAS1", "VIC1"];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

for (const m of months) {
  for (const r of regions) {
    const name = `PRICE_AND_DEMAND_${m}_${r}.csv`;
    const file = join(DIR, name);
    if (existsSync(file)) {
      console.log(`${name}: present`);
      continue;
    }
    let done = false;
    for (let attempt = 1; attempt <= 3 && !done; attempt += 1) {
      try {
        const res = await fetch(BASE + name);
        if (!res.ok) {
          console.log(`${name}: HTTP ${res.status}, attempt ${attempt}`);
          await sleep(1500);
          continue;
        }
        const buf = Buffer.from(await res.arrayBuffer());
        if (buf.length < 1000) {
          console.log(`${name}: ${buf.length} bytes, too small, attempt ${attempt}`);
          await sleep(1500);
          continue;
        }
        writeFileSync(file, buf);
        console.log(`${name}: ${buf.length} bytes`);
        done = true;
      } catch (e) {
        console.log(`${name}: ${e.message}, attempt ${attempt}`);
        await sleep(1500);
      }
    }
    if (!done) console.log(`${name}: FAILED`);
    await sleep(1200);
  }
}
console.log("done");
