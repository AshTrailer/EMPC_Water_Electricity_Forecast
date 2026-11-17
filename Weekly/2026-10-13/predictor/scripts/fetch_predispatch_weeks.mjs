// Fetch the predispatch week packs that cover the scored window.
//
// The report carries the regional demand and semi scheduled availability
// forecast, the interconnector flow and limit forecast, and the published price,
// all per origin and target. One pack per week, five packs for the window.
// Files already present are left alone, so a rerun is free.

import { existsSync, mkdirSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const DIR = join(ROOT, "AEMO_Data", "predispatch_weeks");
if (!existsSync(DIR)) mkdirSync(DIR, { recursive: true });

const BASE = "https://www.nemweb.com.au/Reports/ARCHIVE/Predispatch_Reports/";
const PACKS = [
  "PUBLIC_PREDISPATCH_20260906_20260912.zip",
  "PUBLIC_PREDISPATCH_20260913_20260919.zip",
  "PUBLIC_PREDISPATCH_20260920_20260926.zip",
  "PUBLIC_PREDISPATCH_20260927_20261003.zip",
  "PUBLIC_PREDISPATCH_20261004_20261010.zip",
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const mb = (n) => (n / 1048576).toFixed(1);

let total = 0;
for (const name of PACKS) {
  const file = join(DIR, name);
  if (existsSync(file)) {
    const size = statSync(file).size;
    total += size;
    console.log(`${name}: present ${mb(size)} MB`);
    continue;
  }
  let done = false;
  for (let attempt = 1; attempt <= 3 && !done; attempt += 1) {
    const t0 = Date.now();
    try {
      const res = await fetch(BASE + name);
      if (!res.ok) {
        console.log(`${name}: HTTP ${res.status}, attempt ${attempt}`);
        await sleep(3000);
        continue;
      }
      const buf = Buffer.from(await res.arrayBuffer());
      if (buf.length < 1048576) {
        console.log(`${name}: ${buf.length} bytes, too small, attempt ${attempt}`);
        await sleep(3000);
        continue;
      }
      writeFileSync(file, buf);
      total += buf.length;
      console.log(`${name}: ${mb(buf.length)} MB in ${((Date.now() - t0) / 1000).toFixed(0)} s`);
      done = true;
    } catch (e) {
      console.log(`${name}: ${e.message}, attempt ${attempt}`);
      await sleep(3000);
    }
  }
  if (!done) console.log(`${name}: FAILED`);
  await sleep(1500);
}
console.log(`total on disk ${mb(total)} MB`);
