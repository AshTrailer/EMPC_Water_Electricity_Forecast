// Full field list and a few sample rows for the two offer tables.
//
// N17 recorded that the daily snapshot carries ten prices and ten volumes, but
// not which table holds which. That decides the loader shape, so it is read off
// the header rather than assumed.

import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const path = process.argv[2];
const entries = listEntries(path);
console.log(entries.map((e) => `${e.name}  ${e.compSize}  ${e.size}  method ${e.method}`).join("\n"));

const csv = entries.find((e) => /\.csv$/i.test(e.name)) || entries[0];
const head = new Map();
const samples = new Map();
let rows = 0;

const rl = createInterface({ input: openEntry(path, csv), crlfDelay: Infinity });
for await (const line of rl) {
  rows += 1;
  const tag = line[0];
  if (tag !== "I" && tag !== "D") continue;
  const c = line.split(",");
  const t = c[2];
  if (typeof t !== "string") continue;
  if (tag === "I") {
    head.set(t, c.slice(4));
  } else if ((samples.get(t) || []).length < 3) {
    if (!samples.has(t)) samples.set(t, []);
    samples.get(t).push(c.slice(4));
  }
}

console.log(`\nrows ${rows}`);
for (const [t, f] of head) {
  console.log(`\n=== ${t}  ${f.length} fields`);
  console.log(f.map((x, i) => `${String(i).padStart(2)} ${x}`).join("\n"));
  for (const s of samples.get(t) || []) {
    console.log(`  row: ${s.slice(0, 12).join(" | ")}${s.length > 12 ? " ..." : ""}`);
  }
}
