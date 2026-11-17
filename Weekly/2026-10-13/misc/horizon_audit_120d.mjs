// Measure the real forecast horizon distribution of the 120-day PREDISPATCH extract.
// Read-only. Prints per-run period counts, horizon hours, and horizon end clock time.
import { readFileSync, writeFileSync } from 'node:fs';
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';

const FILE = process.argv[2];
const OUT = process.argv[3];

const runs = new Map();   // run key -> {eff, seqno, runno, periods:Set, minT, maxT, regions:Set}
const rl = createInterface({ input: createReadStream(FILE), crlfDelay: Infinity });
let header = null;
let n = 0;
for await (const line of rl) {
  if (!header) { header = line.split(','); continue; }
  if (!line) continue;
  n++;
  const c = line.split(',');
  const o = {};
  for (let i = 0; i < header.length; i++) o[header[i]] = c[i];
  const key = `${o.effective_time}|${o.predispatch_seqno}|${o.run_no}`;
  let r = runs.get(key);
  if (!r) { r = { eff: o.effective_time, seqno: o.predispatch_seqno, runno: o.run_no, pid: new Set(), minT: null, maxT: null, regions: new Set(), rows: 0 }; runs.set(key, r); }
  r.rows++;
  r.pid.add(Number(o.period_id));
  r.regions.add(o.region_id);
  const t = o.target_datetime ?? o.interval_datetime;
  if (t) { if (r.minT === null || t < r.minT) r.minT = t; if (r.maxT === null || t > r.maxT) r.maxT = t; }
}

const eff = (s) => Date.parse(s.replace(' ', 'T') + '+10:00');
const rows = [];
for (const r of runs.values()) {
  const pids = [...r.pid].sort((a, b) => a - b);
  const pidMin = pids[0], pidMax = pids[pids.length - 1];
  const h = (eff(r.maxT) - eff(r.eff)) / 3600000;
  rows.push({ eff: r.eff, seqno: r.seqno, runno: r.runno, npid: pids.length, pidMin, pidMax, regions: r.regions.size, rows: r.rows, minT: r.minT, maxT: r.maxT, horizon: h, endClock: r.maxT.slice(11) });
}
rows.sort((a, b) => a.eff < b.eff ? -1 : 1);

const q = (arr, p) => { const s = [...arr].sort((a, b) => a - b); const i = (s.length - 1) * p; const lo = Math.floor(i), hi = Math.ceil(i); return lo === hi ? s[lo] : s[lo] + (s[hi] - s[lo]) * (i - lo); };
const H = rows.map(r => r.horizon);

const lines = [];
lines.push(`file            ${FILE}`);
lines.push(`header          ${header.join(',')}`);
lines.push(`data rows       ${n}`);
lines.push(`distinct runs   ${rows.length}`);
lines.push(`run window      ${rows[0].eff} .. ${rows[rows.length - 1].eff}`);
lines.push('');
lines.push(`horizon hours   min ${q(H, 0).toFixed(2)}  q05 ${q(H, .05).toFixed(2)}  q25 ${q(H, .25).toFixed(2)}  median ${q(H, .5).toFixed(2)}  q75 ${q(H, .75).toFixed(2)}  q95 ${q(H, .95).toFixed(2)}  max ${q(H, 1).toFixed(2)}`);
lines.push(`periods/run     min ${Math.min(...rows.map(r => r.npid))}  median ${q(rows.map(r => r.npid), .5)}  max ${Math.max(...rows.map(r => r.npid))}`);
lines.push(`regions/run     ${[...new Set(rows.map(r => r.regions))].join(',')}`);
lines.push('');
lines.push('history of horizon end clock time:');
const ends = new Map();
for (const r of rows) ends.set(r.endClock, (ends.get(r.endClock) ?? 0) + 1);
for (const [k, v] of [...ends.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12)) lines.push(`   ${k}  ${v} runs`);
lines.push('');
lines.push('history of pidMax:');
const pms = new Map();
for (const r of rows) pms.set(r.pidMax, (pms.get(r.pidMax) ?? 0) + 1);
for (const [k, v] of [...pms.entries()].sort((a, b) => a[0] - b[0])) lines.push(`   pidMax=${k}  ${v} runs  (horizon ${((k - 1) * 0.5).toFixed(1)} h)`);
lines.push('');
lines.push('first 8 runs and last 8 runs:');
for (const r of [...rows.slice(0, 8), ...rows.slice(-8)]) lines.push(`   ${r.eff}  seqno=${r.seqno} runno=${r.runno}  npid=${r.npid} pid ${r.pidMin}..${r.pidMax}  horizon ${r.horizon.toFixed(2)}h  end ${r.maxT}`);
lines.push('');
lines.push('runs grouped by effective hour-of-day (NEM clock): mean horizon');
const byHour = new Map();
for (const r of rows) { const hh = r.eff.slice(11, 13); if (!byHour.has(hh)) byHour.set(hh, []); byHour.get(hh).push(r.horizon); }
for (const k of [...byHour.keys()].sort()) { const a = byHour.get(k); lines.push(`   ${k}:00  n=${String(a.length).padStart(4)}  mean ${(a.reduce((x, y) => x + y, 0) / a.length).toFixed(2)}h  min ${Math.min(...a).toFixed(2)}  max ${Math.max(...a).toFixed(2)}`); }

const text = lines.join('\n');
console.log(text);
if (OUT) writeFileSync(OUT, text + '\n', 'utf8');
