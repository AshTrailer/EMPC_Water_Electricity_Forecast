// 补抓 temporal hierarchies 的作者主页版与机构库版。
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const OUT = 'C:/Ash/_research_20261013/lit/_gap';
mkdirSync(OUT, { recursive: true });
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36';

const cands = [
  ['temporal_kourentzes_pdf', 'https://kourentzes.com/forecasting/wp-content/uploads/2015/08/TempHier20150814_Kourentzes.pdf'],
  ['temporal_kourentzes_jina', 'https://r.jina.ai/https://kourentzes.com/forecasting/wp-content/uploads/2015/08/TempHier20150814_Kourentzes.pdf'],
  ['temporal_lancs_page', 'https://eprints.lancs.ac.uk/id/eprint/84905/'],
];

const log = [];
for (const [slug, url] of cands) {
  try {
    const r = await fetch(url, { headers: { 'User-Agent': UA, Accept: '*/*' } });
    const buf = Buffer.from(await r.arrayBuffer());
    const isPdf = buf.length > 2000 && buf.subarray(0, 5).toString('latin1') === '%PDF-';
    log.push({ slug, url, status: r.status, bytes: buf.length, isPdf });
    console.log(isPdf ? 'PDF ' : 'TXT?', slug, r.status, buf.length);
    if (isPdf) writeFileSync(join(OUT, `${slug}.pdf`), buf);
    else if (r.ok) writeFileSync(join(OUT, `${slug}.txt`), '# source: ' + url + '\n' + buf.toString('utf8'), 'utf8');
  } catch (e) {
    log.push({ slug, url, err: String(e && e.message) });
    console.log('ERR ', slug, String(e && e.message));
  }
  await new Promise(r => setTimeout(r, 300));
}
writeFileSync(join(OUT, '_gap_fetch3.json'), JSON.stringify(log, null, 1), 'utf8');
