import { writeFileSync } from 'node:fs';

const dois = [
  '10.1016/j.eswa.2012.01.039',            // Taieb et al multi-step strategies
  '10.1016/j.ijforecast.2018.06.001',      // M4 competition (to confirm)
  '10.2469/faj.v48.n5.28',                 // Black-Litterman (to confirm)
  '10.1109/access.2020.3014241',
  '10.3390/en13071667',
  '10.3390/en14113249',
  '10.3390/en11082039',
  '10.3390/en9080621',
  '10.1016/j.eswa.2012.01.039',
  '10.1016/j.energy.2022.123107',
  '10.1214/13-aoas652',
  '10.3390/en18246422',
  '10.3390/en18123097',
  '10.1016/j.apenergy.2024.124975',
  '10.48550/arxiv.2204.11735',
  '10.1016/j.apenergy.2021.118049',
  '10.1016/j.eswa.2012.01.039',
  '10.1111/j.1468-0084.2008.00541.x',
  '10.3905/jpm.2004.110',
  '10.1093/jjfinec/nbp001',
  '10.1016/j.ijforecast.2019.02.001',
  '10.1109/tpwrs.2016.2521545',
  '10.1016/j.eneco.2014.04.003',
  '10.1016/j.eneco.2014.07.014',
];
const out = [];
for (const d of dois) {
  try {
    const r = await fetch(`https://api.crossref.org/works/${encodeURIComponent(d)}?mailto=research@example.org`);
    if (!r.ok) { out.push({ doi: d, http: r.status }); continue; }
    const j = (await r.json()).message;
    out.push({
      doi: d, title: (j.title || [''])[0],
      year: j.issued && j.issued['date-parts'] && j.issued['date-parts'][0][0],
      venue: (j['container-title'] || [''])[0],
      authors: (j.author || []).map(a => `${a.given || ''} ${a.family || ''}`.trim()).slice(0, 5).join('; '),
      volume: j.volume, page: j.page,
    });
  } catch (e) { out.push({ doi: d, err: String(e && e.message) }); }
  await new Promise(r => setTimeout(r, 120));
}
writeFileSync('C:/Ash/_research_20261013/lit/_cr_results2.json', JSON.stringify(out, null, 1), 'utf8');
for (const o of out) console.log(`${o.doi}\n   ${o.year} | ${o.title || o.http || o.err}\n   ${o.authors}\n   ${o.venue} ${o.volume || ''} ${o.page || ''}`);
