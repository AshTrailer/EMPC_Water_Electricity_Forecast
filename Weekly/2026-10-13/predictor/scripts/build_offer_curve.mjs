// Build the Victoria offer curve features at every forecast origin.
//
// The daily offer file is the version timeline: BIDDAYOFFER holds each lodgement
// of the ten price bands, BIDOFFERPERIOD_SPARSE the ten band volumes per five
// minute period, and both are stamped with the lodgement time. A rebid applies
// to every future period, so the curve as of an origin is, per unit and period,
// the newest lodgement not after that origin.
//
// For each origin and target period the aggregate curve is read at the demand
// forecast that origin carries, and seven numbers are written: marginal band
// price, next band price, headroom in MW to that band, total offered MW, offered
// MW at price at or below zero, at or below one hundred, and the demand used.
//
// Usage: node build_offer_curve.mjs --from 20260908 --to 20261009 --out <dir>

import { existsSync, mkdirSync, readFileSync, writeFileSync, openSync, writeSync, closeSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const CACHE = join(ROOT, "AEMO_Data", "offers_daily");
if (!existsSync(CACHE)) mkdirSync(CACHE, { recursive: true });

const argv = process.argv.slice(2);
const arg = (name, dflt) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : dflt;
};
const fromDay = arg("--from", "20260908");
const toDay = arg("--to", "20261009");
const outDir = arg("--out", join(ROOT, "Weekly", "2026-10-13", "research", "verify"));
if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });

const BANDS = 10;
const PERIODS = 288;
const HORIZON = 468;                       // five minute periods, 39 hours

// Capacity offered at or below each price. N23 showed the level read of the
// stack is displaced from the regional price, so only quantities that do not
// depend on where demand lands on the curve are kept.
const THRESHOLDS = [-1000, -200, -50, 0, 50, 100, 200, 300, 500, 1000, 3000];
const FEATS = ["mw_total", ...THRESHOLDS.map((t) => `mwb_${t}`), "demand"];

// ------------------------------------------------------------ region filter
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
if (vic.size === 0) throw new Error("empty Victoria unit set");

function stampDash(s) {
  return Date.UTC(
    Number(s.substr(0, 4)), Number(s.substr(5, 2)) - 1, Number(s.substr(8, 2)),
    Number(s.substr(11, 2)), Number(s.substr(14, 2)), Number(s.substr(17, 2)),
  ) / 60000;
}

function stampSlash(s) {
  const b = s.charCodeAt(0) === 34 ? 1 : 0;
  return Date.UTC(
    Number(s.substr(b, 4)), Number(s.substr(b + 5, 2)) - 1, Number(s.substr(b + 8, 2)),
    Number(s.substr(b + 11, 2)), Number(s.substr(b + 14, 2)), Number(s.substr(b + 17, 2)),
  ) / 60000;
}

// ------------------------------------------------- demand forecast by origin
const demand = new Map();                  // origin minutes -> Map(period id -> MW)
{
  const p = join(ROOT, "AEMO_Data", "window_60d_20260811_20261009_vic1", "predispatch_30min_VIC1.csv");
  const lines = readFileSync(p, "utf8").split(/\r?\n/);
  for (let i = 1; i < lines.length; i += 1) {
    const l = lines[i];
    if (!l) continue;
    const c = l.split(",");
    const eff = stampDash(c[0]);
    if (!demand.has(eff)) demand.set(eff, new Map());
    demand.get(eff).set(Number(c[3]), Number(c[6]));
  }
}

// --------------------------------------------------------------- day reader
async function ensureDay(day) {
  const file = join(CACHE, `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}.zip`);
  if (existsSync(file)) return file;
  const url = "https://nemweb.com.au/Reports/CURRENT/Next_Day_Offer_Energy_SPARSE/";
  const html = await (await fetch(url)).text();
  const hit = (html.match(new RegExp(`PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}_\\d+\\.zip`, "gi")) || [])[0];
  if (!hit) return null;
  writeFileSync(file, Buffer.from(await (await fetch(url + hit)).arrayBuffer()));
  return file;
}

/**
 * One trading day of Victoria energy offers.
 * @returns {Promise<{trading:number, units:Array, stats:object}>}
 */
async function readDay(file) {
  const csv = listEntries(file).find((e) => /\.csv$/i.test(e.name));
  const ladders = new Map();     // "duid|dir" -> [{t, prices}]
  const vols = new Map();        // "duid|dir" -> [{t, from, to, bands}]
  let trading = 0;
  let priceRows = 0;
  let availRows = 0;
  let expanded = 0;

  const rl = createInterface({ input: openEntry(file, csv), crlfDelay: Infinity });
  for await (const line of rl) {
    if (line.charCodeAt(0) !== 68) continue;
    const c = line.split(",");
    const table = c[2];
    const duid = c[4];
    if (!vic.has(duid)) continue;
    const dir = table === "BIDDAYOFFER" ? c[35] : c[29];
    const key = `${duid}|${dir}`;

    if (table === "BIDDAYOFFER") {
      const prices = new Float64Array(BANDS);
      for (let k = 0; k < BANDS; k += 1) prices[k] = Number(c[12 + k]);
      if (!ladders.has(key)) ladders.set(key, []);
      ladders.get(key).push({ t: stampSlash(c[7]), prices });
      priceRows += 1;
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
      availRows += 1;
      expanded += pTo - pFrom + 1;
    }
  }

  const units = [];
  let priceGap = 0;
  for (const [key, rows] of vols) {
    const dir = key.slice(key.indexOf("|") + 1);
    if (dir === "LOAD") continue;
    const lad = ladders.get(key) || [];
    lad.sort((a, b) => a.t - b.t);

    // Bucketing by period keeps the as-of lookup to the few lodgements that
    // ever touched that period, instead of scanning every lodgement of the day.
    const per = new Array(PERIODS + 1);
    for (const r of rows) {
      const hi = Math.min(r.to, PERIODS);
      for (let p = Math.max(1, r.from); p <= hi; p += 1) {
        if (!per[p]) per[p] = [];
        per[p].push(r);
      }
    }
    let gap = 0;
    for (let p = 1; p <= PERIODS; p += 1) {
      if (!per[p]) continue;
      per[p].sort((a, b) => a.t - b.t);
      for (const r of per[p]) if (ladderAt(lad, r.t) === null) gap += 1;
    }
    if (gap) priceGap += gap;
    units.push({ key, duid: key.slice(0, key.indexOf("|")), dir, lad, per });
  }
  units.sort((a, b) => (a.key < b.key ? -1 : 1));

  return { trading, units, stats: { priceRows, availRows, expanded, priceGap, units: units.length } };
}

function ladderAt(lad, t) {
  let lo = 0;
  let hi = lad.length - 1;
  let pick = null;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (lad[mid].t <= t) {
      pick = lad[mid];
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return pick;
}

// ------------------------------------------------------------ curve reading
const segPrice = [];
const segMw = [];
const segPre = [];
const cum = new Float64Array(4096);
const curvePrice = new Float64Array(4096);

function buildCurve(day, origin, period) {
  segPrice.length = 0;
  segMw.length = 0;
  segPre.length = 0;
  for (const u of day.units) {
    const rows = u.per[period];
    if (!rows) continue;
    // Newest lodgement not after the origin. Rows are sorted by lodgement time,
    // so this is a binary search for the last one at or before it.
    let lo = 0;
    let hi = rows.length - 1;
    let pick = null;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (rows[mid].t <= origin) {
        pick = rows[mid];
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (!pick) continue;
    const lad = ladderAt(u.lad, pick.t);
    if (!lad) continue;
    for (let b = 0; b < BANDS; b += 1) {
      const mw = pick.bands[b];
      if (mw > 0) {
        segPrice.push(lad.prices[b]);
        segMw.push(mw);
      }
    }
  }
  const n = segPrice.length;
  if (n === 0) return null;
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

function features(n, d0) {
  const out = new Float64Array(FEATS.length);
  out[0] = cum[n - 1];
  let i = 0;
  for (let k = 0; k < THRESHOLDS.length; k += 1) {
    while (i + 1 < n && curvePrice[i + 1] <= THRESHOLDS[k]) i += 1;
    // i is the last segment whose price is at or below the threshold, unless the
    // first segment already exceeds it, in which case nothing is offered there.
    out[1 + k] = curvePrice[0] <= THRESHOLDS[k] ? cum[i] : 0;
  }
  out[FEATS.length - 1] = Number.isFinite(d0) ? d0 : NaN;
  return out;
}

// ------------------------------------------------------------------ emitter
const outTimes = join(outDir, "offer_curve_times.bin");
const outFeat = join(outDir, "offer_curve_feat.bin");
const fdTimes = openSync(outTimes, "w");
const fdFeat = openSync(outFeat, "w");
const bufTimes = [];
const bufFeat = [];
let written = 0;
let noCurve = 0;
let demandMissing = 0;
let demandShort = 0;

function flush() {
  if (bufTimes.length === 0) return;
  writeSync(fdTimes, Buffer.concat(bufTimes));
  writeSync(fdFeat, Buffer.concat(bufFeat));
  bufTimes.length = 0;
  bufFeat.length = 0;
}

function pushRow(origin, target, feats) {
  const tb = Buffer.allocUnsafe(16);
  tb.writeDoubleLE(origin, 0);
  tb.writeDoubleLE(target, 8);
  bufTimes.push(tb);
  const fb = Buffer.allocUnsafe(4 * FEATS.length);
  for (let i = 0; i < FEATS.length; i += 1) fb.writeFloatLE(feats[i], 4 * i);
  bufFeat.push(fb);
  written += 1;
  if (bufTimes.length >= 20000) flush();
}

// ---------------------------------------------------------------- main loop
const dayList = [];
for (let d = Number(fromDay); ; ) {
  dayList.push(String(d));
  if (String(d) === toDay) break;
  const next = new Date(Date.UTC(Math.floor(d / 10000), Math.floor((d % 10000) / 100) - 1, d % 100) + 86400000);
  d = next.getUTCFullYear() * 10000 + (next.getUTCMonth() + 1) * 100 + next.getUTCDate();
  if (dayList.length > 400) throw new Error("day range too wide");
}

const t0 = Date.now();
let ahead = null;                 // parsed next day, reused as the current day
let aheadName = null;

for (let i = 0; i < dayList.length; i += 1) {
  const dayName = dayList[i];
  let cur;
  if (ahead && aheadName === dayName) {
    cur = ahead;
    ahead = null;
  } else {
    const file = await ensureDay(dayName);
    if (!file) {
      console.log(`${dayName}: offer file absent, skipped`);
      continue;
    }
    cur = await readDay(file);
  }

  let nxt = null;
  let nxtName = null;
  if (i + 1 < dayList.length) {
    nxtName = dayList[i + 1];
    const nf = await ensureDay(nxtName);
    if (nf) {
      nxt = await readDay(nf);
      ahead = nxt;
      aheadName = nxtName;
    }
  }

  const dayStart = cur.trading || stampDash(`${dayName.slice(0, 4)}-${dayName.slice(4, 6)}-${dayName.slice(6, 8)} 00:00:00`);
  const dayEnd = dayStart + 1440;
  const origins = [...demand.keys()].filter((e) => e >= dayStart && e < dayEnd).sort((a, b) => a - b);
  let rows = 0;

  for (const o of origins) {
    const dmap = demand.get(o);
    for (let step = 1; step <= HORIZON; step += 1) {
      const target = o + 5 * step;
      const which = target < dayEnd ? cur : nxt;
      if (!which) break;
      const period = Math.floor((target - (target < dayEnd ? dayStart : dayEnd)) / 5) + 1;
      if (period < 1 || period > PERIODS) continue;
      const pid = Math.min(79, Math.ceil((target - o) / 30) + 1);
      let d0 = dmap.get(pid);
      if (!Number.isFinite(d0)) {
        // The forecast of a daytime publication stops at the next four o'clock,
        // but the offer stack runs through the following trading day. Rows are
        // kept with the demand left empty so a forward difference can still use
        // the capacity columns.
        demandMissing += 1;
        d0 = NaN;
      }
      const n = buildCurve(which, o, period);
      if (n === null) {
        noCurve += 1;
        continue;
      }
      const f = features(n, d0);
      if (Number.isFinite(d0) && f[0] < d0) demandShort += 1;
      pushRow(o, target, f);
      rows += 1;
    }
  }
  flush();
  const secs = ((Date.now() - t0) / 1000).toFixed(0);
  console.log(`${dayName}: units ${cur.stats.units} price ${cur.stats.priceRows} avail ${cur.stats.availRows} priceGap ${cur.stats.priceGap} origins ${origins.length} rows ${rows} cumulative ${written} (${secs}s)`);
}

flush();
closeSync(fdTimes);
closeSync(fdFeat);

writeFileSync(join(outDir, "offer_curve.json"), JSON.stringify({
  from: fromDay,
  to: toDay,
  rows: written,
  feats: FEATS,
  no_curve: noCurve,
  demand_missing: demandMissing,
  demand_exceeds_curve: demandShort,
  units_in_region: vic.size,
  note: "times are minutes since 1970, stored as float64 pairs; features are float32 in feats order",
}, null, 2), "utf8");

console.log(`\nrows ${written}`);
console.log(`no curve ${noCurve}, demand missing ${demandMissing}, demand above total offered ${demandShort}`);
console.log(`wrote ${outTimes} and ${outFeat}`);
