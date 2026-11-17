// Minimal ZIP reader for NEMWEB single-CSV archives, plus a peek CLI.
// usage: node nemweb_peek.mjs <url> [maxRows]
import { inflateRawSync } from 'node:zlib';

export function extractZip(buf) {
  const eocd = buf.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  if (eocd < 0) throw new Error('no end-of-central-directory');
  const n = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  const out = [];
  for (let i = 0; i < n; i++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) throw new Error('bad central header');
    const method = buf.readUInt16LE(off + 10);
    const csize = buf.readUInt32LE(off + 20);
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const cmtLen = buf.readUInt16LE(off + 32);
    const lho = buf.readUInt32LE(off + 42);
    const name = buf.toString('utf8', off + 46, off + 46 + nameLen);
    const lNameLen = buf.readUInt16LE(lho + 26);
    const lExtraLen = buf.readUInt16LE(lho + 28);
    const start = lho + 30 + lNameLen + lExtraLen;
    const raw = buf.subarray(start, start + csize);
    out.push({ name, data: method === 0 ? raw : inflateRawSync(raw) });
    off += 46 + nameLen + extraLen + cmtLen;
  }
  return out;
}

if (process.argv[1] && process.argv[1].endsWith('nemweb_peek.mjs')) {
  const [url, maxRowsArg] = process.argv.slice(2);
  const maxRows = Number(maxRowsArg || 6);
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  if (!res.ok) { console.log('HTTP', res.status); process.exit(1); }
  const buf = Buffer.from(await res.arrayBuffer());
  console.log(`url ${url}`);
  console.log(`zip bytes ${buf.length}`);
  const entries = extractZip(buf);
  for (const e of entries) {
    const txt = e.data.toString('utf8');
    const lines = txt.split(/\r?\n/);
    console.log(`\n--- entry ${e.name}  ${e.data.length} bytes  ${lines.length} lines`);
    // NEMWEB CSV: rows start with C (comment/header), I (data), D (trailer)
    const tables = new Map();
    let cur = null;
    let shown = 0;
    for (const line of lines) {
      const f = line.split(',');
      if (f[0] === 'C' && f[1] === '00000000') continue; // report header
      if (f[0] === 'D') {
        const key = `${f[1]}|${f[2]}`;
        if (!tables.has(key)) tables.set(key, { head: null, rows: 0 });
        const t = tables.get(key);
        t.rows++;
        if (!t.head) t.head = f.slice(4);
        if (shown < maxRows) { console.log(`  D ${key} :: ${f.slice(4).join(',')}`); shown++; }
      } else if (f[0] === 'I' && f[2]) {
        const key = `${f[1]}|${f[2]}`;
        if (!tables.has(key)) tables.set(key, { head: null, rows: 0 });
        tables.get(key).head = f.slice(4);
      }
    }
    console.log('  tables:');
    for (const [k, v] of tables) {
      console.log(`    ${k.padEnd(34)} rows ${String(v.rows).padStart(7)}  cols ${(v.head || []).length}`);
      if (v.head) console.log(`        ${v.head.join(',')}`);
    }
  }
}
