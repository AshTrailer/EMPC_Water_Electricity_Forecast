// Download one NEXT_DAY_OFFER_ENERGY_SPARSE file and report what is inside it.
//
// The question this answers is whether the daily offer snapshot carries the
// ten price and volume bands per DUID that a supply curve needs, and how many
// DUIDs a day it covers. The zip is kept so the same file can be re-read
// without a second download.
//
// Usage: node probe_offer_files.mjs [yyyyMMdd]   (default 20261015)

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const OUT = join(ROOT, "AEMO_Data", "_probe_offers");
const day = process.argv[2] || "20261015";
const name = `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}_`;
const listing = "https://nemweb.com.au/Reports/CURRENT/Next_Day_Offer_Energy_SPARSE/";

if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });

// The generation part of the file name is not predictable, so the directory
// listing is the index. One fetch, then a regex over the links.
const html = await (await fetch(listing)).text();
const re = new RegExp(`${name}\\d+\\.zip`, "g");
const hits = [...new Set(html.match(re) || [])];
if (hits.length === 0) {
  console.log(`no file for ${day} under ${listing}`);
  process.exit(1);
}
const file = hits[0];
console.log(`listing hit: ${file}`);

const path = join(OUT, file);
if (existsSync(path)) {
  console.log(`already have ${path}, ${readFileSync(path).length} bytes`);
} else {
  const r = await fetch(listing + file);
  if (!r.ok) {
    console.log(`HTTP ${r.status} for ${listing + file}`);
    process.exit(1);
  }
  const buf = Buffer.from(await r.arrayBuffer());
  writeFileSync(path, buf);
  console.log(`wrote ${path}, ${buf.length} bytes`);
}
