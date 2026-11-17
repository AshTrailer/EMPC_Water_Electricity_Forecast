// 补抓四个失败源。只新建 lit 下的文件，不改既有件。
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = 'C:/Ash/_research_20261013/lit';
const OUT = join(ROOT, '_gap');
mkdirSync(OUT, { recursive: true });

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36';

const targets = [
  { slug: 'vst_hsc1701', urls: ['https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_17_01.pdf'] },
  { slug: 'vst_efc17', urls: ['https://efc.pwr.edu.pl/assets/EFC17/Uniejewski_EFC17.pdf'] },
  { slug: 'ltsc_hsc1605', urls: ['https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_16_05.pdf'] },
  { slug: 'temporal_hsc_wp', urls: [
    'https://www.monash.edu/business/econometrics-and-business-statistics/research/publications/ebs/wp12-17.pdf',
    'https://www.monash.edu/business/ebs/research/publications/ebs/2017/wp12-2017.pdf',
    'https://robjhyndman.com/papers/Temporal.pdf',
    'https://robjhyndman.com/papers/temporalhierarchies.pdf'
  ] },
  { slug: 'ltsc_extrapolating_pdf', urls: ['https://arxiv.org/pdf/2503.02518'] },
  { slug: 'weron2022_review_pdf', urls: ['https://arxiv.org/pdf/2204.11735'] },
];

const results = [];
for (const t of targets) {
  const rec = { slug: t.slug, ok: false, url: null, bytes: 0, isPdf: false, tried: [] };
  for (const url of t.urls) {
    try {
      const r = await fetch(url, { headers: { 'User-Agent': UA, Accept: '*/*' }, redirect: 'follow' });
      const buf = Buffer.from(await r.arrayBuffer());
      const isPdf = buf.length > 2000 && buf.subarray(0, 5).toString('latin1') === '%PDF-';
      rec.tried.push({ url, status: r.status, bytes: buf.length, isPdf });
      if (r.ok && isPdf) {
        writeFileSync(join(OUT, `${t.slug}.pdf`), buf);
        rec.ok = true; rec.url = url; rec.bytes = buf.length; rec.isPdf = true;
        break;
      }
    } catch (e) {
      rec.tried.push({ url, err: String(e && e.message) });
    }
  }
  results.push(rec);
  console.log(rec.ok ? 'OK  ' : 'FAIL', t.slug, rec.ok ? `${rec.bytes} <- ${rec.url}` : JSON.stringify(rec.tried));
  await new Promise(r => setTimeout(r, 300));
}
writeFileSync(join(OUT, '_gap_fetch.json'), JSON.stringify(results, null, 1), 'utf8');
