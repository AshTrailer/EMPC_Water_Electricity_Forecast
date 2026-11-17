// Third pass: find the remaining specific papers and get their true metadata.
import { writeFileSync } from 'node:fs';

const targets = [
  'Global Portfolio Optimization Black Litterman Financial Analysts Journal 1992',
  'Forecasting day-ahead electricity prices with a hybrid model using load and renewable forecasts fundamentals contribution',
  'Forecasting electricity prices with fundamentals load wind solar available capacity interconnector',
  'Multi-step ahead electricity price forecasting direct strategy recursive strategy comparison',
  'Probabilistic electricity price forecasting review deep learning 2024',
  'Forecasting intraday electricity prices with lasso variable selection very short-term',
  'The importance of the long-term seasonal component in day-ahead electricity price forecasting NARX',
  'Electricity price forecasting with deep learning a comparative study over 27 European markets',
  'Forecast evaluation with economic value electricity price forecasting trading strategy',
  'Long-term electricity price forecasting model review',
  'Forecasting the shape of the electricity price curve functional data approach',
  'Functional data analysis electricity price curve forecasting',
];

const out = [];
for (const q of targets) {
  const r = await fetch(`https://api.openalex.org/works?search=${encodeURIComponent(q)}&per-page=4&mailto=research@example.org`);
  const j = await r.json();
  out.push({
    q,
    hits: (j.results || []).map(w => ({
      title: w.title, year: w.publication_year, doi: w.doi, cited: w.cited_by_count,
      venue: w.primary_location && w.primary_location.source && w.primary_location.source.display_name,
      oa: w.open_access && w.open_access.oa_url,
    })),
  });
  await new Promise(r => setTimeout(r, 150));
}
writeFileSync('C:/Ash/_research_20261013/lit/_oa_results3.json', JSON.stringify(out, null, 1), 'utf8');
for (const e of out) {
  console.log('### ' + e.q);
  for (const h of e.hits) console.log(`   [${h.year}] ${h.doi} | ${h.title} | cites=${h.cited} | oa=${h.oa || ''}`);
}
