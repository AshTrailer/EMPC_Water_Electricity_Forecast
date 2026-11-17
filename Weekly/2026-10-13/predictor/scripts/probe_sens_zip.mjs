/**
 * 列出 Predispatch Sensitivities 周包内的每个文件与每个 CSV 的表头。
 *
 * 用法: node probe_sens_zip.mjs <zip 路径>
 */
import { readFileSync } from 'node:fs';
import { inflateRawSync } from 'node:zlib';
import { basename } from 'node:path';

function zipEntries(buf) {
   // 扫 EOCD, 拿中央目录偏移与条目数。
   let eocd = -1;
   for (let i = buf.length - 22; i >= Math.max(0, buf.length - 66000); i--) {
      if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
   }
   if (eocd < 0) throw new Error('no EOCD');
   const n = buf.readUInt16LE(eocd + 10);
   let off = buf.readUInt32LE(eocd + 16);
   const out = [];
   for (let k = 0; k < n; k++) {
      if (buf.readUInt32LE(off) !== 0x02014b50) throw new Error('bad CD at ' + off);
      const method = buf.readUInt16LE(off + 10);
      const csize = buf.readUInt32LE(off + 20);
      const usize = buf.readUInt32LE(off + 24);
      const nlen = buf.readUInt16LE(off + 28);
      const elen = buf.readUInt16LE(off + 30);
      const clen = buf.readUInt16LE(off + 32);
      const lho = buf.readUInt32LE(off + 42);
      const name = buf.toString('utf8', off + 46, off + 46 + nlen);
      out.push({ name, method, csize, usize, lho });
      off += 46 + nlen + elen + clen;
   }
   return out;
}

function readEntry(buf, e) {
   const nlen = buf.readUInt16LE(e.lho + 26);
   const elen = buf.readUInt16LE(e.lho + 28);
   const start = e.lho + 30 + nlen + elen;
   const raw = buf.subarray(start, start + e.csize);
   if (e.method === 0) return raw;
   return inflateRawSync(raw);
}

const zipPath = process.argv[2];
const buf = readFileSync(zipPath);
const ents = zipEntries(buf);
console.log(`zip=${basename(zipPath)} entries=${ents.length}`);
for (const e of ents) {
   console.log(`  ${e.name}  usize=${e.usize} method=${e.method}`);
   if (!/\.csv$/i.test(e.name)) continue;
   const txt = readEntry(buf, e).toString('latin1');
   const lines = txt.split(/\r?\n/).filter((s) => s.length > 0);
   console.log(`    lines=${lines.length}`);
   for (let i = 0; i < Math.min(3, lines.length); i++) {
      console.log(`    [${i}] ${lines[i].slice(0, 400)}`);
   }
   console.log(`    [last] ${lines[lines.length - 1].slice(0, 240)}`);
}
