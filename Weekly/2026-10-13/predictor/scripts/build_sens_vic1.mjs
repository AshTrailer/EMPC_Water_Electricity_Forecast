// Build the VIC1 block of PREDISPATCH_SENSITIVITIES for the 60-day window.
//
// E02 needs, for every dispatch run and every target period, the price AEMO's
// own pre-dispatch engine would produce if regional demand moved. The product is
// published one small zip per run, but the ARCHIVE keeps weekly packs, so the
// window is 9 packs plus the runs after the last pack.
//
// The scenario ladder is fixed and is not guessed from the data: AEMO documents
// the regional demand offsets per scenario ID, and VIC1's ladder is scenarios
// 8 to 14 at +100, -100, +200, -200, +500, -500, +1000 MW. Columns are located
// by name from each file's own I record, never by position.
//
// Usage: node build_sens_vic1.mjs [--one]
//        --one  process the newest archive pack only and print a census

import { readFileSync, writeFileSync, existsSync, mkdirSync, createWriteStream } from "node:fs";
import { inflateRawSync } from "node:zlib";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const WIN = join(ROOT, "AEMO_Data", "window_60d_20260811_20261009_vic1");
const OUT = join(WIN, "sens_vic1.csv");
const BASE = "https://nemweb.com.au/Reports";
const one = process.argv.includes("--one");
const KEEP = ["PREDISPATCHSEQNO", "RUNNO", "PERIODID", "INTERVENTION", "DATETIME", "LASTCHANGED"];
const WANT = [];
for (let i = 1; i <= 14; i++) WANT.push(`RRPEEP${i}`);
for (let i = 25; i <= 28; i++) WANT.push(`RRPEEP${i}`);

const get = async (url) => {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`HTTP ${r.status} for ${url}`);
  return Buffer.from(await r.arrayBuffer());
};
const getText = async (url) => {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`HTTP ${r.status} for ${url}`);
  return r.text();
};

function zipEntries(buf) {
  let eocd = -1;
  const stop = Math.max(0, buf.length - 66000);
  for (let i = buf.length - 22; i >= stop; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error("no end-of-central-directory record");
  const n = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  const out = [];
  for (let k = 0; k < n; k++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) throw new Error(`bad central header ${k}`);
    const method = buf.readUInt16LE(off + 10);
    const csize = buf.readUInt32LE(off + 20);
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const commentLen = buf.readUInt16LE(off + 32);
    const lho = buf.readUInt32LE(off + 42);
    const name = buf.toString("latin1", off + 46, off + 46 + nameLen);
    const lnameLen = buf.readUInt16LE(lho + 26);
    const lextraLen = buf.readUInt16LE(lho + 28);
    const dataStart = lho + 30 + lnameLen + lextraLen;
    const raw = buf.subarray(dataStart, dataStart + csize);
    out.push({ name, data: method === 8 ? inflateRawSync(raw) : raw });
    off += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

// The I record names the columns; the D records carry the same order.
function columnIndex(headerLine) {
  const f = headerLine.split(",");
  const idx = {};
  f.forEach((v, i) => (idx[v.trim()] = i));
  const missing = [...KEEP, ...WANT].filter((k) => !(k in idx));
  if (missing.length) throw new Error(`columns missing: ${missing.join(", ")}`);
  return idx;
}

// An archive pack holds one zip per run, so unzip until a CSV comes out.
function processZip(buf, acc, stats, label) {
  for (const e of zipEntries(buf)) {
    if (e.name.toLowerCase().endsWith(".zip")) processZip(e.data, acc, stats, label);
    else scan(e.data.toString("latin1"), acc, stats, label);
  }
}

function scan(text, acc, stats, label) {
  const lines = text.split("\n");
  let idx = null;
  let n = 0;
  for (const raw of lines) {
    if (!raw.startsWith("D,PREDISPATCH,PRICESENSITIVITIES,") &&
        !raw.startsWith("I,PREDISPATCH,PRICESENSITIVITIES,")) continue;
    const f = raw.split(",");
    if (f[0] === "I") { idx = columnIndex(raw); continue; }
    if (!idx) throw new Error(`${label}: a D record precedes the I record`);
    if (f[idx.REGIONID] !== "VIC1") continue;
    const key = `${f[idx.PREDISPATCHSEQNO]}|${f[idx.PERIODID]}`;
    const val = [
      f[idx.PREDISPATCHSEQNO],
      f[idx.RUNNO],
      f[idx.PERIODID],
      f[idx.INTERVENTION],
      f[idx.DATETIME].replace(/"/g, ""),
      f[idx.LASTCHANGED].replace(/"/g, ""),
      ...WANT.map((w) => f[idx[w]]),
    ].join(",");
    acc.set(key, val);
    n++;
  }
  stats.push([label, n, acc.size]);
}

const acc = new Map();
const stats = [];

if (one) {
  const html = await getText(`${BASE}/ARCHIVE/Predispatch_Sensitivities/`);
  const zips = [...new Set(html.match(/[A-Za-z0-9_.-]+\.zip/g) || [])].sort();
  const target = zips[zips.length - 1];
  const buf = await get(`${BASE}/ARCHIVE/Predispatch_Sensitivities/${target}`);
  console.log(`${target}  ${(buf.length / 1e6).toFixed(1)} MB`);
  processZip(buf, acc, stats, target);
  stats.forEach((s) => console.log(`  ${s[0]}: ${s[1]} VIC1 rows, accumulator ${s[2]}`));
  for (const [k, v] of [...acc.entries()].slice(0, 3)) console.log(`   ${k} -> ${v}`);
  process.exit(0);
}

// ---- archive packs that cover the window --------------------------------
const html = await getText(`${BASE}/ARCHIVE/Predispatch_Sensitivities/`);
const packs = [...new Set(html.match(/[A-Za-z0-9_.-]+\.zip/g) || [])]
  .filter((z) => {
    const m = z.match(/_(\d{8})_(\d{8})\.zip$/);
    return m && m[2] >= "20260811" && m[1] <= "20261012";
  })
  .sort();
console.log(`archive packs covering the window: ${packs.length}`);
for (const p of packs) console.log(`  ${p}`);

for (const p of packs) {
  const buf = await get(`${BASE}/ARCHIVE/Predispatch_Sensitivities/${p}`);
  processZip(buf, acc, stats, p);
  const s = stats[stats.length - 1];
  console.log(`  ${p}  ${(buf.length / 1e6).toFixed(1)} MB  rows ${s[1]}  total ${s[2]}`);
}

// ---- runs after the last pack, from CURRENT -----------------------------
const cur = await getText(`${BASE}/CURRENT/Predispatch_Sensitivities/`);
const runs = [...new Set(cur.match(/PUBLIC_PREDISPATCH_SENSITIVITIES_(\d{14})_\d+\.zip/g) || [])]
  .map((z) => ({ z, t: z.match(/_(\d{14})_/)[1] }))
  .filter((r) => r.t >= "20261006120000" && r.t <= "20261009235959")
  .sort((a, b) => (a.t < b.t ? -1 : 1));
console.log(`\nCURRENT runs in the tail: ${runs.length}`);
for (const r of runs) {
  const buf = await get(`${BASE}/CURRENT/Predispatch_Sensitivities/${r.z}`);
  processZip(buf, acc, stats, r.z);
}
console.log(`CURRENT tail rows ${stats.slice(packs.length).reduce((s, a) => s + a[1], 0)}, total ${acc.size}`);

// ---- write --------------------------------------------------------------
const head = [...KEEP, ...WANT].join(",");
const rows = [...acc.values()].sort((a, b) => (a < b ? -1 : 1));
const ws = createWriteStream(OUT, "utf8");
ws.write(head + "\n");
for (const r of rows) ws.write(r + "\n");
await new Promise((res) => ws.end(res));
console.log(`\nwrote ${OUT}, ${rows.length} rows`);
