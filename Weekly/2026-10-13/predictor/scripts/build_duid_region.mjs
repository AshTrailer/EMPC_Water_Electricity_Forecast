// Build the DUID to region map from the latest PASA DUID availability file.
//
// The offer tables carry no region field, so selecting Victoria needs an
// external list. MTPASADUIDAVAILABILITY publishes REGIONID beside DUID every
// evening for the coming days. Taking the newest publish covers every unit that
// is currently in the market; units retired before it are reported as missing
// rather than silently dropped.
//
// Output: AEMO_Data/duid_region.csv, two columns, sorted by DUID.

import { createInterface } from "node:readline";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { randomBytes } from "node:crypto";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const OUT = join(ROOT, "AEMO_Data", "duid_region.csv");
const url = "https://nemweb.com.au/Reports/CURRENT/MTPASA_DUIDAvailability/";

const html = await (await fetch(url)).text();
const zips = [...new Set((html.match(/[\w()\-]+\.zip/gi) || []))].sort();
const file = zips[zips.length - 1];
console.log(`source ${file}`);

const tmp = join(tmpdir(), `mtpasa_${randomBytes(4).toString("hex")}.zip`);
writeFileSync(tmp, Buffer.from(await (await fetch(url + file)).arrayBuffer()));

const entries = listEntries(tmp);
const csv = entries.find((e) => /\.csv$/i.test(e.name)) || entries[0];

const idx = new Map();      // DUID -> Set of regions seen
const publish = new Set();
const daySeen = new Set();
let rows = 0;

const rl = createInterface({ input: openEntry(tmp, csv), crlfDelay: Infinity });
for await (const line of rl) {
  if (line[0] !== "I" && line[0] !== "D") continue;
  const c = line.split(",");
  if (line[0] === "I") {
    if (c[2] === "DUIDAVAILABILITY") {
      idx.set("HEAD", c.slice(4));
    }
    continue;
  }
  if (c[2] !== "DUIDAVAILABILITY") continue;
  const f = c.slice(4);
  const duid = f[3];
  const region = f[2];
  if (!duid || !region) continue;
  rows += 1;
  publish.add(f[0]);
  daySeen.add(f[1]);
  if (!idx.has(duid)) idx.set(duid, new Set());
  idx.get(duid).add(region);
}

const head = idx.get("HEAD");
idx.delete("HEAD");

const duids = [...idx.keys()].sort();
const multi = duids.filter((d) => idx.get(d).size > 1);
const byRegion = new Map();
for (const d of duids) {
  const r = [...idx.get(d)].sort().join("+");
  byRegion.set(r, (byRegion.get(r) || 0) + 1);
}

const lines = ["DUID,REGIONID"];
for (const d of duids) lines.push(`${d},${[...idx.get(d)].sort().join("+")}`);
writeFileSync(OUT, `${lines.join("\n")}\n`, "utf8");

console.log(`fields ${head.join(" | ")}`);
console.log(`rows ${rows}   distinct DUID ${duids.length}`);
console.log(`publish datetimes ${publish.size}   day values ${daySeen.size}`);
console.log(`regions: ${[...byRegion].map(([r, n]) => `${r} ${n}`).join("  ")}`);
console.log(`duids seen in more than one region: ${multi.length}${multi.length ? "  " + multi.slice(0, 10).join(" ") : ""}`);
console.log(`wrote ${OUT}`);
