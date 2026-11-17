// Second OpenAlex pass: fill remaining gaps.
import { writeFileSync } from 'node:fs';

const queries = [
  'A Simple Approximate Long-Memory Model of Realized Volatility Corsi',
  'Direct multi-step estimation and forecasting Chevillon Journal of Economic Surveys',
  'Do We Really Need Both BEKK and DCC',
  'Forecasting electricity prices a review Weron 2014 International Journal of Forecasting',
  'Electricity price forecasting in the Danish market fundamentals available capacity interconnection',
  'The impact of wind and solar generation on electricity prices merit order effect',
  'Negative electricity prices in the German day-ahead market causes',
  'Electricity price forecasting negative prices quantile regression',
  'Regime switching models for electricity spot prices Weron',
  'Modelling electricity prices a comparison of regime switching jump diffusion',
  'Short term load forecasting typical load profile shape normalization',
  'Load profile based electricity price forecasting profile clustering',
  'Cross-temporal coherent forecasts for Australian tourism',
  'Temporal hierarchies',
  'Forecasting day-ahead electricity prices with a hybrid model seasonal decomposition',
  'Analysis and forecasting of electricity price risks with quantile factor models',
  'Complete subset regressions forecast',
  'Dimension reduction for out-of-sample prediction',
  'Equity premium prediction machine learning out-of-sample',
  'The term structure of variance risk premia',
  'Black-Litterman Global Portfolio Optimization',
  'Honey I shrunk the sample covariance matrix',
  'Improved estimation of the covariance matrix of stock returns with an application to portfolio selection',
  'Bias in the estimation of the mean-reversion parameter',
  'Sparse and stable Markowitz portfolios',
  'Forecasting electricity prices with deep learning transformer long horizon performance',
  'Empirical comparison of deep learning electricity price forecasting hybrid models unfair',
  'Nowcasting with large datasets a survey',
  'Mixed frequency models a survey',
  'Forecasting with MIDAS and bridge equations nowcasting comparison',
  'Temporal aggregation and forecast reconciliation'
];

const out = [];
for (const q of queries) {
  const url = `https://api.openalex.org/works?search=${encodeURIComponent(q)}&per-page=3&mailto=research@example.org`;
  try {
    const r = await fetch(url);
    if (!r.ok) { out.push({ q, error: String(r.status) }); continue; }
    const j = await r.json();
    const hits = (j.results || []).map(w => ({
      title: w.title,
      year: w.publication_year,
      doi: w.doi,
      cited: w.cited_by_count,
      oa: w.open_access && w.open_access.oa_url,
      venue: w.primary_location && w.primary_location.source && w.primary_location.source.display_name,
      authors: (w.authorships || []).slice(0, 3).map(a => a.author.display_name).join('; '),
    }));
    out.push({ q, hits });
  } catch (e) {
    out.push({ q, error: String(e && e.message) });
  }
  await new Promise(r => setTimeout(r, 150));
}

writeFileSync('C:/Ash/_research_20261013/lit/_oa_results2.json', JSON.stringify(out, null, 1), 'utf8');
console.log('done', out.length);
