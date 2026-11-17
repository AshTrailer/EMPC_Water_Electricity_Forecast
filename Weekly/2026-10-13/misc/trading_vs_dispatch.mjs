// Check the relationship between the 30-minute trading price and the six 5-minute
// dispatch prices of the same trading interval. Read-only.
import { extractZip } from './nemweb_peek.mjs';

const BASE = 'https://www.nemweb.com.au/Reports/CURRENT/';
const REGION = 'VIC1';

async function listing(dir) {
  const html = await (await fetch(BASE + dir + '/', { headers: { 'User-Agent': 'Mozilla/5.0' } })).text();
  return [...html.matchAll(/<A HREF="([^"]+)"[^>]*>([^<]*)<\/A>/gi)]
    .map(m => m[1]).filter(h => !h.endsWith('/') && !h.includes('DUPLICATE'));
}

async function rows(url, table, cols) {
  const buf = Buffer.from(await (await fetch('https://www.nemweb.com.au' + url, { headers: { 'User-Agent': 'Mozilla/5.0' } })).arrayBuffer());
  const txt = extractZip(buf)[0].data.toString('utf8');
  let head = null;
  const out = [];
  for (const line of txt.split(/\r?\n/)) {
    const f = line.split(',');
    if (f[1] !== table.split('|')[0] || f[2] !== table.split('|')[1]) continue;
    if (f[0] === 'I') { head = f.slice(4).map(s => s.replace(/^"|"$/g, '')); continue; }
    if (f[0] !== 'D') continue;
    const o = {};
    for (let i = 0; i < head.length; i++) o[head[i]] = (f[4 + i] ?? '').replace(/^"|"$/g, '');
    if (!REGION || o.REGIONID === REGION) out.push(o);
  }
  return { head, out };
}

// pick the trading interval ending 03:00 today, i.e. six dispatch intervals 02:35..03:00
const TRADE_END = '2026/10/13 03:00:00';
const DISPATCH_STAMPS = ['202610130235', '202610130240', '202610130245', '202610130250', '202610130255', '202610130300'];

const dFiles = await listing('DispatchIS_Reports');
const tFiles = await listing('TradingIS_Reports');

const dispVals = [];
for (const stamp of DISPATCH_STAMPS) {
  const url = dFiles.find(h => h.includes(`DISPATCHIS_${stamp}_`));
  if (!url) { console.log(`no dispatch file for ${stamp}`); continue; }
  const { out } = await rows(url, 'DISPATCH|PRICE', null);
  const hit = out.find(o => o.SETTLEMENTDATE.includes(stamp.slice(0, 8) === '20261013' ? stamp.slice(8, 10) : '') && false);
  // match on SETTLEMENTDATE ending with the stamp's HH:MM
  const hhmm = `${stamp.slice(8, 10)}:${stamp.slice(10, 12)}`;
  const want = out.find(o => (o.SETTLEMENTDATE || '').endsWith(hhmm + ':00'));
  if (want) { dispVals.push({ hhmm, rrp: Number(want.RRP) }); console.log(`  dispatch ${hhmm}  RRP ${want.RRP}`); }
  else console.log(`  dispatch ${hhmm}: no VIC1 row`);
}

// trading file published just after the trading interval closes
const tUrl = tFiles.filter(h => /TRADINGIS_20261013030[05]_/.test(h)).pop() || tFiles[tFiles.length - 1];
const t = await rows(tUrl, 'TRADING|PRICE', null);
console.log(`\ntrading file ${tUrl}`);
const trade = t.out.find(o => (o.SETTLEMENTDATE || '') === TRADE_END);
if (trade) console.log(`  TRADING|PRICE ${TRADE_END}  RRP ${trade.RRP}`);

const mean = dispVals.reduce((a, b) => a + b.rrp, 0) / dispVals.length;
console.log(`\nsix 5-min dispatch prices: ${dispVals.map(d => d.rrp.toFixed(5)).join('  ')}`);
console.log(`simple mean of six      : ${mean.toFixed(5)}`);
if (trade) {
  console.log(`trading price (30 min)  : ${Number(trade.RRP).toFixed(5)}`);
  console.log(`absolute difference     : ${Math.abs(mean - Number(trade.RRP)).toFixed(6)}`);
}

// does the trading price change within one trading interval?
console.log('\ntrading price evolution inside one trading interval (VIC1):');
for (const stamp of ['202610130235', '202610130240', '202610130245', '202610130250', '202610130255', '202610130300']) {
  const u = tFiles.find(h => h.includes(`TRADINGIS_${stamp}_`));
  if (!u) { console.log(`  ${stamp}: no file`); continue; }
  const r = await rows(u, 'TRADING|PRICE', null);
  const row = r.out.find(o => (o.SETTLEMENTDATE || '').endsWith(stamp.slice(8, 10) + ':' + stamp.slice(10, 12) + ':00'));
  console.log(`  published ${stamp.slice(8, 10)}:${stamp.slice(10, 12)}  SETTLEMENTDATE ${row ? row.SETTLEMENTDATE : 'n/a'}  RRP ${row ? row.RRP : 'n/a'}`);
}
