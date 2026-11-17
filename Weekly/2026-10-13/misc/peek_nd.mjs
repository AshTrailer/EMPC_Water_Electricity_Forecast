import { extractZip } from "./nemweb_peek.mjs";
for (const u of [
  "https://www.nemweb.com.au/Reports/CURRENT/Next_Day_Offer_Energy_SPARSE/PUBLIC_NEXT_DAY_OFFER_ENERGY_SPARSE_20261011_0000000542426900.zip",
  "https://www.nemweb.com.au/Reports/CURRENT/NEXT_DAY_AVAIL_SUBMISS_DAY/PUBLIC_NEXT_DAY_AVAIL_SUBMISS_DAY_20261011_0000000542426888.zip"]) {
  try {
    const r = await fetch(u, { headers: { "User-Agent": "Mozilla/5.0" } });
    if (!r.ok) { console.log(u, "HTTP", r.status); continue; }
    const es = extractZip(Buffer.from(await r.arrayBuffer()));
    const e = es.find(x => /\.csv$/i.test(x.name)) || es[0];
    const lines = e.data.toString("utf8").split(/\r?\n/);
    console.log("\n### " + u.split("/").pop() + "   entries " + es.length + "  lines " + lines.length);
    const hdrs = new Map();
    for (const l of lines) { if (l[0] !== "I") continue; const f = l.split(","); const k = f[1] + "|" + f[2]; if (!hdrs.has(k)) hdrs.set(k, f.slice(4).join(",")); }
    for (const [k, v] of hdrs) console.log("  " + k + "\n     " + v.slice(0, 400));
    const first = lines.find(l => l[0] === "D");
    if (first) console.log("  first D row: " + first.slice(0, 300));
  } catch (err) { console.log(u, "ERR", err.message); }
}