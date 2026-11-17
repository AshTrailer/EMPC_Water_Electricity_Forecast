// Inspect one predispatch week pack: what the members are and which tables
// carry the regional availability and the interconnector flow.
//
// Prints the first member names, and for the first member either its head as
// text or, when it is itself a zip, the names of its members.

import { readFileSync } from "node:fs";
import { inflateRawSync } from "node:zlib";
import { listEntries } from "./lib/zip_stream.mjs";

const FILE = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\AEMO_Data\\predispatch_weeks\\PUBLIC_PREDISPATCH_20260906_20260912.zip";

const pack = readFileSync(FILE);
const entries = listEntries(FILE);
console.log(`members ${entries.length}`);
for (const e of entries.slice(0, 5)) {
  console.log(`  ${e.name}  method ${e.method}  comp ${e.compSize}  size ${e.size}`);
}
console.log(`  ... last ${entries[entries.length - 1].name}`);

function extract(buf, entry) {
  const fd = buf.subarray(entry.offset, entry.offset + 30);
  if (fd.readUInt32LE(0) !== 0x04034b50) throw new Error("bad local header");
  const start = entry.offset + 30 + fd.readUInt16LE(26) + fd.readUInt16LE(28);
  const raw = buf.subarray(start, start + entry.compSize);
  return entry.method === 0 ? Buffer.from(raw) : inflateRawSync(raw);
}

const first = extract(pack, entries[0]);
console.log(`\nfirst member inflates to ${first.length} bytes`);
const head = first.subarray(0, 400).toString("latin1");
console.log(head.replace(/\r/g, "").split("\n").slice(0, 4).join("\n"));

if (first.readUInt32LE(0) === 0x04034b50) {
  console.log("\nfirst member is a zip, members:");
  for (const e of listEntriesFromBuffer(first).slice(0, 12)) console.log(`  ${e.name} ${e.size}`);
}

function listEntriesFromBuffer(buf) {
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0 && i >= buf.length - 22 - 65535; i -= 1) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) return [];
  const count = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  const out = [];
  for (let i = 0; i < count; i += 1) {
    const method = buf.readUInt16LE(p + 10);
    const compSize = buf.readUInt32LE(p + 20);
    const size = buf.readUInt32LE(p + 24);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const commentLen = buf.readUInt16LE(p + 32);
    const offset = buf.readUInt32LE(p + 42);
    out.push({ name: buf.toString("latin1", p + 46, p + 46 + nameLen), method, compSize, size, offset });
    p += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}
