// Pull the scenario definitions out of AEMO's pre-dispatch sensitivities paper.
// No PDF library is installed, so the streams are inflated by hand and the text
// operators are captured; that is enough for a Word-generated document whose
// text is plain ASCII.
//
// Usage: node probe_sens_doc.mjs

import { writeFileSync } from "node:fs";
import { inflateSync, inflateRawSync } from "node:zlib";
import { join } from "node:path";

const ROOT = "C:\\Ash\\Projects\\EMPC_Water_Electricity_Forecast";
const OUT = join(ROOT, "AEMO_Data", "_probe_sens");
const urls = [
  "https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/dispatch/policy_and_process/pre-dispatch-sensitivities.pdf",
  "https://www.aemo.com.au/-/media/Files/PDF/Pre_Dispatch_Sensitivities_6_1_March_2014.pdf",
];

for (const url of urls) {
  try {
    const r = await fetch(url, { redirect: "follow" });
    if (!r.ok) {
      console.log(`${url} -> HTTP ${r.status}`);
      continue;
    }
    const buf = Buffer.from(await r.arrayBuffer());
    writeFileSync(join(OUT, "sens_doc.pdf"), buf);
    console.log(`${url}\n  ${buf.length} bytes -> sens_doc.pdf`);

    // every stream object, inflated where possible
    const text = [];
    let i = 0;
    let n_stream = 0;
    while ((i = buf.indexOf("stream", i)) >= 0) {
      let start = i + 6;
      if (buf[start] === 13) start++;
      if (buf[start] === 10) start++;
      const end = buf.indexOf("endstream", start);
      if (end < 0) break;
      const raw = buf.subarray(start, end);
      n_stream++;
      let out = null;
      for (const fn of [inflateSync, inflateRawSync]) {
        try {
          out = fn(raw);
          break;
        } catch {
          /* not this one */
        }
      }
      if (out) text.push(extract(out.toString("latin1")));
      i = end + 9;
    }
    const joined = text.join("\n");
    writeFileSync(join(OUT, "sens_doc.txt"), joined, "utf8");
    console.log(`  ${n_stream} streams, ${joined.length} chars of text extracted`);
    const hits = joined
      .split("\n")
      .filter((l) => /scenario|Scenario|sensitivity|perturb|region demand/i.test(l))
      .slice(0, 40);
    console.log(hits.map((l) => `   | ${l.trim().slice(0, 200)}`).join("\n"));
    break;
  } catch (e) {
    console.log(`${url} -> ${e.message}`);
  }
}

function extract(s) {
  // text-showing operators only: (literal) Tj, [(a)(b)] TJ, ' and "
  const lines = [];
  const re = /\((?:\\.|[^\\()])*\)/g;
  for (const block of s.split(/BT|ET/)) {
    const parts = block.match(re);
    if (!parts) continue;
    const line = parts
      .map((p) => p.slice(1, -1).replace(/\\([()\\])/g, "$1").replace(/\\[0-9]{3}/g, " "))
      .join("");
    if (line.trim().length > 1) lines.push(line);
  }
  return lines.join("\n");
}
