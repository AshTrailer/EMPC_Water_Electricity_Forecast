/**
 * Backfill the missing P5MIN five minute forecasts for the 60 day window.
 *
 * NEMWEB keeps one zip per day per product. The P5MIN daily zip is a zip of
 * 288 inner zips, each holding one report CSV with several tables. Only
 * P5MIN,REGIONSOLUTION carries the regional price, and only VIC1 is wanted.
 *
 * The project's own Python backfill needs pandas, which this machine does not
 * have, so the zip reading is done here with node:zlib.
 *
 *   node fetch_p5min_days.mjs --start 20260811 --end 20260824
 *
 * Writes AEMO_Data/window_60d_20260811_20261009/p5min_vic1_partial/
 *        p5min_<start>_<end>.csv
 * with the same schema as the neighbouring files:
 *   effective_time,region_id,interval_datetime,rrp,total_demand,intervention
 */
import { inflateRawSync } from "node:zlib";
import { writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";

const BASE = "https://www.nemweb.com.au/Reports/ARCHIVE/P5_Reports/PUBLIC_P5MIN_";
const OUT_DIR = "C:/Ash/Projects/EMPC_Water_Electricity_Forecast/AEMO_Data/" +
   "window_60d_20260811_20261009/p5min_vic1_partial";
const REGION = "VIC1";
const UA = { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) aemo-p5-backfill/1.0" };

const argv = process.argv.slice(2);
const arg = (k) => { const i = argv.indexOf(k); return i >= 0 ? argv[i + 1] : null; };
const start = arg("--start"), end = arg("--end");
if (!start || !end) { console.error("need --start YYYYMMDD --end YYYYMMDD"); process.exit(2); }
// AEMO files a report by generation time, so the batch effective at midnight of
// the first day sits in the previous day's zip. --keep-from drops everything
// before the window so that day can be fetched without dragging in its own day.
const keepFrom = arg("--keep-from");

const say = (...a) => { console.log(...a); };

/* ---- minimal zip reader: central directory, then one entry at a time ---- */
function readZipEntries(buf) {
   const eocdSig = 0x06054b50;
   let p = buf.length - 22;
   while (p >= 0 && buf.readUInt32LE(p) !== eocdSig) p--;
   if (p < 0) throw new Error("no end of central directory");
   const count = buf.readUInt16LE(p + 10);
   let q = buf.readUInt32LE(p + 16);
   const entries = [];
   for (let i = 0; i < count; i++) {
      if (buf.readUInt32LE(q) !== 0x02014b50) throw new Error("bad central header at " + q);
      const method = buf.readUInt16LE(q + 10);
      const csize = buf.readUInt32LE(q + 20);
      const usize = buf.readUInt32LE(q + 24);
      const nlen = buf.readUInt16LE(q + 28);
      const elen = buf.readUInt16LE(q + 30);
      const clen = buf.readUInt16LE(q + 32);
      const lho = buf.readUInt32LE(q + 42);
      const name = buf.toString("latin1", q + 46, q + 46 + nlen);
      entries.push({ name, method, csize, usize, lho });
      q += 46 + nlen + elen + clen;
   }
   return entries;
}

function readZipEntry(buf, e) {
   const nlen = buf.readUInt16LE(e.lho + 26);
   const elen = buf.readUInt16LE(e.lho + 28);
   const dataAt = e.lho + 30 + nlen + elen;
   const raw = buf.subarray(dataAt, dataAt + e.csize);
   if (e.method === 0) return raw;
   if (e.method === 8) return inflateRawSync(raw);
   throw new Error("unsupported compression method " + e.method);
}

/* ---- pull the VIC1 rows out of one report CSV ---- */
function extractReport(csvText, fallbackEffective) {
   const lines = csvText.split("\n");
   let cols = null, atEff = -1, atInt = -1, atReg = -1, atRrp = -1, atDem = -1, atIvn = -1;
   const out = [];
   for (const line of lines) {
      if (line.startsWith("I,P5MIN,REGIONSOLUTION,")) {
         cols = splitCsv(line).slice(3);            // drop I, table, version
         atEff = cols.indexOf("RUN_DATETIME");
         atIvn = cols.indexOf("INTERVENTION");
         atInt = cols.indexOf("INTERVAL_DATETIME");
         atReg = cols.indexOf("REGIONID");
         atRrp = cols.indexOf("RRP");
         atDem = cols.indexOf("TOTALDEMAND");
         if (atReg < 0 || atRrp < 0) throw new Error("REGIONSOLUTION header changed");
         continue;
      }
      if (cols === null || !line.startsWith("D,P5MIN,REGIONSOLUTION,")) continue;
      const f = splitCsv(line).slice(3);
      if (f[atReg] !== REGION) continue;
      out.push([fallbackEffective, REGION, fixTs(f[atInt]), f[atRrp], f[atDem],
         atIvn >= 0 ? f[atIvn] : "0"]);
   }
   return out;
}

/** AEMO quoting: fields may be wrapped in double quotes, no embedded commas. */
function splitCsv(line) {
   const out = [];
   let cur = "", inQ = false;
   for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (c === '"') { inQ = !inQ; continue; }
      if (c === "," && !inQ) { out.push(cur); cur = ""; continue; }
      cur += c;
   }
   out.push(cur);
   return out;
}

const stamp = (s) => `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)} ` +
   `${s.slice(8, 10)}:${s.slice(10, 12)}:00`;

/** AEMO writes 2026/08/11 00:05:00; the neighbouring files use dashes. */
const fixTs = (s) => s.replace(/\//g, "-");

const days = [];
for (let d = new Date(Date.UTC(+start.slice(0, 4), +start.slice(4, 6) - 1, +start.slice(6, 8)));
   d <= new Date(Date.UTC(+end.slice(0, 4), +end.slice(4, 6) - 1, +end.slice(6, 8)));
   d.setUTCDate(d.getUTCDate() + 1)) {
   days.push(d.toISOString().slice(0, 10).replace(/-/g, ""));
}

if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true });
const rows = [];
let done = 0;

for (const day of days) {
   const url = BASE + day + ".zip";
   const t0 = Date.now();
   const res = await fetch(url, { headers: UA });
   if (!res.ok) { say(`${day}  HTTP ${res.status}, skipped`); continue; }
   const buf = Buffer.from(await res.arrayBuffer());
   const inner = readZipEntries(buf).filter((e) => e.name.toLowerCase().endsWith(".zip"));
   let n = 0;
   for (const e of inner) {
      const m = e.name.match(/PUBLIC_P5MIN_(\d{12})_/);
      const eff = m ? stamp(m[1]) : null;
      if (!eff) throw new Error("cannot read the batch key from " + e.name);
      // two levels: the daily zip holds one zip per report, which holds one CSV
      const innerBuf = readZipEntry(buf, e);
      for (const fe of readZipEntries(innerBuf)) {
         if (!fe.name.toLowerCase().endsWith(".csv")) continue;
         if (keepFrom !== null && eff < keepFrom) continue;
         const csv = readZipEntry(innerBuf, fe).toString("utf8");
         const got = extractReport(csv, eff);
         for (const r of got) rows.push(r);
         n += got.length;
      }
   }
   done++;
   say(`${day}  inner ${inner.length}  VIC1 rows ${n}  ` +
      `${((Date.now() - t0) / 1000).toFixed(1)}s  total ${rows.length}`);
}

const outPath = join(OUT_DIR, `p5min_${start}_${end}.csv`);
const head = "effective_time,region_id,interval_datetime,rrp,total_demand,intervention\n";
writeFileSync(outPath, head + rows.map((r) => r.join(",")).join("\n") + "\n", "utf8");
say(`wrote ${outPath}`);
say(`days ok ${done} of ${days.length}, rows ${rows.length}`);
