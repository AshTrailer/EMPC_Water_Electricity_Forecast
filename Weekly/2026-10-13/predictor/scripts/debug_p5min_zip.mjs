/** Debug: what is actually inside one P5MIN inner zip. */
import { inflateRawSync } from "node:zlib";

const URL0 = "https://www.nemweb.com.au/Reports/ARCHIVE/P5_Reports/PUBLIC_P5MIN_20260811.zip";
const UA = { "User-Agent": "aemo-p5-debug/1.0" };

function readZipEntries(buf) {
   let p = buf.length - 22;
   while (p >= 0 && buf.readUInt32LE(p) !== 0x06054b50) p--;
   const count = buf.readUInt16LE(p + 10);
   let q = buf.readUInt32LE(p + 16);
   const entries = [];
   for (let i = 0; i < count; i++) {
      const method = buf.readUInt16LE(q + 10);
      const csize = buf.readUInt32LE(q + 20);
      const nlen = buf.readUInt16LE(q + 28);
      const elen = buf.readUInt16LE(q + 30);
      const clen = buf.readUInt16LE(q + 32);
      const lho = buf.readUInt32LE(q + 42);
      const flags = buf.readUInt16LE(q + 8);
      entries.push({ name: buf.toString("latin1", q + 46, q + 46 + nlen), method, csize, lho, flags });
      q += 46 + nlen + elen + clen;
   }
   return entries;
}

function readZipEntry(buf, e) {
   const nlen = buf.readUInt16LE(e.lho + 26);
   const elen = buf.readUInt16LE(e.lho + 28);
   const at = e.lho + 30 + nlen + elen;
   const raw = buf.subarray(at, at + e.csize);
   return e.method === 0 ? raw : inflateRawSync(raw);
}

const res = await fetch(URL0, { headers: UA });
const buf = Buffer.from(await res.arrayBuffer());
console.log("outer bytes", buf.length);
const outer = readZipEntries(buf);
console.log("outer entries", outer.length);
console.log("first three names:", outer.slice(0, 3).map((e) => e.name));
console.log("first three methods:", outer.slice(0, 3).map((e) => e.method));
console.log("first three flags:", outer.slice(0, 3).map((e) => e.flags));

const innerBuf = readZipEntry(buf, outer[0]);
console.log("inner bytes", innerBuf.length);
const inner = readZipEntries(innerBuf);
console.log("inner entries", inner.length, inner.map((e) => e.name));

const csvBuf = readZipEntry(innerBuf, inner[0]);
console.log("csv bytes", csvBuf.length);
const text = csvBuf.toString("utf8");
const lines = text.split("\n");
console.log("csv lines", lines.length);
console.log("--- first 6 lines ---");
for (const l of lines.slice(0, 6)) console.log(l.slice(0, 200));

const tables = new Set();
for (const l of lines) if (l.startsWith("I,P5MIN,")) tables.add(l.split(",")[2]);
console.log("tables:", [...tables]);

const rsHead = lines.find((l) => l.startsWith("I,P5MIN,REGIONSOLUTION,"));
console.log("REGIONSOLUTION header present:", Boolean(rsHead));
if (rsHead) console.log(rsHead.slice(0, 260));

let dcount = 0, vic = 0;
for (const l of lines) {
   if (!l.startsWith("D,P5MIN,REGIONSOLUTION,")) continue;
   dcount++;
   if (l.includes(",VIC1,")) vic++;
}
console.log("REGIONSOLUTION data rows", dcount, "with VIC1", vic);
