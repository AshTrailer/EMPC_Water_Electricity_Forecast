// Read back the offer curve features and describe them.
//
// Four checks before the full window is built. Do the marginal band prices sit
// near the published price that the same publication carries; how often does
// demand land above every band; how wide is the headroom to the next band; and
// what do the capacity totals look like against Victoria load.

import { readFileSync } from "node:fs";
import { join } from "node:path";

const dir = process.argv[2];
const meta = JSON.parse(readFileSync(join(dir, "offer_curve.json"), "utf8"));
const tbuf = readFileSync(join(dir, "offer_curve_times.bin"));
const fbuf = readFileSync(join(dir, "offer_curve_feat.bin"));
const rows = tbuf.length / 16;
const nf = meta.feats.length;
if (fbuf.length !== rows * nf * 4) throw new Error(`feature file size ${fbuf.length} does not match ${rows} rows`);

const col = (name) => {
  const i = meta.feats.indexOf(name);
  return new Float64Array(rows).map((_, r) => fbuf.readFloatLE((r * nf + i) * 4));
};
const times = new Float64Array(rows).map((_, r) => tbuf.readDoubleLE(r * 16));
const targets = new Float64Array(rows).map((_, r) => tbuf.readDoubleLE(r * 16 + 8));

const pm = col("pm");
const pn = col("pn");
const head = col("headroom");
const tot = col("mw_total");
const low = col("mw_below_0");
const mid = col("mw_below_100");
const dem = col("demand");

function q(a, f) {
  const s = Array.from(a).sort((x, y) => x - y);
  return s[Math.min(s.length - 1, Math.floor(f * s.length))];
}
function line(name, a) {
  console.log(`  ${name.padEnd(14)} min ${q(a, 0.01).toFixed(1).padStart(10)}  p25 ${q(a, 0.25).toFixed(1).padStart(9)}  med ${q(a, 0.5).toFixed(1).padStart(9)}  p75 ${q(a, 0.75).toFixed(1).padStart(9)}  p99 ${q(a, 0.99).toFixed(1).padStart(10)}  max ${q(a, 1).toFixed(1).padStart(10)}`);
}

console.log(`rows ${rows}  days ${meta.from} to ${meta.to}`);
console.log(`features ${meta.feats.join(" ")}`);
console.log("\ndistributions");
for (const [n, a] of [["pm", pm], ["pn", pn], ["headroom", head], ["mw_total", tot], ["mw_below_0", low], ["mw_below_100", mid], ["demand", dem]]) line(n, a);

// Marginal price against the price the same publication carries.
const want = new Map();
{
  const p = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\AEMO_Data\\window_60d_20260811_20261009_vic1\\predispatch_30min_VIC1.csv";
  for (const l of readFileSync(p, "utf8").split(/\r?\n/).slice(1)) {
    if (!l) continue;
    const c = l.split(",");
    const eff = Date.UTC(+c[0].slice(0, 4), +c[0].slice(5, 7) - 1, +c[0].slice(8, 10), +c[0].slice(11, 13), +c[0].slice(14, 16)) / 60000;
    const tgt = Date.UTC(+c[2].slice(0, 4), +c[2].slice(5, 7) - 1, +c[2].slice(8, 10), +c[2].slice(11, 13), +c[2].slice(14, 16)) / 60000;
    want.set(`${eff}|${tgt}`, Number(c[4]));
  }
}

// Targets are five minute instants, prices are half hourly; take the period end
// that covers the target.
let paired = 0;
let agree = 0;
const diff = [];
for (let r = 0; r < rows; r += 1) {
  const o = times[r];
  const t = targets[r];
  const pid = Math.min(79, Math.ceil((t - o) / 30) + 1);
  const tgt = o + 30 * (pid - 1);
  const rrp = want.get(`${o}|${tgt}`);
  if (!Number.isFinite(rrp)) continue;
  paired += 1;
  const d = pm[r] - rrp;
  diff.push(d);
  if (Math.abs(d) < 0.01) agree += 1;
}
diff.sort((a, b) => a - b);
const mean = diff.reduce((a, b) => a + b, 0) / diff.length;
const qd = (f) => diff[Math.min(diff.length - 1, Math.floor(f * diff.length))];
console.log(`\nmarginal band price minus published price, ${paired} pairs`);
console.log(`  mean ${mean.toFixed(2)}  p10 ${qd(0.1).toFixed(2)}  p25 ${qd(0.25).toFixed(2)}  median ${qd(0.5).toFixed(2)}  p75 ${qd(0.75).toFixed(2)}  p90 ${qd(0.9).toFixed(2)}`);
console.log(`  within 0.01 of the published price: ${(100 * agree / paired).toFixed(1)}%`);

const zeroHead = Array.from(head).filter((x) => x === 0).length;
console.log(`\nrows sitting at or above the top band: ${zeroHead} of ${rows} (${(100 * zeroHead / rows).toFixed(1)}%)`);
