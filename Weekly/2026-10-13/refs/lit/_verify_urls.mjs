// 校验报告里的每个 URL：GET + 重定向，报告最终状态码、类型、字节数。
import { readFileSync, writeFileSync } from 'node:fs';

const txt = readFileSync('C:/Ash/_research_20261013/lit/_verify_urls.txt', 'utf8');
const urls = txt.split(/\r?\n/).map(s => s.trim()).filter(s => s && !s.startsWith('#'));

const out = [];
for (const u of urls) {
  const rec = { url: u };
  const t0 = Date.now();
  try {
    const r = await fetch(u, {
      redirect: 'follow',
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36', Accept: 'text/html,application/xhtml+xml,application/pdf,*/*' },
    });
    const buf = Buffer.from(await r.arrayBuffer());
    rec.status = r.status;
    rec.ok = r.ok;
    rec.final = r.url;
    rec.type = (r.headers.get('content-type') || '').split(';')[0];
    rec.bytes = buf.length;
    rec.ms = Date.now() - t0;
    rec.looksHtml = buf.subarray(0, 400).toString('utf8').toLowerCase().includes('<html');
  } catch (e) {
    rec.err = String((e && e.message) || e);
    rec.ms = Date.now() - t0;
  }
  out.push(rec);
  console.log(`${rec.ok ? 'OK  ' : 'BAD '} ${rec.status || rec.err} ${rec.type || ''} ${rec.bytes || 0}B ${rec.url}`);
  await new Promise(r => setTimeout(r, 200));
}
writeFileSync('C:/Ash/_research_20261013/lit/_verify_urls.json', JSON.stringify(out, null, 1), 'utf8');
console.log('--- total', out.length, 'ok', out.filter(o => o.ok).length, 'bad', out.filter(o => !o.ok).length);
