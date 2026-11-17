// Read the two predispatch tables out of one report and print their headers.
//
// The report is a nested zip, so the member is inflated in memory and the csv
// is scanned for the I rows that carry the column names. Prints the column list
// with positions so the extractor can map by name rather than by offset.

import { readFileSync } from "node:fs";
import { entryBuffer, listEntriesFromBuffer } from "./lib/zip_stream.mjs";

const PACK = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\AEMO_Data\\predispatch_weeks\\PUBLIC_PREDISPATCH_20260906_20260912.zip";

const pack = readFileSync(PACK);
const members = listEntriesFromBuffer(pack);
const member = members[0];
const inner = entryBuffer(pack, member);
const files = listEntriesFromBuffer(inner);
const csv = entryBuffer(inner, files[0]).toString("latin1");

const lines = csv.split(/\r?\n/);
console.log(`member ${member.name}`);
console.log(`csv ${csv.length} chars, ${lines.length} lines`);

const WANT = ["REGIONSUM", "INTERCONNECTORRES", "PRICESOLUTION"];
const headers = {};
const counts = {};
for (const line of lines) {
  if (line.charCodeAt(0) === 73) {                    // I row
    const c = line.split(",");
    const table = c[2];
    if (!WANT.includes(table)) continue;
    if (!headers[table]) {
      headers[table] = c.slice(4);
      console.log(`\n=== I ${table} v${c[3]} (${c.length - 4} columns) ===`);
      c.slice(4).forEach((n, i) => {
        if (/DEMAND|UIGF|RRP|INTERCONNECTOR|MWFLOW|LIMIT|REGION|PERIOD|PREDISPATCHSEQ|LOSS/i.test(n)) {
          console.log(`  ${String(i).padStart(3)} ${n}`);
        }
      });
      console.log(`  all: ${c.slice(4).join(",")}`);
    }
  } else if (line.charCodeAt(0) === 68) {             // D row
    const c = line.split(",");
    const table = c[2];
    counts[table] = (counts[table] || 0) + 1;
  }
}
console.log("\nrow counts per table (first 12):");
for (const [k, v] of Object.entries(counts).slice(0, 12)) console.log(`  ${k} ${v}`);

// one sample data row for each wanted table
for (const table of WANT) {
  if (!headers[table]) continue;
  const line = lines.find((l) => l.startsWith(`D,PREDISPATCH,${table},`));
  if (!line) continue;
  const c = line.split(",");
  console.log(`\n--- sample ${table} ---`);
  const h = headers[table];
  for (let i = 0; i < h.length; i += 1) {
    if (/DEMAND|UIGF|RRP|INTERCONNECTOR|MWFLOW|LIMIT|REGION|PERIOD|PREDISPATCHSEQ|LOSS|INTERVENTION/i.test(h[i])) {
      console.log(`  ${h[i]} = ${c[4 + i]}`);
    }
  }
}
