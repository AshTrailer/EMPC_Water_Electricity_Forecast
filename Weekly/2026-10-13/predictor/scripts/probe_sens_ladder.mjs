// Does the VIC1 demand ladder behave like a price curve?
//
// The scenario mapping is taken from AEMO's own table, not inferred: scenarios 8
// to 14 apply +100, -100, +200, -200, +500, -500 and +1000 MW to the VIC1 demand
// forecast. A price that rises with demand must therefore satisfy
// RRPEEP8 < RRPEEP10 < RRPEEP12 < RRPEEP14 and RRPEEP9 > RRPEEP11 > RRPEEP13.
// Violations would mean the column order is not what the document says.
//
// Usage: node probe_sens_ladder.mjs

import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const path =
  "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\AEMO_Data\\window_60d_20260811_20261009_vic1\\sens_vic1.csv";
const rl = createInterface({ input: createStream(), crlfDelay: Infinity });
function createStream() {
  return createReadStream(path);
}

let idx = null;
let n = 0;
let upViol = 0;
let dnViol = 0;
const upGap = [];
const dnGap = [];
const zeroRun = [];
for await (const line of rl) {
  if (idx === null) {
    idx = {};
    line.split(",").forEach((v, i) => (idx[v.trim()] = i));
    continue;
  }
  const f = line.split(",");
  const p100 = +f[idx.RRPEEP8];
  const m100 = +f[idx.RRPEEP9];
  const p200 = +f[idx.RRPEEP10];
  const m200 = +f[idx.RRPEEP11];
  const p500 = +f[idx.RRPEEP12];
  const m500 = +f[idx.RRPEEP13];
  const p1000 = +f[idx.RRPEEP14];
  n++;
  if (!(p100 <= p200 && p200 <= p500 && p500 <= p1000)) upViol++;
  if (!(m100 >= m200 && m200 >= m500)) dnViol++;
  upGap.push(p1000 - p100);
  dnGap.push(m100 - m500);
  if (p1000 === p100 && m100 === m500) zeroRun.push(n);
}
const med = (a) => {
  const b = [...a].sort((x, y) => x - y);
  return b[b.length >> 1];
};
console.log(`rows ${n}`);
console.log(`up ladder violations   ${upViol} (${(100 * upViol / n).toFixed(2)}%)`);
console.log(`down ladder violations ${dnViol} (${(100 * dnViol / n).toFixed(2)}%)`);
console.log(`flat ladder at both ends ${zeroRun.length} (${(100 * zeroRun.length / n).toFixed(2)}%)`);
console.log(`P(+1000) - P(+100): median ${med(upGap).toFixed(3)}  p90 ${[...upGap].sort((a, b) => a - b)[Math.floor(0.9 * n)].toFixed(1)}  max ${Math.max(...upGap).toFixed(1)}`);
console.log(`P(-100) - P(-500):  median ${med(dnGap).toFixed(3)}  p90 ${[...dnGap].sort((a, b) => a - b)[Math.floor(0.9 * n)].toFixed(1)}  max ${Math.max(...dnGap).toFixed(1)}`);
