import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
const OUT = 'C:/Ash/_research_20261013/lit/_web';
mkdirSync(OUT, { recursive: true });
const targets = [
  { slug: 'smith_wallis2009', urls: [
    'http://www.bundesbank.de/download/vfz/konferenzen/20090323_24_berlin/discussion_wallis.pdf',
    'https://www.bundesbank.de/download/vfz/konferenzen/20090323_24_berlin/discussion_wallis.pdf',
    'https://ideas.repec.org/a/bla/obuest/v71y2009i3p331-355.html',
  ] },
  { slug: 'thief2025_full', urls: [
    'https://arxiv.org/pdf/2508.11372',
    'https://arxiv.org/html/2508.11372v2',
  ] },
  { slug: 'weron2022_forecasting_prices', urls: [
    'https://arxiv.org/abs/2204.11735',
  ] },
];
for (const t of targets) {
  let saved = null;
  for (const url of t.urls) {
    for (const prox of [false, true]) {
      const u = prox ? `https://r.jina.ai/${url}` : url;
      try {
        const r = await fetch(u, { headers: { 'User-Agent': 'Mozilla/5.0 (research; research@example.org)' } });
        const txt = await r.text();
        const okHead = txt.slice(0, 5) === '%PDF-' ? 'PDF' : 'TXT';
        if (r.ok && txt.length > 20000) {
          writeFileSync(join(OUT, `${t.slug}.${okHead === 'PDF' ? 'pdf.txt' : 'txt'}`), `# source: ${u} (${okHead})\n\n${txt}`, 'utf8');
          saved = { u, len: txt.length, okHead };
          break;
        }
      } catch (e) { /* next */ }
    }
    if (saved) break;
  }
  console.log(saved ? `OK   ${t.slug} ${saved.len} ${saved.okHead} <- ${saved.u}` : `FAIL ${t.slug}`);
}