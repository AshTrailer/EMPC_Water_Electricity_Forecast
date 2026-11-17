// Read Victoria's scheduled offer stack at the generation the market cleared.
//
// The stack that prices a region is the scheduled fleet's, because a semi
// scheduled unit is dispatched to its availability rather than to its bid. The
// quantity that fleet serves is the dispatchable generation, which the
// predispatch report publishes for every origin and target, so the price is the
// stack read there, not at regional demand.
//
// The daily offer file is a snapshot taken after the trading day ends and holds
// the whole version history, rebids included, so the stack has to be taken as of
// each origin: per unit and period, the newest lodgement at or before the origin.
// Taking the last lodgement of the day would read bids placed after the forecast
// was made.
//
// Three readings are recorded for every predispatch row, all from the same stack:
// at the dispatchable generation, at demand, and at demand plus the net
// interchange. Each unit's ten bands are brought back to its stated maximum
// availability first, because storage reports its full rating in several bands.
//
// Writes research/verify/e09_candidate.bin.
//
// Usage: node build_e09_candidate.mjs [--from 20260908] [--to 20261009]

import { existsSync, openSync, writeSync, closeSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_daily");
const OUT = join(ROOT, "Weekly", "2026-10-13", "research", "verify");

const argv = process.argv.slice(2);
const arg = (name, dflt) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : dflt;
};
const DAY_FROM = Number(arg("--from", "20260908"));
const DAY_TO = Number(arg("--to", "20261009"));

const BANDS = 10;
const PERIODS = 288;
const COLS = 13;
const COL_NAMES = ["origin", "target", "q_dispatchable", "price_at_dispatchable",
  "price_at_demand", "price_at_total_generation", "rrp", "demand", "dispatchable",
  "net_interchange", "ss_solar", "ss_wind", "lodge_age_min"];

// ------------------------------------------------------------------ classes
const cls = new Map();
for (const line of readFileSync(join(ROOT, "AEMO_Data", "duid_unit_class.csv"), "utf8").split(/\r?\n/).slice(1)) {
  if (!line) continue;
  const c = line.split(",");
  if (c[0]) cls.set(c[0], c[4] || "");
}
const isSemi = (d) => (cls.get(d) || "").toLowerCase().includes("semi");

const region = new Map();
for (const f of ["duid_region_registration.csv", "duid_region.csv"]) {
  const p = join(ROOT, "AEMO_Data", f);
  if (!existsSync(p)) continue;
  for (const line of readFileSync(p, "utf8").split(/\r?\n/).slice(1)) {
    const [d, r] = line.split(",");
    if (d && d !== "-" && r && !region.has(d)) region.set(d, r);
  }
}
const vic = new Set([...region].filter(([, r]) => r === "VIC1").map(([d]) => d));

function stampSlash(s) {
  const b = s.charCodeAt(0) === 34 ? 1 : 0;
  return Date.UTC(
    Number(s.substr(b, 4)), Number(s.substr(b + 5, 2)) - 1, Number(s.substr(b + 8, 2)),
    Number(s.substr(b + 11, 2)), Number(s.substr(b + 14, 2)), Number(s.substr(b + 17, 2)),
  ) / 60000;
}

// ------------------------------------------------------------------- panel
const meta = JSON.parse(readFileSync(join(OUT, "e09_pd_panel.json"), "utf8"));
const nCols = meta.region_cols.length;
const raw = readFileSync(join(OUT, "e09_pd_region.bin"));
const nRows = raw.length / (8 * nCols);
const panel = new Float64Array(nRows * nCols);
for (let i = 0; i < nRows * nCols; i += 1) panel[i] = raw.readDoubleLE(8 * i);

// Victoria only, grouped by the trading day of the target, then by origin.
const byDay = new Map();
let victoriaRows = 0;
for (let i = 0; i < nRows; i += 1) {
  const base = i * nCols;
  if (panel[base + 2] !== 1) continue;
  const origin = panel[base];
  const target = panel[base + 1];
  const day = Math.floor(target / 1440);
  if (!byDay.has(day)) byDay.set(day, new Map());
  const byOrigin = byDay.get(day);
  if (!byOrigin.has(origin)) byOrigin.set(origin, []);
  byOrigin.get(origin).push(base);
  victoriaRows += 1;
}
console.log(`panel rows ${nRows}, Victoria rows ${victoriaRows}`);

// ------------------------------------------------------------ offer reading
async function readDay(file) {
  const csv = listEntries(file).find((e) => /\.csv$/i.test(e.name));
  const ladders = new Map();
  const vols = new Map();
  let trading = 0;
  const rl = createInterface({ input: openEntry(file, csv), crlfDelay: Infinity });
  for await (const line of rl) {
    if (line.charCodeAt(0) !== 68) continue;
    const c = line.split(",");
    const table = c[2];
    const duid = c[4];
    if (!vic.has(duid)) continue;
    const dir = table === "BIDDAYOFFER" ? c[35] : c[29];
    if (dir === "LOAD") continue;
    const key = `${duid}|${dir}`;
    if (table === "BIDDAYOFFER") {
      const prices = new Float64Array(BANDS);
      for (let k = 0; k < BANDS; k += 1) prices[k] = Number(c[12 + k]);
      if (!ladders.has(key)) ladders.set(key, []);
      ladders.get(key).push({ t: stampSlash(c[7]), prices });
    } else if (table === "BIDOFFERPERIOD_SPARSE") {
      trading = stampSlash(c[6]);
      const bands = new Float32Array(BANDS);
      let sum = 0;
      for (let k = 0; k < BANDS; k += 1) {
        const x = Number(c[18 + k]);
        bands[k] = Number.isFinite(x) ? x : 0;
        sum += bands[k];
      }
      // MAXAVAIL is not usable as a cap: it reads zero for the largest coal
      // units in this file, which would remove thousands of megawatts of the
      // cheapest capacity. The ten bands are the market's own bid curve, so they
      // are used as published.
      const scale = 1;
      void sum;
      const pFrom = Number(c[8]);
      const pTo = Number(c[9]) || pFrom;
      if (!vols.has(key)) vols.set(key, []);
      vols.get(key).push({ t: stampSlash(c[7]), from: pFrom, to: pTo, bands, scale });
    }
  }
  const units = [];
  for (const [key, rows] of vols) {
    const duid = key.slice(0, key.indexOf("|"));
    if (isSemi(duid)) continue;                 // the quantity excludes their output
    const lad = (ladders.get(key) || []).slice().sort((a, b) => a.t - b.t);
    const per = new Array(PERIODS + 1);
    for (const r of rows) {
      const hi = Math.min(r.to, PERIODS);
      for (let p = Math.max(1, r.from); p <= hi; p += 1) {
        if (!per[p]) per[p] = [];
        per[p].push(r);
      }
    }
    for (let p = 1; p <= PERIODS; p += 1) if (per[p]) per[p].sort((a, b) => a.t - b.t);
    units.push({ duid, lad, per });
  }
  return { trading, units };
}

function ladderAt(lad, t) {
  let lo = 0;
  let hi = lad.length - 1;
  let pick = null;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (lad[mid].t <= t) { pick = lad[mid]; lo = mid + 1; } else { hi = mid - 1; }
  }
  return pick;
}

function rowAt(rows, origin) {
  let lo = 0;
  let hi = rows.length - 1;
  let pick = null;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (rows[mid].t <= origin) { pick = rows[mid]; lo = mid + 1; } else { hi = mid - 1; }
  }
  return pick;
}

// --------------------------------------------------------------- curve work
const segPrice = [];
const segMw = [];
const segPre = [];
const cum = new Float64Array(8192);
const curvePrice = new Float64Array(8192);

/** The stack in force at an origin, for one period. Returns segment count. */
function buildLadder(day, period, origin) {
  segPrice.length = 0;
  segMw.length = 0;
  segPre.length = 0;
  for (const u of day.units) {
    const rows = u.per[period];
    if (!rows) continue;
    const pick = rowAt(rows, origin);
    if (!pick) continue;
    const lad = ladderAt(u.lad, pick.t);
    if (!lad) continue;
    for (let b = 0; b < BANDS; b += 1) {
      const mw = pick.bands[b] * pick.scale;
      if (mw > 0) {
        segPrice.push(lad.prices[b]);
        segMw.push(mw);
      }
    }
  }
  const n = segPrice.length;
  if (n === 0) return 0;
  for (let i = 0; i < n; i += 1) segPre.push(i);
  segPre.sort((a, b) => segPrice[a] - segPrice[b]);
  let s = 0;
  for (let i = 0; i < n; i += 1) {
    const j = segPre[i];
    s += segMw[j];
    curvePrice[i] = segPrice[j];
    cum[i] = s;
  }
  return n;
}

function priceAt(n, q) {
  if (n === 0 || !Number.isFinite(q)) return NaN;
  if (q <= cum[0]) return curvePrice[0];
  let lo = 0;
  let hi = n - 1;
  let pick = -1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (cum[mid] >= q) { pick = mid; hi = mid - 1; } else { lo = mid + 1; }
  }
  return pick >= 0 ? curvePrice[pick] : curvePrice[n - 1];
}

/** Age in minutes of the oldest lodgement used, as a look-ahead guard. */
function lodgeAge(day, period, origin) {
  let oldest = origin;
  for (const u of day.units) {
    const rows = u.per[period];
    if (!rows) continue;
    const pick = rowAt(rows, origin);
    if (pick && pick.t < oldest) oldest = pick.t;
  }
  return origin - oldest;
}

// ------------------------------------------------------------------- output
const fd = openSync(join(OUT, "e09_candidate.bin"), "w");
const rowsOut = [];
let shortStack = 0;
let written = 0;
let maxAge = 0;

function flush() {
  if (rowsOut.length === 0) return;
  const buf = Buffer.allocUnsafe(8 * COLS * rowsOut.length);
  for (let i = 0; i < rowsOut.length; i += 1) {
    for (let j = 0; j < COLS; j += 1) {
      const v = rowsOut[i][j];
      buf.writeDoubleLE(Number.isFinite(v) ? v : NaN, 8 * (i * COLS + j));
    }
  }
  writeSync(fd, buf);
  rowsOut.length = 0;
}

const days = [];
for (let d = DAY_FROM; d <= DAY_TO; ) {
  days.push(String(d));
  const nx = new Date(Date.UTC(Math.floor(d / 10000), Math.floor((d % 10000) / 100) - 1, d % 100) + 86400000);
  d = nx.getUTCFullYear() * 10000 + (nx.getUTCMonth() + 1) * 100 + nx.getUTCDate();
}

const t0 = Date.now();
for (const dayName of days) {
  const file = join(CACHE, `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${dayName}.zip`);
  if (!existsSync(file)) { console.log(`${dayName}: no offer file`); continue; }
  const day = await readDay(file);
  const dayStart = day.trading;
  if (!dayStart) { console.log(`${dayName}: no trading stamp`); continue; }
  const byOrigin = byDay.get(Math.floor(dayStart / 1440)) || new Map();
  const origins = [...byOrigin.keys()].sort((a, b) => a - b);
  let used = 0;
  for (const origin of origins) {
    const cache = new Map();                    // period -> segment count
    for (const base of byOrigin.get(origin)) {
      const target = panel[base + 1];
      const rrp = panel[base + 3];
      const demand = panel[base + 4];
      const dispatchable = panel[base + 5];
      const netInt = panel[base + 6];
      const ssSolar = panel[base + 7];
      const ssWind = panel[base + 8];
      const period = Math.min(PERIODS, Math.max(1, Math.round((target - dayStart) / 5)));
      if (!cache.has(period)) cache.set(period, buildLadder(day, period, origin));
      const n = cache.get(period);
      if (!n) continue;
      const total = cum[n - 1];
      if (dispatchable > total) shortStack += 1;
      const age = lodgeAge(day, period, origin);
      if (age > maxAge) maxAge = age;
      rowsOut.push([
        origin, target, dispatchable,
        priceAt(n, dispatchable),
        priceAt(n, demand),
        priceAt(n, demand + netInt),
        rrp, demand, dispatchable, netInt, ssSolar, ssWind, age,
      ]);
      written += 1;
      used += 1;
    }
    flush();
  }
  console.log(`${dayName}: units ${day.units.length} origins ${origins.length} rows ${used} total ${written} (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
}
flush();
closeSync(fd);

writeFileSync(join(OUT, "e09_candidate.json"), JSON.stringify({
  rows: written,
  cols: COL_NAMES,
  day_from: DAY_FROM,
  day_to: DAY_TO,
  dispatchable_above_stack: shortStack,
  oldest_lodgement_used_min: maxAge,
  note: "every reading uses, per unit and period, the newest lodgement at or before the origin; "
    + "price_at_dispatchable is the scheduled stack read at the published dispatchable generation",
}, null, 2), "utf8");
console.log(`\nrows ${written}, dispatchable above the whole stack ${shortStack}, oldest lodgement used ${maxAge} min before its origin`);
console.log(`wrote ${join(OUT, "e09_candidate.bin")}`);
