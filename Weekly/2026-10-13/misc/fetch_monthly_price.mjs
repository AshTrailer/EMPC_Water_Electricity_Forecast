// Fetch AEMO monthly "Historical aggregated price and demand" CSVs for VIC1.
//   node fetch_monthly_price.mjs           probe only
//   node fetch_monthly_price.mjs --apply   write the missing months into AEMO_Data
// 202509 is a control: its bytes must equal the copy already on disk, which
// proves the URL pattern is the same one the earlier files came from.
import { writeFileSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const BASE = 'https://www.aemo.com.au/aemo/data/nem/priceanddemand/';
const DEST = 'C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast\\AEMO_Data';
const APPLY = process.argv.includes('--apply');

const PLAN = [
  { month: '202509', control: true },
  { month: '202608', control: false },
  { month: '202609', control: false },
  { month: '202610', control: false },
];

function lines(buf) {
  return buf.toString('utf8').split(/\r?\n/).filter(s => s.length > 0);
}

for (const item of PLAN) {
  const name = `PRICE_AND_DEMAND_${item.month}_VIC1.csv`;
  const url = BASE + name;
  const dest = join(DEST, name);
  let res;
  try {
    res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  } catch (err) {
    console.log(`${name}  FETCH FAILED  ${err.message}`);
    continue;
  }
  if (res.status !== 200) {
    console.log(`${name}  HTTP ${res.status}`);
    continue;
  }
  const buf = Buffer.from(await res.arrayBuffer());
  const rows = lines(buf);
  const first = rows[1] ?? '(none)';
  const last = rows[rows.length - 1];
  console.log(`${name}  ${res.status}  ${buf.length} bytes  ${rows.length - 1} data rows`);
  console.log(`   first: ${first}`);
  console.log(`   last : ${last}`);

  if (item.control) {
    if (!existsSync(dest)) {
      console.log('   CONTROL: no local copy to compare against');
    } else {
      const local = readFileSync(dest);
      console.log(`   CONTROL: local ${local.length} bytes, identical=${local.equals(buf)}`);
    }
  }

  if (APPLY && !item.control) {
    writeFileSync(dest, buf);
    console.log(`   WROTE ${dest}`);
  }
}
