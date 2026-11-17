// 下载一组论文 PDF 到 lit\_pdf\，逐个试候选 URL，落 manifest。只写在 lit 目录下。
import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = 'C:/Ash/_research_20261013/lit';
const OUT = join(ROOT, '_pdf');
mkdirSync(OUT, { recursive: true });

const readText = p => readFileSync(p, 'utf8');
const manifestPath = join(ROOT, '_pdf_manifest.json');
const manifest = existsSync(manifestPath) ? JSON.parse(readText(manifestPath)) : [];
const have = new Set(manifest.filter(m => m.ok).map(m => m.slug));

const targets = JSON.parse(readText(join(ROOT, '_pdf_targets.json')));

for (const t of targets) {
  if (have.has(t.slug)) { console.log('skip', t.slug); continue; }
  const dest = join(OUT, `${t.slug}.pdf`);
  const rec = { slug: t.slug, title: t.title, ok: false, url: null, bytes: 0, tried: [] };
  for (const url of t.urls) {
    try {
      const r = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (research; contact research@example.org)', Accept: 'application/pdf,*/*' } });
      const buf = Buffer.from(await r.arrayBuffer());
      const isPdf = buf.length > 2000 && buf.subarray(0, 5).toString('latin1') === '%PDF-';
      rec.tried.push({ url, status: r.status, bytes: buf.length, isPdf });
      if (r.ok && isPdf) {
        writeFileSync(dest, buf);
        rec.ok = true; rec.url = url; rec.bytes = buf.length;
        break;
      }
    } catch (e) {
      rec.tried.push({ url, err: String(e && e.message) });
    }
  }
  manifest.push(rec);
  console.log(rec.ok ? 'OK  ' : 'FAIL', t.slug, rec.ok ? `${rec.bytes} B <- ${rec.url}` : JSON.stringify(rec.tried));
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 1), 'utf8');
  await new Promise(r => setTimeout(r, 250));
}
console.log('manifest entries:', manifest.length, 'ok:', manifest.filter(m => m.ok).length);
