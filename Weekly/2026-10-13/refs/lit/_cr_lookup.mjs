// Resolve authoritative metadata for a fixed list of DOIs via Crossref.
import { writeFileSync } from 'node:fs';

const dois = [
  '10.1093/jjfinec/nbp001',
  '10.1111/j.1467-6419.2007.00518.x',
  '10.1111/j.1468-0262.00418',
  '10.1016/j.eneco.2023.106843',
  '10.1093/rfs/hhae044',
  '10.1016/j.jfineco.2021.09.013',
  '10.1016/j.ijforecast.2015.12.005',
  '10.1016/j.ijforecast.2018.09.006',
  '10.1016/j.ijforecast.2013.01.010',
  '10.1080/07474930600972467',
  '10.1016/j.ijforecast.2014.08.008',
  '10.1016/j.apenergy.2021.116983',
  '10.1016/j.apenergy.2018.02.069',
  '10.1016/j.apenergy.2017.11.098',
  '10.1016/j.eneco.2017.12.016',
  '10.1016/j.eneco.2016.05.009',
  '10.1109/tpwrs.2017.2734563',
  '10.1016/j.rser.2017.05.234',
  '10.1016/j.ijforecast.2014.12.004',
  '10.1016/j.eneco.2021.105121',
  '10.1016/j.csda.2011.03.006',
  '10.1080/01621459.2018.1448825',
  '10.1016/j.ejor.2017.02.046',
  '10.1016/j.ijforecast.2023.10.010',
  '10.1016/j.ijforecast.2023.10.003',
  '10.1016/j.annals.2019.02.001',
  '10.1016/j.ejor.2022.07.040',
  '10.1093/rfs/hhm014',
  '10.3386/w27410',
  '10.1016/j.jeconom.2024.105722',
  '10.1016/j.jeconom.2020.03.002',
  '10.1016/j.ijforecast.2013.12.003',
  '10.1016/j.ijforecast.2015.07.004',
  '10.1111/j.1468-0084.2008.00541.x',
  '10.1016/j.apenergy.2018.02.081',
  '10.1016/j.eneco.2018.11.007',
  '10.1016/j.apenergy.2018.07.076',
  '10.1016/j.eneco.2021.105445',
  '10.1016/j.apenergy.2022.118579',
  '10.1016/j.eneco.2020.104961',
  '10.1016/j.apenergy.2023.121141',
  '10.1016/j.eneco.2023.106583',
  '10.1016/j.enpol.2014.11.038',
  '10.1016/j.tej.2015.04.001',
  '10.1007/s10182-011-0181-2',
  '10.1109/tpwrs.2016.2521545',
  '10.1016/j.ijforecast.2019.02.001',
  '10.1016/j.jeconom.2013.04.017',
  '10.3905/jpm.2004.110',
  '10.1016/s0927-5398(03)00007-0',
  '10.1073/pnas.0904287106',
  '10.3386/w8160',
  '10.3386/w24967',
  '10.1093/rfs/hhaa047',
  '10.1016/j.eneco.2014.07.014',
];

const out = [];
for (const d of dois) {
  try {
    const r = await fetch(`https://api.crossref.org/works/${encodeURIComponent(d)}?mailto=research@example.org`);
    if (!r.ok) { out.push({ doi: d, http: r.status }); continue; }
    const j = (await r.json()).message;
    out.push({
      doi: d,
      title: (j.title || [''])[0],
      year: j.issued && j.issued['date-parts'] && j.issued['date-parts'][0][0],
      venue: (j['container-title'] || [''])[0],
      authors: (j.author || []).map(a => `${a.given || ''} ${a.family || ''}`.trim()).slice(0, 4).join('; '),
      volume: j.volume, page: j.page, type: j.type,
    });
  } catch (e) { out.push({ doi: d, err: String(e && e.message) }); }
  await new Promise(r => setTimeout(r, 120));
}
writeFileSync('C:/Ash/_research_20261013/lit/_cr_results.json', JSON.stringify(out, null, 1), 'utf8');
console.log(out.map(o => `${o.doi} :: ${o.year} :: ${o.title || o.http || o.err}`).join('\n'));
