// Invert Victoria's day ahead offer stack at the price that actually settled.
//
// N23 read the stack at regional demand and found it far too cheap, which says
// the quantity that matters is not demand. This measures the same stack the
// other way round: for every five minute interval it records the quantity
// interval in which the settled price sits, so the implied dispatch can be
// compared with demand, and it reads the stack again at demand plus two thousand
// MW, the export the region can physically carry.
//
// Two stacks are built from one pass. The first has every unit. The second drops
// the semi scheduled plant, whose offer is a bid curve it cannot exceed its
// availability, so the truth lies between the two readings.
//
// The stack used is the one lodged a day ahead, the same object a forecast at six
// to twenty four hours has.
//
// Usage: node diag_e09_ladder.mjs [--region VIC1] [--from 20260907] [--to 20261008]

import { existsSync, mkdirSync, readFileSync, writeFileSync, openSync, writeSync, closeSync } from "node:fs";
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
const REGION = arg("--region", "VIC1");
const outDir = arg("--out", OUT);
const DAY_FROM = Number(arg("--from", "20260907"));
const DAY_TO = Number(arg("--to", "20261008"));

const BANDS = 10;
const PERIODS = 288;
const EPS = 0.005;
const EXTRA_MW = 2000;          // the export Victoria can physically carry

// ------------------------------------------------------------- unit classes
const cls = new Map();
{
  const p = join(ROOT, "AEMO_Data", "duid_unit_class.csv");
  for (const line of readFileSync(p, "utf8").split(/\r?\n/).slice(1)) {
    if (!line) continue;
    const c = line.split(",");
    if (c[0]) cls.set(c[0], c[4] || "");
  }
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
const inRegion = new Set([...region].filter(([, r]) => r === REGION).map(([d]) => d));

function stampSlash(s) {
  const b = s.charCodeAt(0) === 34 ? 1 : 0;
  return Date.UTC(
    Number(s.substr(b, 4)), Number(s.substr(b + 5, 2)) - 1, Number(s.substr(b + 8, 2)),
    Number(s.substr(b + 11, 2)), Number(s.substr(b + 14, 2)), Number(s.substr(b + 17, 2)),
  ) / 60000;
}

// ------------------------------------------------- settled price and demand
const settled = new Map();
for (const m of ["202608", "202609", "202610"]) {
  const p = join(ROOT, "AEMO_Data", `PRICE_AND_DEMAND_${m}_${REGION}.csv`);
  if (!existsSync(p)) continue;
  const lines = readFileSync(p, "utf8").split(/\r?\n/);
  const head = lines[0].split(",");
  const ci = head.indexOf("SETTLEMENTDATE");
  const ri = head.indexOf("RRP");
  const di = head.indexOf("TOTALDEMAND");
  for (let i = 1; i < lines.length; i += 1) {
    const l = lines[i];
    if (!l) continue;
    const c = l.split(",");
    settled.set(stampSlash(c[ci]), { d: Number(c[di]), p: Number(c[ri]) });
  }
}

// ------------------------------------------------------------ offer reading
const DAYS = [];
for (let d = DAY_FROM; d <= DAY_TO; ) {
  DAYS.push(String(d));
  const nx = new Date(Date.UTC(Math.floor(d / 10000), Math.floor((d % 10000) / 100) - 1, d % 100) + 86400000);
  d = nx.getUTCFullYear() * 10000 + (nx.getUTCMonth() + 1) * 100 + nx.getUTCDate();
}

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
    if (!inRegion.has(duid)) continue;
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
      for (let k = 0; k < BANDS; k += 1) {
        const x = Number(c[18 + k]);
        bands[k] = Number.isFinite(x) ? x : 0;
      }
      const pFrom = Number(c[8]);
      const pTo = Number(c[9]) || pFrom;
      if (!vols.has(key)) vols.set(key, []);
      vols.get(key).push({ t: stampSlash(c[7]), from: pFrom, to: pTo, bands });
    }
  }
  const units = [];
  for (const [key, rows] of vols) {
    const duid = key.slice(0, key.indexOf("|"));
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
    units.push({ duid, lad, per, semi: isSemi(duid) });
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

// --------------------------------------------------------------- curve work
const segPrice = [];
const segMw = [];
const segSemi = [];
const segPre = [];
const cumAll = new Float64Array(8192);
const cumNo = new Float64Array(8192);
const cumSemi = new Float64Array(8192);
const curvePrice = new Float64Array(8192);

/** Sorted offer segments for one period, in price order. */
function buildSegments(day, origin, period) {
  segPrice.length = 0;
  segMw.length = 0;
  segSemi.length = 0;
  segPre.length = 0;
  for (const u of day.units) {
    const rows = u.per[period];
    if (!rows) continue;
    let lo = 0;
    let hi = rows.length - 1;
    let pick = null;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (rows[mid].t <= origin) { pick = rows[mid]; lo = mid + 1; } else { hi = mid - 1; }
    }
    if (!pick) continue;
    const lad = ladderAt(u.lad, pick.t);
    if (!lad) continue;
    for (let b = 0; b < BANDS; b += 1) {
      const mw = pick.bands[b];
      if (mw > 0) {
        segPrice.push(lad.prices[b]);
        segMw.push(mw);
        segSemi.push(u.semi ? 1 : 0);
      }
    }
  }
  const n = segPrice.length;
  if (n === 0) return 0;
  for (let i = 0; i < n; i += 1) segPre.push(i);
  segPre.sort((a, b) => segPrice[a] - segPrice[b]);
  let sAll = 0;
  let sNo = 0;
  let sSemi = 0;
  for (let i = 0; i < n; i += 1) {
    const j = segPre[i];
    curvePrice[i] = segPrice[j];
    sAll += segMw[j];
    if (!segSemi[j]) sNo += segMw[j];
    else sSemi += segMw[j];
    cumAll[i] = sAll;
    cumNo[i] = sNo;
    cumSemi[i] = sSemi;
  }
  return n;
}

/** The price of the first segment whose cumulative reaches q, or NaN. */
function priceAt(n, cum, q) {
  if (!Number.isFinite(q)) return NaN;
  if (cum[n - 1] < q) return NaN;
  let lo = 0;
  let hi = n - 1;
  let pick = -1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (cum[mid] >= q) { pick = mid; hi = mid - 1; } else { lo = mid + 1; }
  }
  return pick >= 0 ? curvePrice[pick] : NaN;
}

/** Quantity interval consistent with a settled price. flag 2 below, 1 above. */
function priceWindow(n, cum, maxPrice, p, out) {
  const minPrice = curvePrice[0];
  if (p < minPrice - EPS) {
    out.low = 0; out.high = 0; out.flag = 2;
    return;
  }
  if (p > maxPrice + EPS) {
    out.low = cum[n - 1]; out.high = cum[n - 1]; out.flag = 1;
    return;
  }
  let iLow = 0;
  while (iLow < n && curvePrice[iLow] < p - EPS) iLow += 1;
  let iHigh = n - 1;
  while (iHigh >= 0 && curvePrice[iHigh] > p + EPS) iHigh -= 1;
  out.low = iLow > 0 ? cum[iLow - 1] : 0;
  out.high = iHigh >= 0 ? cum[iHigh] : 0;
  out.flag = 0;
}

function maxPriceOf(n, skipSemi) {
  let m = -Infinity;
  for (let i = 0; i < n; i += 1) {
    const j = segPre[i];
    if (skipSemi && segSemi[j]) continue;
    if (curvePrice[i] > m) m = curvePrice[i];
  }
  return m;
}

function mwAtOrBelow(n, cum, limit) {
  let idx = -1;
  let lo = 0;
  let hi = n - 1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (curvePrice[mid] <= limit) { idx = mid; lo = mid + 1; } else { hi = mid - 1; }
  }
  return idx >= 0 ? cum[idx] : 0;
}

function semiAtQ(n, q) {
  let lo = 0;
  let hi = n - 1;
  let pick = -1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (cumAll[mid] >= q) { pick = mid; hi = mid - 1; } else { lo = mid + 1; }
  }
  return pick >= 0 ? cumSemi[pick] : 0;
}

// ------------------------------------------------------------------- output
const COLS = 12;
const win = { low: 0, high: 0, flag: 0 };
const files = [
  { suffix: "", skipSemi: false },
  { suffix: "_nosemi", skipSemi: true },
].map((v) => ({
  ...v,
  name: `e09_ladder_${REGION}${v.suffix}.bin`,
  fd: openSync(join(outDir, `e09_ladder_${REGION}${v.suffix}.bin`), "w"),
  buf: [],
  rows: 0,
}));

function emit(v, vals) {
  const b = Buffer.allocUnsafe(8 * COLS);
  for (let i = 0; i < COLS; i += 1) b.writeDoubleLE(Number.isFinite(vals[i]) ? vals[i] : NaN, 8 * i);
  v.buf.push(b);
  v.rows += 1;
  if (v.buf.length >= 2000) { writeSync(v.fd, Buffer.concat(v.buf)); v.buf.length = 0; }
}

const t0 = Date.now();
let skipped = 0;
let missing = 0;
for (const dayName of DAYS) {
  const file = join(CACHE, `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${dayName}.zip`);
  if (!existsSync(file)) { console.log(`${dayName}: no file`); skipped += 1; continue; }
  const day = await readDay(file);
  const dayStart = day.trading;
  if (!dayStart) { console.log(`${dayName}: no trading stamp`); skipped += 1; continue; }
  let rows = 0;
  for (let p0 = 0; p0 < PERIODS; p0 += 1) {
    const origin = dayStart + 5 * p0;
    const endMin = origin + 5;
    const s = settled.get(endMin);
    if (!s || !Number.isFinite(s.d) || !Number.isFinite(s.p)) { missing += 1; continue; }
    const n = buildSegments(day, origin, p0 + 1);
    if (n === 0) continue;
    const semiTotal = cumSemi[n - 1];
    const maxAll = maxPriceOf(n, false);
    const maxNo = maxPriceOf(n, true);
    const mwLe0All = mwAtOrBelow(n, cumAll, 0);
    const mwLe0Semi = mwAtOrBelow(n, cumSemi, 0);
    for (const v of files) {
      const cum = v.skipSemi ? cumNo : cumAll;
      const maxPrice = v.skipSemi ? maxNo : maxAll;
      priceWindow(n, cum, maxPrice, s.p, win);
      emit(v, [
        endMin, s.d, s.p,
        priceAt(n, cum, s.d),
        priceAt(n, cum, s.d + EXTRA_MW),
        win.low, win.high, cum[n - 1],
        v.skipSemi ? 0 : mwLe0All,
        v.skipSemi ? 0 : mwLe0Semi,
        v.skipSemi ? 0 : semiAtQ(n, s.d),
        win.flag,
      ]);
    }
    rows += 1;
  }
  const secs = ((Date.now() - t0) / 1000).toFixed(0);
  console.log(`${dayName}: trading ${new Date(dayStart * 60000).toISOString().slice(0, 10)} units ${day.units.length} intervals ${rows} cumulative ${files[0].rows} (${secs}s)`);
}
for (const v of files) {
  if (v.buf.length) writeSync(v.fd, Buffer.concat(v.buf));
  closeSync(v.fd);
  writeFileSync(join(outDir, `e09_ladder_${REGION}${v.suffix}.json`), JSON.stringify({
    region: REGION,
    drop_semi: v.skipSemi,
    rows: v.rows,
    days: DAYS.length,
    days_skipped: skipped,
    intervals_without_price: missing,
    extra_mw: EXTRA_MW,
    cols: ["end_min", "demand", "price", "price_at_demand", "price_at_demand_plus_2000",
      "q_low", "q_high", "mw_total", "mw_le0", "mw_le0_semi", "mw_semi_at_demand", "edge_flag"],
    note: "q_low and q_high bound the dispatch the settled price implies; edge_flag 2 means the price sits below the stack, 1 above it, 0 inside",
  }, null, 2), "utf8");
  console.log(`wrote ${v.name}: ${v.rows} rows`);
}
console.log(`days ${DAYS.length}, skipped ${skipped}, intervals without a settled price ${missing}`);
