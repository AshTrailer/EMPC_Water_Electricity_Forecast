// Census of one NEXT_DAY_OFFER_ENERGY_SPARSE file, streamed.
//
// Two questions. Which tables does it carry, and does any of them hold a MW
// volume per price band. The second decides whether the daily snapshot can
// build a supply curve or only a price ladder.

import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const path = process.argv[2];
if (!path) {
  console.log("usage: node offer_census.mjs <csv path>");
  process.exit(1);
}

const tables = new Map();      // table -> rows
const header = new Map();      // table -> field list
let rows = 0;
let firstD = null;
const duid = new Set();

const rl = createInterface({ input: createReadStream(path, "latin1"), crlfDelay: Infinity });
for await (const line of rl) {
  rows += 1;
  const tag = line.slice(0, 1);
  if (tag === "C") continue;
  const c = line.split(",");
  if (tag === "I") {
    const t = c[2];
    header.set(t, c.slice(4));
    tables.set(t, 0);
    continue;
  }
  if (tag === "D") {
    const t = c[2];
    tables.set(t, (tables.get(t) || 0) + 1);
    if (t === "BIDDAYOFFER") {
      duid.add(c[4]);
      if (!firstD) firstD = c;
    }
  }
}

console.log(`file rows ${rows}`);
console.log(`\ntables:`);
for (const [t, n] of [...tables].sort((a, b) => b[1] - a[1])) {
  console.log(`  ${t.padEnd(28)} ${String(n).padStart(9)}  fields ${header.get(t)?.length ?? 0}`);
}
console.log(`\nBIDDAYOFFER distinct DUIDs ${duid.size}`);
const h = header.get("BIDDAYOFFER") || [];
const lower = h.map((x) => x.toLowerCase());
const volumeish = h.filter((x) => /mw|band\d$|volume|capacity|avail/i.test(x) && !/^PRICEBAND/.test(x));
console.log(`\nfields that could carry a volume: ${volumeish.length ? volumeish.join(" | ") : "none"}`);
console.log(`price band fields: ${h.filter((x) => /^PRICEBAND/.test(x)).length}`);
console.log(`\nfirst BIDDAYOFFER data row, field by field:`);
if (firstD) for (let i = 0; i < h.length; i += 1) console.log(`  ${h[i].padEnd(24)} ${firstD[4 + i] ?? ""}`);
