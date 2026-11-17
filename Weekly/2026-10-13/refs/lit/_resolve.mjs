// 用 OpenAlex 解析 DOI / 标题 -> arXiv id 与 OA pdf 地址，供 _fetch_pdf.mjs 使用。
import { writeFileSync, readFileSync } from 'node:fs';

const ROOT = 'C:/Ash/_research_20261013/lit';
const items = JSON.parse(readFileSync(`${ROOT}/_resolve_targets.json`, 'utf8'));

const out = [];
for (const it of items) {
  const rec = { slug: it.slug, want: it.doi || it.title, arxiv_id: null, oa_url: null, best_oa: null, title: null, year: null, doi: null };
  try {
    const url = it.doi
      ? `https://api.openalex.org/works/doi:${it.doi}?mailto=research@example.org`
      : `https://api.openalex.org/works?search=${encodeURIComponent(it.title)}&per-page=1&mailto=research@example.org`;
    const r = await fetch(url);
    const j = await r.json();
    const w = it.doi ? j : (j.results || [])[0];
    if (w) {
      rec.title = w.title; rec.year = w.publication_year; rec.doi = w.doi;
      rec.oa_url = w.open_access && w.open_access.oa_url;
      rec.best_oa = (w.best_oa_location && (w.best_oa_location.pdf_url || w.best_oa_location.landing_page_url)) || null;
      rec.locations = (w.locations || []).map(l => l.pdf_url || l.landing_page_url).filter(Boolean).slice(0, 6);
      const all = [w.doi, rec.oa_url, rec.best_oa, ...(w.locations || []).map(l => l.landing_page_url)].filter(Boolean).join(' ');
      const m = all.match(/arxiv\.org\/(?:abs|pdf)\/([0-9]{4}\.[0-9]{4,5})/);
      if (m) rec.arxiv_id = m[1];
      if (!rec.arxiv_id && w.ids && w.ids.mag) { /* ignore */ }
    }
  } catch (e) { rec.err = String(e && e.message); }
  out.push(rec);
  console.log(`${it.slug} | ${rec.year || '?'} | ${rec.title || '?'} | arxiv=${rec.arxiv_id || '-'} | oa=${rec.oa_url || '-'} | best=${rec.best_oa || '-'}`);
  console.log(`    locs: ${(rec.locations || []).join(' ; ')}`);
  await new Promise(r => setTimeout(r, 150));
}
writeFileSync(`${ROOT}/_resolve_out.json`, JSON.stringify(out, null, 1), 'utf8');
