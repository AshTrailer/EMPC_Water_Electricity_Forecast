// 用 jina 代理补抓两个仍然 403 的源。只写 lit _gap 下。
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const OUT = 'C:/Ash/_research_20261013/lit/_gap';
mkdirSync(OUT, { recursive: true });
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36';

const targets = [
  { slug: 'temporal_bath_jina', urls: [
    'https://r.jina.ai/https://researchportal.bath.ac.uk/files/153427625/EJOR_2017_Temporal_hierarchies_post_print_.pdf',
    'https://r.jina.ai/https://robjhyndman.com/papers/Temporal.pdf',
  ] },
  { slug: 'ltsc_hsc1605_jina', urls: [
    'https://r.jina.ai/https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_16_05.pdf',
    'https://r.jina.ai/http://www.im.pwr.wroc.pl/~hugo/RePEc/wuu/wpaper/HSC_16_05.pdf',
  ] },
  { slug: 'vst_hsc1701_jina', urls: [
    'https://r.jina.ai/https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_17_01.pdf',
  ] },
];

const log = [];
for (const t of targets) {
  for (const url of t.urls) {
    try {
      const r = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'text/plain,*/*' } });
      const txt = await r.text();
      const ok = r.ok && txt.length > 8000 && !/Are you a robot|captcha challenge/i.test(txt.slice(0, 3000));
      log.push({ slug: t.slug, url, status: r.status, chars: txt.length, ok });
      console.log(ok ? 'OK  ' : 'FAIL', t.slug, r.status, txt.length, url);
      if (ok) { writeFileSync(join(OUT, `${t.slug}.txt`), '# source: ' + url + '\n' + txt, 'utf8'); break; }
    } catch (e) {
      log.push({ slug: t.slug, url, err: String(e && e.message) });
      console.log('ERR ', t.slug, url, String(e && e.message));
    }
    await new Promise(r => setTimeout(r, 400));
  }
}
writeFileSync(join(OUT, '_gap_jina.json'), JSON.stringify(log, null, 1), 'utf8');
