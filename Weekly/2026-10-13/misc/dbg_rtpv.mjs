import { extractZip } from "./nemweb_peek.mjs";
const url = "https://www.nemweb.com.au/Reports/ARCHIVE/ROOFTOP_PV/FORECAST/PUBLIC_ROOFTOP_PV_FORECAST_20260205.zip";
const r = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" } });
const buf = Buffer.from(await r.arrayBuffer());
console.log("zip bytes", buf.length);
const es = extractZip(buf);
console.log("entries", es.length);
console.log("first 8 names:", es.slice(0,8).map(e=>e.name).join(" | "));
const e0 = es[0];
const txt = e0.data.toString("utf8");
const lines = txt.split(/\r?\n/);
console.log("entry0 lines", lines.length);
for (const l of lines.slice(0,6)) console.log("  " + l.slice(0,220));
const hist = new Map();
for (const l of lines) { const k = l.split(",").slice(0,3).join("|"); hist.set(k,(hist.get(k)||0)+1); }
console.log("top table keys:", [...hist.entries()].sort((a,b)=>b[1]-a[1]).slice(0,8));