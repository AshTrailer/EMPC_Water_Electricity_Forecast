// Query OpenAlex for authoritative DOI + title of candidate papers.
import { writeFileSync } from 'node:fs';

const queries = [
  'A Comprehensive Look at the Empirical Performance of Equity Premium Prediction',
  'A Comprehensive 2022 Look at the Empirical Performance of Equity Premium Prediction',
  'Biases in long-horizon predictive regressions',
  'The forecast combination puzzle a simple theoretical explanation',
  'Machine learning for regularized survey forecast combination partially-egalitarian LASSO',
  'A comparison of mixed frequency approaches for nowcasting Euro area macroeconomic aggregates',
  'MIDAS Regressions Further Results and New Directions',
  'Modeling and Forecasting Realized Volatility',
  'Modeling and Forecasting Realized Volatility HAR',
  'The Econometrics of Financial Markets',
  'Roughing up beta good and bad betas',
  'Local projections vs VARs Lessons from thousands of DGPs',
  'Direct multi-step estimation and forecasting Chevillon',
  'Optimal combination forecasts for hierarchical time series',
  'Optimal Forecast Reconciliation for Hierarchical and Grouped Time Series Through Trace Minimization',
  'Benefits of availing load and renewable generation forecasts in electricity price forecasting',
  'Forecasting day-ahead electricity prices in Europe the importance of considering market integration',
  'Forecasting spot electricity prices Deep learning approaches and empirical comparison of traditional algorithms',
  'Forecasting day-ahead electricity prices a review of state-of-the-art algorithms best practices and an open-access benchmark',
  'Electricity price forecasting a review of the state-of-the-art with a look into the future',
  'Distributional neural networks for electricity price forecasting',
  'Day-ahead electricity price forecasting with high-dimensional structures univariate vs multivariate',
  'Importance of the long-term seasonal component in day-ahead electricity price forecasting',
  'Variance stabilizing transformations for electricity spot price forecasting',
  'Probabilistic electricity price forecasting with NARX networks a comparative analysis of predictive models',
  'Recent advances in electricity price forecasting a review of probabilistic forecasting',
  'Forecasting the intraday market price of money',
  'Probabilistic forecasting of electricity prices using quantile regression averaging',
  'An empirical comparison of electricity price forecasting methods',
  'N-BEATS neural basis expansion analysis for interpretable time series forecasting',
  'Do people mean what they say the great moderation',
  'Hierarchical forecasts for Australian domestic tourism',
  'Probabilistic forecast reconciliation properties evaluation and score optimisation',
  'The role of the long-term seasonal component in electricity price forecasting',
  'Forecasting realized volatility a comparison of HAR',
  'Interpretable optimal stopping for electricity price',
  'Machine learning for electricity price forecasting a review of recent advances',
  'Forecasting negative electricity prices',
  'Intraday electricity price forecasting with lasso',
  'A survey of electricity price forecasting with deep learning',
  'Bayesian shrinkage estimation of dynamic stochastic general equilibrium',
  'Forecasting with dynamic panel data models Minnesota prior',
  'Stein shrinkage forecast',
  'Temporal hierarchies forecast reconciliation',
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

writeFileSync('C:/Ash/_research_20261013/lit/_oa_results.json', JSON.stringify(out, null, 1), 'utf8');
console.log('done', out.length);
