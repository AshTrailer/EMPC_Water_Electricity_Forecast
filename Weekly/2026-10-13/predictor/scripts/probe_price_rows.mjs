// Print every column of one unit's price rows, to find what separates them.
//
// Fourteen price rows share one submission key, with different band prices.
// Some column that the join ignored must distinguish them, and printing the rows
// field by field is the only way to name it.

import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const file = process.argv[2];
const want = process.argv[3] || "HBESS1";
const csv = listEntries(file).find((e) => /\.csv$/i.test(e.name));

const head = new Map();
const rows = [];
const rl = createInterface({ input: openEntry(file, csv), crlfDelay: Infinity });
for await (const line of rl) {
  if (line[0] !== "I" && line[0] !== "D") continue;
  const c = line.split(",");
  const t = c[2];
  if (line[0] === "I") {
    head.set(t, c.slice(4));
    continue;
  }
  if (t !== "BIDDAYOFFER_D") continue;
  const f = c.slice(4);
  if (f[1] !== want) continue;
  rows.push(f);
}

const h = head.get("BIDDAYOFFER_D");
console.log(`${rows.length} rows for ${want}`);
const cols = h.map((name, i) => i).filter((i) => {
  const vals = new Set(rows.map((r) => r[i]));
  return vals.size > 1;
});
console.log(`columns that vary: ${cols.map((i) => h[i]).join(" | ")}`);

for (const r of rows.slice(0, 20)) {
  console.log("");
  for (let i = 0; i < h.length; i += 1) {
    if (r[i] === "" || r[i] === undefined) continue;
    console.log(`  ${h[i].padEnd(22)} ${r[i]}`);
  }
}
