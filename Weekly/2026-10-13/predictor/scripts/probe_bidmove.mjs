// Whether Bidmove_Complete carries a version key on both offer tables.
//
// The daily sparse snapshot gives prices and volumes in two tables with no
// shared version column, so the join would have to be guessed from timestamps.
// Bidmove is the full model export; if both of its tables carry OFFERDATE and
// BIDVERSIONNO the join is exact. File size decides whether that is affordable
// for sixty days.

import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const url = "https://nemweb.com.au/Reports/CURRENT/Bidmove_Complete/";
const html = await (await fetch(url)).text();
const zips = [...new Set((html.match(/[\w()\-]+\.zip/gi) || []))].sort();
console.log(`Bidmove_Complete: ${zips.length} zips`);
console.log(`  first ${zips[0]}`);
console.log(`  last  ${zips[zips.length - 1]}`);

const file = zips[zips.length - 1];
const head = await fetch(url + file, { method: "HEAD" });
console.log(`  ${file}  content-length ${head.headers.get("content-length")}`);

const res = await fetch(url + file);
const buf = Buffer.from(await res.arrayBuffer());
console.log(`  downloaded ${buf.length} bytes`);
const tmp = `${process.env.TEMP}\\bidmove_probe.zip`;
const { writeFileSync, rmSync } = await import("node:fs");
writeFileSync(tmp, buf);

const entries = listEntries(tmp);
console.log(`\nentries:`);
for (const e of entries) console.log(`  ${e.name}  comp ${e.compSize}  raw ${e.size}`);

const csv = entries.find((e) => /\.csv$/i.test(e.name)) || entries[0];
const head2 = new Map();
const sample = new Map();
const counts = new Map();
const rl = createInterface({ input: openEntry(tmp, csv), crlfDelay: Infinity });
for await (const line of rl) {
  const tag = line[0];
  if (tag !== "I" && tag !== "D") continue;
  const c = line.split(",");
  const t = c[2];
  if (typeof t !== "string") continue;
  if (tag === "I") head2.set(t, c.slice(4));
  else {
    counts.set(t, (counts.get(t) || 0) + 1);
    if (!sample.has(t)) sample.set(t, c.slice(4));
  }
}

for (const [t, f] of head2) {
  console.log(`\n=== ${t}  ${f.length} fields  ${counts.get(t) || 0} rows`);
  console.log(`  ${f.join(" | ")}`);
  if (sample.has(t)) console.log(`  row: ${sample.get(t).join(" | ")}`);
}
rmSync(tmp, { force: true });
