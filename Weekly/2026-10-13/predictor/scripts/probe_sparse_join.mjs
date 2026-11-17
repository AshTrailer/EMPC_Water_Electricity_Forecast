// Whether the daily offer file gives a version timeline and a usable join.
//
// Bidmove turned out to be a snapshot of the day's final state, which cannot
// answer "what was known at this origin". The daily file is the alternative and
// carries a lodgement history. Two things have to be checked: that each unit has
// many distinct lodgement times, and that the price table's timestamp appears as
// the volume table's OFFERDATETIME so the join is exact.

import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const file = process.argv[2];
const csv = listEntries(file).find((e) => /\.csv$/i.test(e.name));
const want = process.argv[3] || "HBESS1";

const priceTimes = new Map();     // duid -> Set of times
const availTimes = new Map();     // duid -> Map time -> periods
const head = new Map();
let energyPrice = 0;
let energyAvail = 0;

const rl = createInterface({ input: openEntry(file, csv), crlfDelay: Infinity });
for await (const line of rl) {
  const ch = line.charCodeAt(0);
  if (ch !== 73 && ch !== 68) continue;
  const c = line.split(",");
  const t = c[2];
  if (ch === 73) {
    head.set(t, c.slice(4));
    continue;
  }
  if (c[5] !== "ENERGY") continue;
  const duid = c[4];
  if (t === "BIDDAYOFFER") {
    const od = c[7];
    if (!priceTimes.has(duid)) priceTimes.set(duid, new Map());
    priceTimes.get(duid).set(`${od}|v${c[8]}|${c[35]}`, `${od}|v${c[8]}`);
    energyPrice += 1;
  } else if (t === "BIDOFFERPERIOD_SPARSE") {
    const odt = c[7];
    if (!availTimes.has(duid)) availTimes.set(duid, new Map());
    const g = availTimes.get(duid);
    if (!g.has(odt)) g.set(odt, { rows: 0, pmin: 1e9, pmax: -1 });
    const gg = g.get(odt);
    gg.rows += 1;
    gg.pmin = Math.min(gg.pmin, Number(c[8]));
    gg.pmax = Math.max(gg.pmax, Number(c[8]));
    energyAvail += 1;
  }
}

console.log(`head BIDDAYOFFER: ${head.get("BIDDAYOFFER")?.join(" | ")}`);
console.log(`head BIDOFFERPERIOD_SPARSE: ${head.get("BIDOFFERPERIOD_SPARSE")?.join(" | ")}`);
console.log(`energy price rows ${energyPrice}, energy avail rows ${energyAvail}`);
console.log(`units with price history ${priceTimes.size}, with avail history ${availTimes.size}`);

const priceHist = new Map();
for (const m of priceTimes.values()) priceHist.set(m.size, (priceHist.get(m.size) || 0) + 1);
const availHist = new Map();
for (const m of availTimes.values()) availHist.set(m.size, (availHist.get(m.size) || 0) + 1);
console.log(`distinct price lodgements per unit: ${[...priceHist].sort((a, b) => b[1] - a[1]).slice(0, 8).map(([k, n]) => `${k}:${n}`).join(" ")}`);
console.log(`distinct avail lodgements per unit: ${[...availHist].sort((a, b) => b[1] - a[1]).slice(0, 8).map(([k, n]) => `${k}:${n}`).join(" ")}`);

const pt = priceTimes.get(want);
const at = availTimes.get(want);
console.log(`\n${want}: ${pt ? pt.size : 0} price lodgements, ${at ? at.size : 0} avail lodgements`);
if (pt) console.log(`  price: ${[...pt.keys()].slice(0, 8).join("  ")}`);
if (at) console.log(`  avail: ${[...at.keys()].slice(0, 8).join("  ")}`);
if (at) {
  const g = [...at.entries()].slice(0, 8).map(([k, v]) => `${k}->${v.rows}p(${v.pmin}..${v.pmax})`);
  console.log(`  avail groups: ${g.join("  ")}`);
}
