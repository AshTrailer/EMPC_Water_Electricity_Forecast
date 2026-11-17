// Probe the NEMWEB ARCHIVE for the P5MIN daily zips we are missing.
const BASE = "https://www.nemweb.com.au/Reports/ARCHIVE/P5_Reports/PUBLIC_P5MIN_";
const days = [];
for (let d = 11; d <= 24; d++) days.push(`202608${String(d).padStart(2, "0")}`);
for (let d = 7; d <= 9; d++) days.push(`202610${String(d).padStart(2, "0")}`);

const head = async (day) => {
   const url = BASE + day + ".zip";
   try {
      const r = await fetch(url, { method: "HEAD", headers: { "User-Agent": "aemo-p5-probe/1.0" } });
      const len = r.headers.get("content-length");
      return { day, status: r.status, mb: len ? (Number(len) / 1048576).toFixed(2) : "?" };
   } catch (e) {
      return { day, status: "ERR " + e.message, mb: "-" };
   }
};

const out = await Promise.all(days.map(head));
for (const o of out) console.log(`${o.day}  ${String(o.status).padEnd(6)} ${o.mb} MB`);
console.log("probed", out.length);
