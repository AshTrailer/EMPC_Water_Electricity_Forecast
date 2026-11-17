// Why the two offer tables do not line up one to one.
//
// For Victoria on one day the price table has about three times as many rows as
// there are distinct submission keys, while the volume table has exactly one set
// of 288 periods per key. Printing the raw rows of a unit that repeats settles
// which column carries the missing distinction.

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_bidmove");
const day = process.argv[2] || "20260915";

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

const file = join(CACHE, `PUBLIC_BIDMOVE_COMPLETE_${day}.zip`);
const csv = listEntries(file).find((e) => /\.csv$/i.test(e.name));

const priceKeys = new Map();     // key -> [rows]
const availKeys = new Map();     // key -> count
const byDuid = new Map();        // duid -> rows (price)

const rl = createInterface({ input: openEntry(file, csv), crlfDelay: Infinity });
for await (const line of rl) {
  if (line[0] !== "D") continue;
  const c = line.split(",");
  const t = c[2];
  const f = c.slice(4);
  if (t === "BIDDAYOFFER_D") {
    const duid = f[1];
    if (!vic.has(duid)) continue;
    const key = `${duid}|${f[4]}|${f[5]}`;
    if (!priceKeys.has(key)) priceKeys.set(key, []);
    priceKeys.get(key).push({ sd: f[0], bsd: f[3], od: f[4], ver: f[5], b1: f[9], b10: f[18], lc: f[25], et: f[26], dir: f[27] });
    if (!byDuid.has(duid)) byDuid.set(duid, 0);
    byDuid.set(duid, byDuid.get(duid) + 1);
  } else if (t === "BIDPEROFFER_D") {
    const duid = f[1];
    if (!vic.has(duid)) continue;
    const key = `${duid}|${f[4]}|${f[6]}`;
    availKeys.set(key, (availKeys.get(key) || 0) + 1);
  }
}

console.log(`distinct price keys ${priceKeys.size}, distinct avail keys ${availKeys.size}`);
const multi = [...priceKeys].filter(([, v]) => v.length > 1).sort((a, b) => b[1].length - a[1].length);
console.log(`price keys repeated ${multi.length}`);
for (const [k, v] of multi.slice(0, 2)) {
  console.log(`\nkey ${k}  ${v.length} rows`);
  for (const r of v.slice(0, 6)) console.log(`  ${JSON.stringify(r)}`);
}

const onlyPrice = [...priceKeys.keys()].filter((k) => !availKeys.has(k));
const onlyAvail = [...availKeys.keys()].filter((k) => !priceKeys.has(k));
console.log(`\nkeys only in price table ${onlyPrice.length}  only in avail table ${onlyAvail.length}`);
for (const k of onlyPrice.slice(0, 5)) console.log(`  price-only ${k}`);
for (const k of onlyAvail.slice(0, 5)) console.log(`  avail-only ${k}`);

const cnt = [...availKeys.values()];
const hist = new Map();
for (const n of cnt) hist.set(n, (hist.get(n) || 0) + 1);
console.log(`\nperiods per avail key: ${[...hist].sort((a, b) => b[1] - a[1]).slice(0, 5).map(([n, c]) => `${n}x${c}`).join(" ")}`);
