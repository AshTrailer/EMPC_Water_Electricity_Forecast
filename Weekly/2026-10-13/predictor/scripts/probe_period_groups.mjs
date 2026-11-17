// How the period table groups its rows.
//
// The nightly file needs OFFERDATE and VERSIONNO to line price bands up with
// band volumes. Printing the distinct combinations for one unit, with the period
// range each covers, shows whether the two tables share a key at all.

import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const file = process.argv[2];
const want = process.argv[3] || "HBESS1";
const csv = listEntries(file).find((e) => /\.csv$/i.test(e.name));

const groups = new Map();
let n = 0;
const rl = createInterface({ input: openEntry(file, csv), crlfDelay: Infinity });
for await (const line of rl) {
  if (line[0] !== "D") continue;
  const c = line.split(",");
  if (c[2] !== "BIDPEROFFER_D") continue;
  if (c[5] !== want) continue;
  if (c[6] !== "ENERGY") continue;
  const key = `${c[8]}|v${c[10]}|${c[32]}`;
  n += 1;
  if (!groups.has(key)) groups.set(key, { rows: 0, pmin: 1e9, pmax: -1, maxavail: new Set() });
  const g = groups.get(key);
  g.rows += 1;
  g.pmin = Math.min(g.pmin, Number(c[9]));
  g.pmax = Math.max(g.pmax, Number(c[9]));
  g.maxavail.add(c[11]);
}

console.log(`${want}: ${n} ENERGY period rows in ${groups.size} groups`);
for (const [k, g] of [...groups].slice(0, 12)) {
  console.log(`  ${k}  rows ${g.rows}  periods ${g.pmin}..${g.pmax}  maxavail ${[...g.maxavail].slice(0, 4).join("/")}`);
}
