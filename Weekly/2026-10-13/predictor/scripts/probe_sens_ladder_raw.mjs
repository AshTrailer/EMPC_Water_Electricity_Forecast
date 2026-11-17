/**
 * 打印单次发布里每个情景的 RRPEEP 值。
 *
 * 用法: node probe_sens_ladder_raw.mjs <zip 路径> [PERIODID]
 */
import { readFileSync } from 'node:fs';
import { inflateRawSync } from 'node:zlib';

function zipEntries(buf) {
   let eocd = -1;
   for (let i = buf.length - 22; i >= Math.max(0, buf.length - 66000); i--) {
      if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
   }
   if (eocd < 0) throw new Error('no EOCD');
   const n = buf.readUInt16LE(eocd + 10);
   let off = buf.readUInt32LE(eocd + 16);
   const out = [];
   for (let k = 0; k < n; k++) {
      const method = buf.readUInt16LE(off + 10);
      const csize = buf.readUInt32LE(off + 20);
      const nlen = buf.readUInt16LE(off + 28);
      const elen = buf.readUInt16LE(off + 30);
      const clen = buf.readUInt16LE(off + 32);
      const lho = buf.readUInt32LE(off + 42);
      const name = buf.toString('utf8', off + 46, off + 46 + nlen);
      out.push({ name, method, csize, lho });
      off += 46 + nlen + elen + clen;
   }
   return out;
}

function readEntry(buf, e) {
   const nlen = buf.readUInt16LE(e.lho + 26);
   const elen = buf.readUInt16LE(e.lho + 28);
   const start = e.lho + 30 + nlen + elen;
   const raw = buf.subarray(start, start + e.csize);
   return e.method === 0 ? raw : inflateRawSync(raw);
}

// 按引号切字段。
function splitCsv(line) {
   const out = [];
   let cur = '';
   let q = false;
   for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (q) {
         if (c === '"') {
            if (line[i + 1] === '"') { cur += '"'; i++; } else { q = false; }
         } else cur += c;
      } else if (c === '"') q = true;
      else if (c === ',') { out.push(cur); cur = ''; }
      else cur += c;
   }
   out.push(cur);
   return out;
}

const zipPath = process.argv[2];
const wantPeriod = process.argv[3] ? Number(process.argv[3]) : 1;
const buf = readFileSync(zipPath);
const e = zipEntries(buf).find((x) => /\.csv$/i.test(x.name));
const txt = readEntry(buf, e).toString('latin1');
const lines = txt.split(/\r?\n/);
let header = null;
const rows = [];
for (const ln of lines) {
   if (!ln) continue;
   if (ln.startsWith('I,PREDISPATCH,PRICESENSITIVITIES')) {
      header = splitCsv(ln).slice(4);
   } else if (ln.startsWith('D,PREDISPATCH,PRICESENSITIVITIES')) {
      // D 记录比 I 多一个版本号字段, 两者都要切掉前四个。
      const f = splitCsv(ln).slice(4);
      const o = {};
      header.forEach((h, i) => { o[h] = f[i]; });
      rows.push(o);
   }
}
const idx = header.map((h, i) => [h, i]);
const rrp = header.filter((h) => /^RRPEEP\d+$/.test(h));
console.log(`header fields=${header.length} rrp=${rrp.length}`);
console.log('fields: ' + header.join(','));

const runs = [...new Set(rows.map((r) => r.PREDISPATCHSEQNO + '/' + r.RUNNO))];
console.log(`rows=${rows.length} runs=${runs.length} first run=${runs[0]}`);
const periods = [...new Set(rows.map((r) => Number(r.PERIODID)))].sort((a, b) => a - b);
console.log(`periods=${periods.length} range=${periods[0]}..${periods[periods.length - 1]}`);

const run0 = runs[runs.length - 1];
for (const reg of ['VIC1', 'NSW1', 'SA1']) {
   const r = rows.find((x) => (x.PREDISPATCHSEQNO + '/' + x.RUNNO) === run0
      && x.REGIONID === reg && Number(x.PERIODID) === wantPeriod);
   if (!r) continue;
   console.log(`\n--- ${reg} run=${run0} period=${wantPeriod} datetime=${r.DATETIME} ---`);
   const vals = rrp.map((h) => [h.replace('RRPEEP', ''), Number(r[h])]);
   for (let i = 0; i < vals.length; i += 11) {
      console.log('  ' + vals.slice(i, i + 11).map(([k, v]) => `${k}:${v}`).join('  '));
   }
}

// 每个情景在 VIC1 上相对 RRPEEP1 的比例, 取全文件的中位数。
const num = (s) => { const v = Number(s); return Number.isFinite(v) ? v : NaN; };
console.log('\n=== median ratio to RRPEEP1 (VIC1, all rows, price>10) ===');
const vic = rows.filter((r) => r.REGIONID === 'VIC1' && num(r.RRPEEP1) > 10);
for (const h of rrp) {
   const rs = vic.map((r) => num(r[h]) / num(r.RRPEEP1)).filter((x) => Number.isFinite(x));
   rs.sort((a, b) => a - b);
   const med = rs[Math.floor(rs.length / 2)];
   const mean = rs.reduce((a, b) => a + b, 0) / rs.length;
   console.log(`  ${h}  n=${rs.length}  med=${med.toFixed(4)}  mean=${mean.toFixed(4)}`);
}
