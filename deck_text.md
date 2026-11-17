<!-- Slide number: 1 -->

Electricity Price Forecasting for Economic MPC
of Water Pumping Systems
From AR + RLS to a six-model predictor suite — data, models, and benchmark results
AEMO NEM market data  ·  MATLAB  ·  Python data capture
Ash Trailer  ·  Capstone Project  ·  2026-09-15

<!-- Slide number: 2 -->
Project workflow and where forecasting fits
Wholesale spot price varies every 5 min — EMPC shifts pumping to cheap periods using forecasts
1
AEMO market
dispatch / pre-dispatch
Data capture
(Python)
AEMO_Data
CSV store
Price predictor
(short / long-term)
EMPC
(MPC layer)
Water supply
system

The predictor is one link in a closed loop:
•  MPC (tank-level optimisation) decides, over a receding horizon, how much total inflow the tanks need and when.
•  Decision (pump-combination optimisation) picks which pumps to run to deliver that inflow at minimum cost.
•  The price forecast feeds both layers; the control step and the spot price are aligned at 5 minutes.
Time scales: spot price + control step = 5 min; AEMO pre-dispatch forecast = 30-min grid, 48 h look-ahead.

<!-- Slide number: 3 -->
Data source — AEMO monthly price & demand files
Historical data: one CSV per region-month, publicly available from AEMO
2
Files: PRICE_AND_DEMAND_202601_VIC1.csv … PRICE_AND_DEMAND_202608_VIC1.csv
| REGION | SETTLEMENTDATE | TOTALDEMAND | RRP | PERIODTYPE |
| --- | --- | --- | --- | --- |
| VIC1 | 2026/01/01 00:05:00 | 4188.23 | 58.51 | TRADE |
| VIC1 | 2026/01/01 00:10:00 | 4169.89 | 25.66 | TRADE |
| VIC1 | 2026/01/01 00:15:00 | 4143.35 | 21.31 | TRADE |
•  RRP (Regional Reference Price, $/MWh) is the only column used as the electricity-price signal.
•  5-minute resolution: 288 slots per day; used for train / test splits and all predictor experiments.
•  Loaded via load_aemo_data(): returns time (datetime) and price vectors across the whole history.
Data range used in the benchmark: 2026-01-01 00:05 → 2026-08-09 00:00 (63,360 points, 5-min).

<!-- Slide number: 4 -->
Automated AEMO capture — Python (nemweb.com.au)
Replaces manual monthly downloads with a continuous fetch of current NEM reports
3
DispatchIS_Reports
Actual prices
Realised 5-min dispatch prices (RRP). NEMWEB keeps ~2 days; gaps refilled on startup.
PredispatchIS_Reports
30-min forecast
Official 30-min pre-dispatch forecast (RRP, ~48 h ahead).
P5_Reports
5-min forecast
Official 5-min P5 forecast (RRP).
Module architecture
aemo_config.py
paths · retention · URLs
aemo_common.py
time · listing · download
aemo_parser.py
record parsing (C/I/D)
aemo_store.py
append + evict + dedup
aemo_capture.py
orchestration loop

•  Continuous loop (default 60 s): one pass over all three listings, download zips, parse, merge, dedup, evict.
•  State (capture_state.json) tracks processed files + generation numbers to avoid re-downloading revisions.
Future: schedule/update the capture automatically with GitHub Actions.

<!-- Slide number: 5 -->
Capture stores, retention and dedup
Three append-only / batch-retention CSV stores under AEMO_Data
4
| Store file | Content | Retention policy |
| --- | --- | --- |
| dispatch\_actual.csv | Realised 5-min prices (RRP, EEP, demand) | Append forever; gaps back-filled ~2 days |
| predispatch\_forecast.csv | 30-min pre-dispatch forecasts | Keep last 10 runs (~5 h) |
| p5min\_forecast.csv | 5-min P5 forecasts | Keep last 60 runs (~5 h) |
•  Dedup keeps the highest RUNNO per interval/region (the last successful market solve).
•  Forecast stores keep only the latest N batches; older batches are evicted automatically.
•  Zip cache + state bookkeeping are pruned to bound disk usage; all timestamps normalised to AU local time.
•  This design feeds both the offline experiments (monthly CSV) and, going forward, live on-line forecasting.
Regions tracked: NSW1, QLD1, SA1, TAS1, VIC1.

<!-- Slide number: 6 -->
Core building block — adaptive RLS AR(p) filter
apply_rls_filter.m — estimates AR coefficients online with forgetting
5
Signal model:   y(k) = φ(k)Tθ + e(k),   φ(k) = [y(k−1), …, y(k−p)]T  ∈ ℝp
φ(k): regressor vector (p latest lags)  ·  θ: AR coefficient vector (p×1)  ·  e(k): scalar innovation
1. Gain (vector):
K = Pφ / (λ + φTPφ)   ∈ ℝp   (scalar denominator)
2. Prior error (scalar):
e = y−φTθ,  e ← clip(e, ±0.5)
3. Weight update:
θ ← θ + K·e
4. Covariance update:
P ← (P − KφTP) / λ
Numerical guards
•  P0 = δ·I  (δ = 100),  λ = 0.98
•  P symmetrised every step: P ← (P + PT)/2
•  Ridge damping: P ← P + εI  (ε = 1e−6)
•  Trace cap to stop P from blowing up
•  Condition-number check → soft restart
λ = forgetting factor; δ = initial covariance scale. Filter output y(k) = φ(k)ᵀθ.

<!-- Slide number: 7 -->
AR(p) model and iterated multi-step prediction
predict_ar_recursive.m — freeze coefficients, recurse forward over the horizon
6
AR(p) on a centred series  r(t) = y(t) − μ:      r(t) = Σj=1..p φj r(t−j) + e(t)
One-step-ahead:   r̂(t+1|t) = φT [r(t), r(t−1), …, r(t−p+1)]T
Iterated (recursive) h-step:   r̂(t+s|t) = φT [r̂(t+s−1|t), …, r̂(t+s−p|t)]T,   s = 1..h
•  Coefficients φ are frozen during the forecast; each predicted value is fed back into the buffer.
•  Forecast reconstruction:  ŷ(t+s|t) = μ + r̂(t+s|t)   (or, with a template,  T(s) + r̂).
•  Without an intercept (no template), the recursion decays to 0 → pure AR can only 'chase' the short term.
RLS supplies φ; the recursion is what makes long-horizon AR forecasts collapse to the mean.

<!-- Slide number: 8 -->
Daily template — the cross-day memory
build_daily_template.m / init_ewma_state.m — a mean profile over 288 five-minute slots
7
Pointwise mean:  Tc(s) = (1/N) Σd ∈ Wc yd(s),   s = 1..288,  c ∈ {weekday, weekend}
yd(s): price at slot s on day d ·  Wc: window of the last N days of class c ·  slot 288 = 24:00
•  Class split: weekday vs weekend templates, so weekend samples don't dilute the weekday mean.
•  Rolling window rebuilds the template daily at 00:00 (7-day, 28-day, or in-class windows).
•  Truncated EWMA: exponential weights (1−α)k over in-class days, truncated at K = ⌊ln ε / ln(1−α)⌋.
EWMA template:  Tc(s) = Σk=0..n−1 wk pk(s) / Σk wk,    wk = (1−α)k
k = 0 newest day ·  α = 0.15, ε = 0.01 → K = 28 in-class days ·  bounded buffer, no infinite memory
get_slot_index.m maps a timestamp to slot 1..288; get_day_class.m maps to weekday/weekend.

<!-- Slide number: 9 -->
Experiment 1 — AR vs AR + daily template
run_prediction_experiment.m — does a template fix the long-horizon collapse of pure AR?
8

![exp1_three_models.png](Picture4.jpg)
•  Protocol: daily forecast at 00:00, freeze RLS, recurse 288 steps (24 h).
•  Three models compared:
•    Pure AR(4) (no template)
•    AR(4) + all-day template (Jan mean)
•    AR(4) + weekday/weekend template
•  Train: 2026-01 (31 days). Test: 2026-02-01 → 02-07.
•  Left column: actual vs forecast. Right column: error per horizon.
Vertical dashed lines mark 00:00 — error grows visibly within each 24-h block as horizon increases.

<!-- Slide number: 10 -->
Experiment 1 — key finding: short good, long bad
The template supplies the daily shape; AR only helps at short lead times
9
Why pure AR cannot forecast beyond ~6 hours:
•  AR has no intercept: iterated forecasts decay geometrically toward the mean within a few hours.
•  Adding a daily template restores the daily price shape — the forecast stays realistic out to 24 h.
•  At very short horizons (~1 h) all models track well; at 6–24 h the template dominates the AR term.

Takeaway: the daily template is the long-term component; the AR residual is a short-term correction. This exact split is what the later 'Template + intraday AR' predictor formalises.
Exact RMSE values are in the experiment log; the figures show the actual-vs-forecast trend and the error growth with horizon.

<!-- Slide number: 11 -->
Experiment 2 — template window strategies
run_prediction_experiment.m (Fig. 2) — how many days should the mean span?
10
•  Three window strategies for the class-specific template:
•    7-day in-class rolling window
•    28-day in-class rolling window
•    Truncated EWMA (α=0.15, ε=0.01 → K=28)
•  Class windows count weekdays and weekends separately, equalising sample counts.
•  Longer / smoother windows track the slow daily shape better over the test week.

![exp2_window_strategies.png](Picture4.jpg)
All schemes still use AR(4) + weekday/weekend template; only the window differs.

<!-- Slide number: 12 -->
Experiment 3 — AR order sweep (p = 1…10)
run_ar_order_sweep.m — does raising the AR order help? (2026-02-01 → 02-07)
11
| Order | RMSE | MAE | 1h | 3h | 6h | 12h | 24h |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AR(1) | 51.63 | 39.26 | 16.48 | 36.49 | 53.43 | 49.53 | 39.81 |
| AR(2) | 51.32 | 39.29 | 17.09 | 38.14 | 56.00 | 48.10 | 36.63 |
| AR(3) | 51.04 | 39.08 | 16.42 | 36.95 | 54.40 | 49.47 | 34.83 |
| AR(4) | 51.84 | 39.51 | 16.28 | 36.35 | 53.29 | 52.62 | 36.18 |
| AR(5) | 52.29 | 39.82 | 16.18 | 36.35 | 53.35 | 53.01 | 38.87 |
| AR(6) | 53.82 | 41.01 | 16.30 | 36.95 | 54.50 | 53.78 | 47.01 |
| AR(7) | 55.81 | 42.52 | 16.22 | 36.77 | 54.19 | 55.61 | 56.11 |
| AR(8) | 57.92 | 43.90 | 16.25 | 36.73 | 54.30 | 57.16 | 65.14 |
| AR(9) | 59.56 | 44.84 | 16.03 | 36.59 | 54.15 | 58.04 | 72.59 |
| AR(10) | 65.29 | 47.72 | 16.77 | 38.80 | 57.32 | 59.15 | 94.89 |

![exp3_ar_order.png](Picture4.jpg)
Signal std = 58.0 $/MWh — RMSE near this is uninformative. Raising p gives no meaningful gain: best overall AR(3).

<!-- Slide number: 13 -->
Experiment 4 — forecast update cadence
run_update_cadence_sweep.m — pure AR(4), how often should we re-issue the forecast?
12

![exp4_update_cadence.png](Picture4.jpg)
| Cadence | Eff. horizon | RMSE | MAE |
| --- | --- | --- | --- |
| 5 min | 1..1 | 26.8 | 8.9 |
| 30 min | 1..6 | 29.2 | 11.9 |
| 1 h | 1..12 | 34.1 | 14.5 |
| 6 h | 1..72 | 57.2 | 37.3 |
| 24 h | 1..288 | 51.8 | 39.5 |
•  More frequent updates = lower overall RMSE.
•  Longer cadence = longer average lead time and staler RLS state.
24-h cadence can look good because its single 00:00 origin is the calmest part of the day (see origin-of-day table in log).

<!-- Slide number: 14 -->
Experiment 5 — no-split vs weekday/weekend template (89 days)
run_template_class_long_test.m — 28-day windows, 2026-02-01 → 2026-05-01
13

![exp5_template_class.png](Picture4.jpg)
| Subset | n | A RMSE | B RMSE | A MAE | B MAE | A ME | B ME |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Overall | 25632 | 134.0 | 278.5 | 46.0 | 49.2 | -9.3 | 12.9 |
| Weekdays | 18432 | 149.0 | 327.1 | 48.5 | 56.5 | -1.3 | 18.3 |
| Weekends | 7200 | 84.1 | 46.4 | 39.7 | 30.3 | -29.6 | -1.0 |
•  Weekday/weekend split (B) helps weekends a lot (84.1 → 46.4 RMSE) but hurts weekdays (149 → 327).
•  Split removes weekend contamination but also halves the weekday sample size → the split is a mixed result.
•  24-h weekday RMSE blows up (383 → 1040), confirming long-horizon weakness persists regardless of template.
A = no-split 28-day window; B = weekday/weekend 28-day in-class windows. ME = mean error (bias).

<!-- Slide number: 15 -->
Phase-1 summary — what the first experiments established
14
AR order
Raising p (1→10) gives no meaningful gain — AR(3)–AR(4) is enough.
Update cadence
Faster updates lower RMSE — every 5 min is best.
Template
The daily template is essential; it carries all cross-day memory.
Horizon
Short horizons are easy; beyond ~6 h every AR-based model degrades.
Class split
Weekday/weekend split helps weekends but is not a clear overall win.
→ Next: a unified benchmark of six predictors at 5-min cadence, scored on a 288×288 RMSE matrix.

<!-- Slide number: 16 -->

Part II — the six-model predictor suite
Unified on-line benchmark at 5-minute cadence, scored on a 288×288 RMSE matrix per predictor

<!-- Slide number: 17 -->
Benchmark protocol and price clamp
run_predictor_benchmark.m — every observation re-issues the full 24-h forecast
15
•  Update cadence = 1: each new 5-min observation triggers a fresh 288-step forecast.
•  Every test point is forecast 288 times (lead h = 1..288) → a 288×288 RMSE matrix per model.
•  Warm-up: all predictors trained on-line over Jan 1–30 (8,640 points).
•  Forecast origins start Jan 31 so every Feb-1 target owns all 288 lead times.
Price clamp
ŷclamped = clip(ŷ, Q1, Q99)
Q1 / Q99 = global 1% / 99% quantiles of a rolling 30-day raw-price window, recomputed daily.
•  Applied to forecasts and actuals — RMSE is scored on the exact signal the MPC receives.
•  Q1/Q99 at test start −60.0 / 299.5, at end −33.6 / 178.7 $/MWh.
The six predictors
1. Persistence — yesterday's same-slot price
2. Rolling template — per-slot rolling mean
3. Theta-y tracker — per-slot RLS gain on yesterday
4. Template + intraday AR(4) — template + residual recursion
5. Blend A — w·T + (1−w)·r̂
6. Blend B — w·(θ·yyesterday) + (1−w)·r̂
Model states (gains, AR coefficients, template) are trained on raw prices; scoring uses clamped prices.

<!-- Slide number: 18 -->
Predictor 1 & 2 — Persistence and rolling template
16

1. Persistence
ŷ(t+h|t) = y(s+h − 288)
Same slot, previous day — the naive baseline. s+h is the target slot; 288 = slots per day.
2. Rolling template
ŷ(t+h|t) = T(s+h)
T(s) = (1/W) Σ y(s) over the last W=28 samples of slot s. Pointwise rolling mean.
Why these are the anchors
•  Persistence is the reference every other model must beat.
•  The rolling template carries all cross-day memory with almost no parameters.
•  Both are constant over lead time — their RMSE is flat vs h (see benchmark).
•  Any AR-based model should beat these at short lead and converge to the template at long lead.

<!-- Slide number: 19 -->
Predictor 3 — Theta-y tracker
Per-slot scalar gain on yesterday's price, adapted by RLS
17
ŷ(t+h|t) = θ(s+h) · y(s+h − 288),      θ(s) ∈ ℝ  (scalar per-slot gain)
•  Prior θ0 = 1 recovers persistence exactly; RLS then learns whether yesterday over- or under-predicts.
•  Each slot is updated once per day (when its true value arrives), with regressor x = yprev(s) and target ytrue.
Scalar RLS update:   K = P·x / (λ + P·x²),   θ ← θ + K(y − θx),   P ← (1 − Kx)P / λ
x = yesterday's value for this slot ·  λ = 0.98 ·  all quantities scalar (per-slot state).
Implemented by rls_scalar_step.m, shared with the blend-weight updates.

<!-- Slide number: 20 -->
Predictor 4 — Template + intraday AR(4)
The core model: rolling template for the daily shape + AR for short-term tracking
18
Template (pointwise rolling mean):   T(s) ← T(s) + (y − yold) / W,    W = 28
Residual:   r(t) = y(t) − Tt(st),    Tt = template value BEFORE the update
•  Intraday AR(4) on CONSECUTIVE residuals:  r(t) = φT [r(t−1), …, r(t−4)] + e(t)
•  φ updated by vector RLS (λ=0.98) every 5 min — the AR chases the current residual level.
•  Cross-day per-slot regressors removed: same-slot values 24 h apart are nearly uncorrelated.
Forecast:   ŷ(u) = T(u) + r̂(u),     r̂(u) = iterated 288-step AR recursion from [r(t−1), …, r(t−4)]
Short leads chase the residual level; long leads decay to 0, so ŷ → T as h grows.
init/predict/update_template_ar.m — order of operations matters: residual is defined against the pre-update template.

<!-- Slide number: 21 -->
Predictor 5 & 6 — convex blends (Blend A and B)
Adaptively combine a long-term and a short-term component, per slot
19
ŷ = w(s)·x1 + (1 − w(s))·x2,      w(s) ∈ [0, 1]  (convex, per slot)
Blend A:  x1 = T (template),  x2 = r̂ (residual AR)          Blend B:  x1 = θ(s)·yyesterday,  x2 = r̂
•  Weight adaptation: rewrite ŷ − x2 = w·(x1 − x2), then scalar-RLS the single weight w on regressor d = x1 − x2.
•  w is clipped to [0,1] so the combination stays convex (weights sum to 1 exactly).
•  Initial w = 0.5; the update uses the 1-step-ahead component pair available before the true value arrives.
Scalar RLS for w:   K = P·d / (λ + P·d²),   w ← clip(w + K·(y − x2 − w·d), 0, 1)
Idea: when the AR residual struggles mid-day but the template matches well, w moves toward 1 (trust the template).
update_blend_weights.m / init_blend_tmpl_ar.m / init_blend_yt_ar.m.

<!-- Slide number: 22 -->
Benchmark results — aggregate & lead-time accuracy
Two-week test (Feb 1–14), clamped prices, $/MWh
20
| Model | RMSE 2wk | RMSE w1 | RMSE w2 | MAE | Bias | RMSE D9 |
| --- | --- | --- | --- | --- | --- | --- |
| Persistence | 51.2 | 47.2 | 54.9 | 38.8 | -5.2 | 68.7 |
| Rolling template | 46.4 | 46.1 | 46.7 | 36.6 | 9.6 | 63.1 |
| Theta-y tracker | 49.7 | 45.6 | 53.5 | 37.3 | 13.6 | 76.3 |
| T + AR(4) | 51.9 | 45.6 | 57.5 | 37.5 | 1.0 | 61.4 |
| Blend A | 55.6 | 49.1 | 61.5 | 41.3 | 23.1 | 69.5 |
| Blend B | 61.4 | 53.8 | 68.1 | 45.5 | 29.3 | 77.4 |
| Model | 5min | 30min | 1h | 3h | 6h | 12h | 24h |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Persistence | 51.2 | 51.2 | 51.2 | 51.2 | 51.2 | 51.2 | 51.2 |
| Template | 46.4 | 46.4 | 46.4 | 46.4 | 46.4 | 46.4 | 46.4 |
| Theta-y | 49.7 | 49.7 | 49.7 | 49.7 | 49.7 | 49.7 | 49.7 |
| T + AR(4) | 15.8 | 23.4 | 28.0 | 39.4 | 50.3 | 54.8 | 58.5 |
| Blend A | 38.0 | 41.0 | 43.9 | 49.1 | 53.8 | 57.0 | 62.6 |
| Blend B | 43.6 | 46.8 | 49.5 | 55.5 | 59.9 | 61.8 | 68.6 |
Reading the tables:
•  Persistence / template / theta-y are flat vs lead time (they only carry a daily signal).
•  T + AR(4) wins every short horizon (5 min = 15.8) but degrades past 6 h — exactly as designed.
•  The two blends sit between their components but never beat the best single model overall.
Clamped signal std = 51.3 $/MWh — RMSE near this value is an uninformative forecast.

<!-- Slide number: 23 -->
Benchmark results — RMSE(slot, lead) matrices
Full 288×288 RMSE surface per model (rows = target slot, cols = lead time)
21

![bench_rmse_lead.png](Picture4.jpg)

![bench_rmse_matrix.png](Picture3.jpg)
Left: heatmaps show persistence/template/theta-y are flat in lead time; T+AR(4) is sharp at short leads. Right: RMSE vs lead (mean/median ± std across slots).

<!-- Slide number: 24 -->
Benchmark results — per-slot profile & improvement
Where each model wins, and by how much vs the persistence baseline
22
| Model | 2wk | 5min | 24h |
| --- | --- | --- | --- |
| Persistence | 0.0% | 0.0% | 0.0% |
| Template | +9.3% | +9.3% | +9.3% |
| Theta-y | +2.9% | +2.9% | +2.9% |
| T + AR(4) | -1.4% | +69.2% | -14.3% |
| Blend A | -8.7% | +25.9% | -22.2% |
| Blend B | -19.9% | +14.8% | -34.1% |

![bench_rmse_slot.png](Picture5.jpg)
Best model per lead time
5 min → T + AR(4)   (15.8)
30 min → T + AR(4)  (23.4)
1 h → T + AR(4)     (28.0)
3 h → T + AR(4)     (39.4)
6 h → Template      (46.4)
12 h → Template     (46.4)
24 h → Template     (46.4)

![bench_week_aligned.png](Picture6.jpg)
Improvement vs persistence: positive = better. T+AR(4) gives +69% at 5 min but −14% at 24 h — a short-term specialist.

<!-- Slide number: 25 -->

Conclusions
●  The daily template is the indispensable long-term component — AR alone cannot forecast past ~6 h.
●  The residual AR is a short-term specialist: +69% over persistence at 5 min, useless by 24 h.
●  No single model wins everywhere — the right model depends on the MPC horizon.
●  Faster updates help; raising the AR order and splitting weekday/weekend give little or mixed benefit.
●  Price clamping to [Q1, Q99] keeps scoring honest on the signal the controller actually sees.

<!-- Slide number: 26 -->
Next steps
23
Automation
Schedule the Python capture with GitHub Actions for hands-off daily data refresh.
Holiday handling
Map public holidays into the template class logic to clean the weekday mean.
Kalman predictor
Finish the harmonic state-space Kalman predictor as an alternative long-term model.
EMPC integration
Wire the predictor into the MPC layer and validate cost savings on the tank system.
Forecast blending
Blend by lead time (AR for short, template for long) instead of one per-slot weight.
AEMO forecast data
Fold the official P5 / pre-dispatch forecasts in as an exogenous input.
