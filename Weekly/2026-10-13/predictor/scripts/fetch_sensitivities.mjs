// List the ARCHIVE packs that cover the 60-day window and fetch one CURRENT run
// file, so the container can be inspected before 130 MB is pulled.
//
// Usage: node fetch_sensitivities.mjs list
//        node fetch_sensitivities.mjs one

import { writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const OUT = join(ROOT, "AEMO_Data", "_probe_sens");
const BASE = "https://nemweb.com.au/Reports";
const mode = process.argv[2] || "list";

if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });

const get = async (url) => {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`HTTP ${r.status} for ${url}`);
  return r;
};

if (mode === "list") {
  const html = await (await get(`${BASE}/ARCHIVE/Predispatch_Sensitivities/`)).text();
  const zips = [...new Set(html.match(/[A-Za-z0-9_.-]+\.zip/g) || [])].sort();
  for (const z of zips) {
    const m = z.match(/_(\d{8})_(\d{8})\.zip$/);
    if (!m) continue;
    if (m[1] >= "20260804" && m[1] <= "20261012") console.log(`  ${z}  ${m[1]}..${m[2]}`);
  }
} else if (mode === "one") {
  const html = await (await get(`${BASE}/CURRENT/Predispatch_Sensitivities/`)).text();
  const zips = [...new Set(html.match(/[A-Za-z0-9_.-]+\.zip/g) || [])].sort();
  const target = zips[zips.length - 1];
  const path = join(OUT, target);
  if (!existsSync(path)) {
    const buf = Buffer.from(await (await get(`${BASE}/CURRENT/Predispatch_Sensitivities/${target}`)).arrayBuffer());
    writeFileSync(path, buf);
    console.log(`wrote ${path}, ${buf.length} bytes`);
  } else {
    console.log(`already have ${path}`);
  }
}
