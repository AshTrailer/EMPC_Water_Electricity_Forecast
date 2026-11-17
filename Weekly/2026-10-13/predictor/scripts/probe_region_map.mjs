// Find a public table that maps DUID to REGIONID.
//
// The offer tables carry no region field, so VIC1 selection needs an external
// list. This downloads the newest file in each small report folder, then prints
// every table whose header mentions DUID together with whether it also carries
// REGION. Files go to the private temp directory and are removed.

import { createInterface } from "node:readline";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createWriteStream, writeFileSync, rmSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { listEntries, openEntry } from "./lib/zip_stream.mjs";

const folders = process.argv.slice(2);

for (const url of folders) {
  let html;
  try {
    html = await (await fetch(url)).text();
  } catch (e) {
    console.log(`\n${url} FAILED ${e.message}`);
    continue;
  }
  const zips = [...new Set((html.match(/[\w()\-]+\.zip/gi) || []))].sort();
  const file = zips[zips.length - 1];
  if (!file) {
    console.log(`\n${url} no zip`);
    continue;
  }
  const tmp = join(tmpdir(), `probe_${randomBytes(4).toString("hex")}.zip`);
  const res = await fetch(url + file);
  writeFileSync(tmp, Buffer.from(await res.arrayBuffer()));
  console.log(`\n=== ${file}`);

  const entries = listEntries(tmp);
  const csv = entries.find((e) => /\.csv$/i.test(e.name)) || entries[0];
  const seen = new Map();
  const rl = createInterface({ input: openEntry(tmp, csv), crlfDelay: Infinity });
  for await (const line of rl) {
    const tag = line[0];
    if (tag !== "I" && tag !== "D") continue;
    const c = line.split(",");
    const t = c[2];
    if (typeof t !== "string" || t.length === 0) continue;
    if (tag === "I") seen.set(t, c.slice(4));
    else if (!seen.has(`${t}#`)) seen.set(`${t}#`, c.slice(4));
  }
  for (const [t, fields] of seen) {
    if (t.endsWith("#")) continue;
    if (!fields.some((f) => /DUID/i.test(f))) continue;
    const region = fields.some((f) => /REGION/i.test(f));
    console.log(`  ${t}  fields ${fields.length}  region ${region ? "YES" : "no"}`);
    if (region) {
      console.log(`    ${fields.join(" | ")}`);
      const s = seen.get(`${t}#`);
      if (s) console.log(`    sample: ${s.join(" | ")}`);
    }
  }
  rmSync(tmp, { force: true });
}
