// Loaders for the daily Victoria energy offer files.
//
// One trading day of the daily offer archive, reduced to what a supply curve
// needs: per unit and direction, the lodgement history of the ten price bands and
// the ten band volumes per five minute period. A rebid applies to every future
// period, so the state as of an origin is the newest lodgement not after it.
//
// Only BIDTYPE ENERGY is present in this file; the FCAS products are published
// separately, so no type filter is needed. LOAD directions are dropped by the
// caller because a load offer is not supply.

import { existsSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./zip_stream.mjs";

const BANDS = 10;
const PERIODS = 288;

/** "YYYY/MM/DD HH:MM:SS", optionally quoted, to minutes since 1970. */
export function stampSlash(s) {
  const b = s.charCodeAt(0) === 34 ? 1 : 0;
  return Date.UTC(
    Number(s.substr(b, 4)), Number(s.substr(b + 5, 2)) - 1, Number(s.substr(b + 8, 2)),
    Number(s.substr(b + 11, 2)), Number(s.substr(b + 14, 2)), Number(s.substr(b + 17, 2)),
  ) / 60000;
}

/** "YYYY-MM-DD HH:MM:SS" to minutes since 1970. */
export function stampDash(s) {
  return Date.UTC(
    Number(s.substr(0, 4)), Number(s.substr(5, 2)) - 1, Number(s.substr(8, 2)),
    Number(s.substr(11, 2)), Number(s.substr(14, 2)), Number(s.substr(17, 2)),
  ) / 60000;
}

export function ensureDay(cacheDir, day) {
  if (!existsSync(cacheDir)) mkdirSync(cacheDir, { recursive: true });
  const file = join(cacheDir, `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}.zip`);
  if (existsSync(file)) return file;
  return null;
}

export async function downloadDay(cacheDir, day) {
  const file = ensureDay(cacheDir, day);
  if (file) return file;
  const url = "https://nemweb.com.au/Reports/CURRENT/Next_Day_Offer_Energy_SPARSE/";
  const html = await (await fetch(url)).text();
  const hit = (html.match(new RegExp(`PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}_\\d+\\.zip`, "gi")) || [])[0];
  if (!hit) return null;
  writeFileSync(join(cacheDir, `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}.zip`), Buffer.from(await (await fetch(url + hit)).arrayBuffer()));
  return join(cacheDir, `PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_${day}.zip`);
}

/**
 * @param {string} file zip path
 * @param {Set<string>} keep units to retain
 * @returns {Promise<{trading:number, units:Array, stats:object}>}
 */
export async function readDay(file, keep) {
  const csv = listEntries(file).find((e) => /\.csv$/i.test(e.name));
  const ladders = new Map();
  const vols = new Map();
  let trading = 0;
  let priceRows = 0;
  let availRows = 0;
  let expanded = 0;

  const rl = createInterface({ input: openEntry(file, csv), crlfDelay: Infinity });
  for await (const line of rl) {
    if (line.charCodeAt(0) !== 68) continue;
    const c = line.split(",");
    const duid = c[4];
    if (!keep.has(duid)) continue;
    const table = c[2];
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
      let sum = 0;
      for (let k = 0; k < BANDS; k += 1) {
        const x = Number(c[18 + k]);
        bands[k] = Number.isFinite(x) ? x : 0;
        sum += bands[k];
      }
      const maxAvail = Number(c[10]);
      const pFrom = Number(c[8]);
      const pTo = Number(c[9]) || pFrom;
      if (!vols.has(key)) vols.set(key, []);
      vols.get(key).push({
        t: stampSlash(c[7]), from: pFrom, to: pTo, bands, sum, maxAvail,
        // Band availabilities do not always add up to the unit's maximum
        // availability; storage especially reports the full rating in several
        // bands. The scale brings the ladder back to the stated capability.
        scale: sum > maxAvail && sum > 0 ? maxAvail / sum : 1,
      });
      availRows += 1;
      expanded += pTo - pFrom + 1;
    }
  }

  const units = [];
  for (const [key, rows] of vols) {
    const dir = key.slice(key.indexOf("|") + 1);
    const lad = ladders.get(key) || [];
    lad.sort((a, b) => a.t - b.t);
    const per = new Array(PERIODS + 1);
    for (const r of rows) {
      const hi = Math.min(r.to, PERIODS);
      for (let p = Math.max(1, r.from); p <= hi; p += 1) {
        if (!per[p]) per[p] = [];
        per[p].push(r);
      }
    }
    for (let p = 1; p <= PERIODS; p += 1) if (per[p]) per[p].sort((a, b) => a.t - b.t);
    units.push({ key, duid: key.slice(0, key.indexOf("|")), dir, lad, per });
  }
  units.sort((a, b) => (a.key < b.key ? -1 : 1));

  return { trading, units, stats: { priceRows, availRows, expanded, units: units.length } };
}

/** Last entry at or before t, by binary search over a time sorted array. */
export function atOrBefore(list, t) {
  let lo = 0;
  let hi = list.length - 1;
  let pick = null;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (list[mid].t <= t) {
      pick = list[mid];
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return pick;
}

export { BANDS, PERIODS };
