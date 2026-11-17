// Parse one Bidmove_Complete day into per unit energy offer versions.
//
// Bidmove is the full model export. BIDDAYOFFER_D holds the ten price bands of
// each offer version, BIDPEROFFER_D the ten band availabilities per five minute
// period, and both carry OFFERDATE and VERSIONNO, so the join is exact.
//
// Only BIDTYPE ENERGY is kept. The same two tables also carry the ten FCAS
// products, which share DUID, OFFERDATE and VERSIONNO and would otherwise
// collide on the key.
//
// A version's OFFERDATE is the moment the offer was lodged, which is what makes
// "what was known at this origin" answerable: take, per unit, the latest version
// whose OFFERDATE is not after the origin.

import { createInterface } from "node:readline";
import { listEntries, openEntry } from "./zip_stream.mjs";

const BANDS = 10;
const PERIODS = 288;

/**
 * @param {string} path absolute path to the zip
 * @param {Set<string>} keepDuid units to retain; an empty set keeps all
 * @returns {Promise<{units:Map, stats:object}>}
 */
export async function parseDay(path, keepDuid) {
  const entries = listEntries(path);
  const csv = entries.find((e) => /\.csv$/i.test(e.name)) || entries[0];

  const priceRows = new Map();     // key -> {duid, dir, offer, version, prices}
  const availRows = new Map();     // key -> Float32Array(PERIODS*BANDS)
  const dups = new Map();
  let priceN = 0;
  let availN = 0;
  let otherType = 0;
  let headerPrice = null;
  let headerAvail = null;

  const rl = createInterface({ input: openEntry(path, csv), crlfDelay: Infinity });
  for await (const line of rl) {
    const ch = line.charCodeAt(0);
    if (ch !== 73 && ch !== 68) continue;          // 'I' and 'D'
    const c = line.split(",");
    const table = c[2];
    if (ch === 73) {
      if (table === "BIDDAYOFFER_D") headerPrice = c.slice(4);
      else if (table === "BIDPEROFFER_D") headerAvail = c.slice(4);
      continue;
    }
    if (c[6] !== "ENERGY") {
      otherType += 1;
      continue;
    }
    const duid = c[5];
    if (keepDuid.size && !keepDuid.has(duid)) continue;

    if (table === "BIDDAYOFFER_D") {
      const dir = c[31];
      const key = `${duid}|${c[8]}|${c[9]}|${dir}`;
      const prices = new Float64Array(BANDS);
      for (let b = 0; b < BANDS; b += 1) prices[b] = Number(c[13 + b]);
      if (priceRows.has(key)) dups.set(key, (dups.get(key) || 1) + 1);
      priceRows.set(key, { duid, dir, offer: c[8], version: c[9], prices });
      priceN += 1;
    } else if (table === "BIDPEROFFER_D") {
      const dir = c[32];
      const key = `${duid}|${c[8]}|${c[10]}|${dir}`;
      const pid = Number(c[9]);
      let v = availRows.get(key);
      if (!v) {
        v = new Float32Array(PERIODS * BANDS);
        availRows.set(key, v);
      }
      const base = (pid - 1) * BANDS;
      for (let b = 0; b < BANDS; b += 1) {
        const x = Number(c[19 + b]);
        v[base + b] = Number.isFinite(x) ? x : 0;
      }
      availN += 1;
    }
  }

  const units = new Map();
  let matched = 0;
  const unmatched = [];
  for (const [key, p] of priceRows) {
    const a = availRows.get(key);
    if (!a) {
      unmatched.push(key);
      continue;
    }
    matched += 1;
    const t = stamp(p.offer);
    if (!units.has(p.duid)) units.set(p.duid, { duid: p.duid, versions: [] });
    units.get(p.duid).versions.push({ t, dir: p.dir, version: Number(p.version), prices: p.prices, avail: a });
  }
  for (const u of units.values()) {
    u.versions.sort((x, y) => (x.t - y.t) || (x.version - y.version));
  }

  return {
    units,
    stats: {
      priceN, availN, otherType,
      priceKeys: priceRows.size, availKeys: availRows.size,
      matched, unmatched: unmatched.length,
      dupKeys: dups.size, dupRows: [...dups.values()].reduce((a, b) => a + b, 0),
      unmatchedSample: unmatched.slice(0, 3),
      headerPrice, headerAvail,
    },
  };
}

/** Minutes since 1970 for a "YYYY/MM/DD HH:MM:SS" stamp, ignoring quotes. */
export function stamp(s) {
  const b = s.charCodeAt(0) === 34 ? 1 : 0;
  return Date.UTC(
    Number(s.substr(b, 4)), Number(s.substr(b + 5, 2)) - 1, Number(s.substr(b + 8, 2)),
    Number(s.substr(b + 11, 2)), Number(s.substr(b + 14, 2)), Number(s.substr(b + 17, 2)),
  ) / 60000;
}

export { BANDS, PERIODS };
