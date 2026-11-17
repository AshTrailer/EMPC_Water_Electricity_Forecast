// 为 403 的 DOI 找可点开的替代开放地址（OpenAlex / Semantic Scholar 摘要页）。
import { readFileSync, writeFileSync } from 'node:fs';

const items = JSON.parse(readFileSync('C:/Ash/_research_20261013/lit/_alt_targets.json', 'utf8'));
const out = [];
for (const it of items) {
  const rec = { slug: it.slug, ...it };
  try {
    const r = await fetch(`https://api.openalex.org/works/doi:${it.doi}?mailto=research@example.org`);
    const w = await r.json();
    rec.title = w.title; rec.year = w.publication_year;
    rec.all = [w.open_access && w.open_access.oa_url, w.best_oa_location && (w.best_oa_location.pdf_url || w.best_oa_location.landing_page_url), ...(w.locations || []).map(l => l.pdf_url || l.landing_page_url)]
      .filter(Boolean).filter((v, i, a) => a.indexOf(v) === i);
  } catch (e) { rec.err = String(e && e.message); }
  try {
    const r2 = await fetch(`https://api.semanticscholar.org/graph/v1/paper/DOI:${it.doi}?fields=title,year,venue,abstract,openAccessPdf,externalIds`);
    if (r2.ok) {
      const s = await r2.json();
      rec.s2 = { title: s.title, year: s.year, venue: s.venue, oaPdf: s.openAccessPdf && s.openAccessPdf.url, abstract: (s.abstract || '').slice(0, 900), ids: s.externalIds };
    } else { rec.s2 = { http: r2.status }; }
  } catch (e) { rec.s2 = { err: String(e && e.message) }; }
  out.push(rec);
  console.log('=====', it.slug, '|', rec.year, '|', rec.title);
  console.log('   cands:', (rec.all || []).join(' | '));
  console.log('   s2oa:', rec.s2 && rec.s2.oaPdf, '| s2http:', rec.s2 && (rec.s2.http || 'ok'));
  if (rec.s2 && rec.s2.abstract) console.log('   abstract:', rec.s2.abstract.replace(/\s+/g, ' ').slice(0, 700));
  await new Promise(r => setTimeout(r, 400));
}
writeFileSync('C:/Ash/_research_20261013/lit/_alt_out.json', JSON.stringify(out, null, 1), 'utf8');
