%% ============================================================
%  RUN_PREDICTOR_BENCHMARK  Unified predictor benchmark
%
%  Every predictor runs with update cadence = 1: each time a new 5-min
%  observation arrives, the predictor re-issues the full next 24 h
%  (288 steps). Every test point is therefore forecast 288 times, at
%  lead times h = 1..288, which yields a 288x288 RMSE matrix per
%  predictor (rows = target slot, cols = lead time).
%
%  Predictors (all warm-started online on January data):
%     1. Persistence         yhat = y(same slot, yesterday)
%     2. Rolling template    yhat = T(s), per-slot rolling mean
%     3. Theta-y tracker     yhat = theta(s) * y(same slot, yesterday),
%                            per-slot scalar RLS gain (lambda = 0.98)
%     4. Template + AR(4)    yhat = T(s) + rhat, ONE intraday AR(4) on
%                            consecutive residuals r = y - T (RLS,
%                            lambda = 0.98), iterated 288-step recursion
%     5. Blend A             yhat = w(s)*T(s) + (1-w(s))*rhat(s)
%     6. Blend B             yhat = w(s)*[theta(s)*y_yesterday] + (1-w(s))*rhat(s)
%     5/6 keep w in [0, 1], so the combination is always convex.
%
%  AR design note: the earlier per-slot CROSS-DAY AR(p) (same slot,
%  previous p days) was removed - same-slot values 24 h apart carry
%  almost no correlation and the AR added no short-term skill. All
%  cross-day memory lives in the template; the AR only chases the
%  current intraday level, so its regressors are CONSECUTIVE and the
%  forecast is iterated (lead-time dependent).
%
%  Price clamp: forecasts and actuals are clamped to [Q1, Q99] of a
%  rolling 30-day window of raw prices (global quantiles, recomputed
%  once per day). All RMSE/MAE are computed on clamped values, i.e. on
%  the signal the MPC actually receives. Model states (gains, AR
%  coefficients, template) are trained on raw prices.
%
%  Periods:
%     Warm-up (online)   : 2026-01-01 00:05 ~ 2026-01-30 24:00
%     Forecast origins   : 2026-01-31 00:05 ~ 2026-02-14 24:00
%     Test targets       : 2026-02-01 00:05 ~ 2026-02-15 00:00 (14 days)
%  Forecasting already starts on Jan 31 so that every Feb-1 target owns
%  the complete set of 288 lead times (full 288x288 matrices). Jan 31 is
%  streamed inside the origin loop (not in the warm-up), so each
%  observation is processed exactly once and causality holds.
%
%  Note: the January training window includes Australia Day (Jan 26);
%  it is kept as a regular weekday, as agreed.
% ============================================================
clear; close all; clc;

% ---- paths ----
project_root = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project";
predictor_root = fullfile(project_root, "Predicitor");

addpath(project_root);
addpath(genpath(predictor_root));

aemo_data = load_aemo_data(fullfile(project_root, "AEMO_Data"));
t_all = aemo_data.time;
y_all = aemo_data.price;

% ---- fixed settings ----
n_slots_day = 288;
p_ar = 4;                 % unified AR order
rls_lambda = 0.98;        % unified RLS forgetting factor
rls_delta = 100;          % initial RLS covariance scale
tpl_window_days = 28;     % rolling template memory (same-slot days)
clamp_window_days = 30;   % price-clamp rolling window
n_test_days = 14;
single_day = 9;           % Feb 9 (Monday) for the single-day comparison

% ---- periods ----
train_start = datetime(2026,1,1,0,5,0);
train_end   = datetime(2026,2,1,0,0,0);
test_start  = datetime(2026,2,1,0,5,0);
test_end    = datetime(2026,2,15,0,0,0);

assert(t_all(end) >= test_end, 'Data does not cover the two-week test period.');

train_mask = (t_all >= train_start) & (t_all <= train_end);
test_mask  = (t_all >= test_start) & (t_all <= test_end);
t_train = t_all(train_mask);
y_train = y_all(train_mask);
t_test  = t_all(test_mask);
y_test  = y_all(test_mask);
n_train = numel(y_train);
n_test  = numel(y_test);

assert(n_train == 31 * n_slots_day, 'Training period mismatch');
assert(n_test  == n_test_days * n_slots_day, 'Test period mismatch');

% ---- forecast origin series: Jan 31 (288 points) + the two test weeks ----
t_orig = [t_train(end-n_slots_day+1:end); t_test];
y_orig = [y_train(end-n_slots_day+1:end); y_test];
n_orig = numel(y_orig);   % 288 + 4032 = 4320

% ---- predictor initialization ----
tracker = init_theta_tracker(n_slots_day, rls_lambda, rls_delta);
tpl_ar  = init_template_ar(n_slots_day, p_ar, tpl_window_days, rls_lambda, rls_delta);
blend_a = init_blend_tmpl_ar(n_slots_day, rls_lambda, rls_delta);
blend_b = init_blend_yt_ar(n_slots_day, rls_lambda, rls_delta);
y_prev_ring = zeros(n_slots_day, 1);   % persistence: yesterday's raw price per slot

% ---- price clamp: daily [Q1, Q99] over a rolling 30-day window ----
% Initial window: the 30 complete days right before the test period
% (Jan 2 .. Jan 31). Each test day's thresholds are precomputed in a
% causal pass (a day's thresholds only use the preceding 30 days), so
% cross-midnight forecasts can be clamped with the thresholds of their
% target day.
y_win0 = reshape(y_train(n_slots_day+1:end), n_slots_day, clamp_window_days)';
clamp_st = init_price_clamp(y_win0);
q_by_day = zeros(n_test_days, 2);
q_by_day(1, :) = clamp_st.q;
for d = 1:n_test_days-1
   clamp_st = update_price_clamp(clamp_st, y_test((d-1)*n_slots_day + (1:n_slots_day))');
   q_by_day(d+1, :) = clamp_st.q;
end

% ---- warm-up: online updates over Jan 1 .. Jan 30 (no forecasting) ----
r1_prev = 0;       % 1-step residual-AR forecast for the next point
r1_ready = false;  % true once p consecutive residuals exist
for i = 1:n_train-n_slots_day
   slot = get_slot_index(t_train(i));
   y = y_train(i);

   % capture pre-update components (used by the blend weight updates)
   has_tpl = tpl_ar.cnt(slot) > 0;
   if has_tpl
      tpl_pre = tpl_ar.sum(slot) / tpl_ar.cnt(slot);
   end
   has_trk = tracker.has_prev(slot);
   if has_trk
      trk_xa = tracker.theta(slot) * tracker.y_prev(slot);
   end

   % stream the observation into the core predictors
   tpl_ar = update_template_ar(tpl_ar, slot, y);
   tracker = update_theta_tracker(tracker, slot, y);
   y_prev_ring(slot) = y;

   % adapt blend weights on the 1-step-ahead component pair
   if r1_ready
      if has_tpl
         blend_a = update_blend_weights(blend_a, slot, y, tpl_pre, r1_prev);
      end
      if has_trk
         blend_b = update_blend_weights(blend_b, slot, y, trk_xa, r1_prev);
      end
   end

   % 1-step intraday residual-AR forecast of the next point
   r1_ready = tpl_ar.n_hist >= p_ar;
   if r1_ready
      r1_prev = tpl_ar.phi' * tpl_ar.hist;
   end
end
fprintf("Warm-up completed: %d January points streamed through all predictors.\n", ...
   n_train - n_slots_day);

%% ---------- test loop: forecast 288 steps at every origin, then update ----------
n_models = 6;
n_cells_day = n_slots_day * n_slots_day;
err_sq = cell(n_models, 1);          % 288x288 squared-error accumulators
err_sq_day9 = cell(n_models, 1);     % same, restricted to the single day
for m = 1:n_models
   err_sq{m} = zeros(n_slots_day, n_slots_day);
   err_sq_day9{m} = zeros(n_slots_day, n_slots_day);
end
cnt_mat = zeros(n_slots_day, n_slots_day);   % samples per (slot, lead) cell
err_abs = zeros(n_models, 1);                % for MAE
err_bias = zeros(n_models, 1);               % mean error (bias)
err_abs_day9 = zeros(n_models, 1);           % for single-day MAE
err_day_sq = zeros(n_models, n_test_days);   % per-day squared-error sums
err_wk_sq = zeros(n_models, 2);              % per-week squared-error sums
pred_h1 = zeros(n_models, n_test);           % clamped 1-step forecast per test point

for i = 1:n_orig
   slot = get_slot_index(t_orig(i));
   y = y_orig(i);

   % ---- full 288-step forecasts (raw) ----
   u = target_slots(slot, n_slots_day);
   [y_tar, r_hat, t_vec] = predict_template_ar(tpl_ar, slot, n_slots_day);
   y_pers = y_prev_ring(u);
   y_trk = tracker.theta(u) .* tracker.y_prev(u);
   y_bla = predict_blend(blend_a.w(u), t_vec, r_hat);
   y_blb = predict_blend(blend_b.w(u), y_trk, r_hat);
   F = [y_pers, t_vec, y_trk, y_tar, y_bla, y_blb];

   % ---- clamp with the target day's thresholds and record errors ----
   h_vec = (1:n_slots_day)';
   j_vec = i + h_vec - n_slots_day;
   ok = (j_vec >= 1) & (j_vec <= n_test);
   jj = j_vec(ok);
   hh = h_vec(ok);
   if ~isempty(jj)
      d_tgt = floor((jj - 1) / n_slots_day) + 1;
      q1 = q_by_day(d_tgt, 1);
      q2 = q_by_day(d_tgt, 2);
      y_c = min(max(y_test(jj), q1), q2);
      s_tgt = mod(slot + hh - 1, n_slots_day) + 1;
      lin = (hh - 1) * n_slots_day + s_tgt;
      cnt_mat(lin) = cnt_mat(lin) + 1;
      day9 = (d_tgt == single_day);
      wk_idx = double(d_tgt <= 7) + 1;   % 1 = week 1, 2 = week 2
      for m = 1:n_models
         f_c = min(max(F(ok, m), q1), q2);
         e = y_c - f_c;
         err_sq{m}(lin) = err_sq{m}(lin) + e .^ 2;
         err_abs(m) = err_abs(m) + sum(abs(e));
         err_bias(m) = err_bias(m) + sum(e);
         err_day_sq(m, :) = err_day_sq(m, :) + accumarray(d_tgt, e .^ 2, [n_test_days, 1])';
         err_wk_sq(m, :) = err_wk_sq(m, :) + accumarray(wk_idx, e .^ 2, [2, 1])';
         if any(day9)
            err_sq_day9{m}(lin(day9)) = err_sq_day9{m}(lin(day9)) + e(day9) .^ 2;
            err_abs_day9(m) = err_abs_day9(m) + sum(abs(e(day9)));
         end
      end
   end

   % ---- clamped 1-step forecast, for the time-series figure ----
   j1 = i + 1 - n_slots_day;
   if j1 >= 1 && j1 <= n_test
      d1 = floor((j1 - 1) / n_slots_day) + 1;
      pred_h1(:, j1) = min(max(F(1, :)', q_by_day(d1, 1)), q_by_day(d1, 2));
   end

   % ---- capture pre-update components for the blend weight updates ----
   has_tpl = tpl_ar.cnt(slot) > 0;
   if has_tpl
      tpl_pre = tpl_ar.sum(slot) / tpl_ar.cnt(slot);
   end
   has_trk = tracker.has_prev(slot);
   if has_trk
      trk_xa = tracker.theta(slot) * tracker.y_prev(slot);
   end

   % ---- stream the observation into every predictor ----
   tpl_ar = update_template_ar(tpl_ar, slot, y);
   tracker = update_theta_tracker(tracker, slot, y);
   y_prev_ring(slot) = y;

   if r1_ready
      if has_tpl
         blend_a = update_blend_weights(blend_a, slot, y, tpl_pre, r1_prev);
      end
      if has_trk
         blend_b = update_blend_weights(blend_b, slot, y, trk_xa, r1_prev);
      end
   end

   % 1-step intraday residual-AR forecast of the next point
   r1_ready = tpl_ar.n_hist >= p_ar;
   if r1_ready
      r1_prev = tpl_ar.phi' * tpl_ar.hist;
   end
end
fprintf("Test loop completed: %d origins x 288-step forecasts x %d models.\n", n_orig, n_models);

%% ---------- metrics ----------
n_samples = n_cells_day * n_test_days;   % 14 * 288^2

model_names = ["Persistence (yesterday)", "Rolling template", ...
               "Theta-y tracker", "Template + AR(4) residual", ...
               "Blend A: w*T + (1-w)*r", "Blend B: w*thY + (1-w)*r"];
model_short = ["Persistence", "Template", "Theta-y", "T+AR(4)", "Blend A", "Blend B"];

rmse_mat = cell(n_models, 1);
rmse_2wk = zeros(n_models, 1);
rmse_day9 = zeros(n_models, 1);
mae_2wk = zeros(n_models, 1);
mae_day9 = zeros(n_models, 1);
bias_2wk = zeros(n_models, 1);
for m = 1:n_models
   rmse_mat{m} = sqrt(err_sq{m} ./ max(cnt_mat, 1));
   rmse_2wk(m) = sqrt(sum(err_sq{m}(:)) / n_samples);
   rmse_day9(m) = sqrt(sum(err_sq_day9{m}(:)) / n_cells_day);
   mae_2wk(m) = err_abs(m) / n_samples;
   mae_day9(m) = err_abs_day9(m) / n_cells_day;
   bias_2wk(m) = err_bias(m) / n_samples;
end

rmse_wk = sqrt(err_wk_sq / (7 * n_cells_day));    % n_models x 2 (week1, week2)
rmse_day = sqrt(err_day_sq / n_cells_day);        % n_models x 14

% aggregated views of the 288x288 matrices
lead_mean = zeros(n_models, n_slots_day);
lead_med = zeros(n_models, n_slots_day);
lead_std = zeros(n_models, n_slots_day);
slot_mean = zeros(n_models, n_slots_day);
for m = 1:n_models
   R = rmse_mat{m};
   lead_mean(m, :) = mean(R, 1);
   lead_med(m, :) = median(R, 1);
   lead_std(m, :) = std(R, 0, 1);
   slot_mean(m, :) = mean(R, 2)';
end

h_targets = [1 6 12 36 72 144 288];
h_labels = {'5min', '30min', '1h', '3h', '6h', '12h', '24h'};
rmse_h = zeros(n_models, numel(h_targets));
for m = 1:n_models
   rmse_h(m, :) = sqrt(sum(err_sq{m}(:, h_targets), 1) / (n_test_days * n_slots_day));
end
min_lead = min(lead_mean, [], 2);

% clamped actual series (per target day), for figures and signal std
y_test_c = y_test;
std_day = zeros(1, n_test_days);
for d = 1:n_test_days
   jj = (d-1)*n_slots_day + (1:n_slots_day);
   y_test_c(jj) = min(max(y_test(jj), q_by_day(d, 1)), q_by_day(d, 2));
   std_day(d) = std(y_test_c(jj));
end
day_dates = strings(1, n_test_days);
for d = 1:n_test_days
   day_dates(d) = string(t_test((d-1)*n_slots_day + 1), 'MM-dd');
end

%% ---------- console output ----------
fprintf("\n======================================================================\n");
fprintf(" PREDICTOR BENCHMARK - two-week test, 5-min update cadence\n");
fprintf("======================================================================\n");
fprintf("Warm-up (online training): %s ~ %s (%d points)\n", ...
   char(train_start), char(t_train(n_train-n_slots_day)), n_train - n_slots_day);
fprintf("Forecast origins         : %s ~ %s (%d origins)\n", ...
   char(t_orig(1)), char(t_orig(end)), n_orig);
fprintf("Test targets             : %s ~ %s (%d points, %d days)\n", ...
   char(t_test(1)), char(t_test(end)), n_test, n_test_days);
fprintf("Price clamp              : rolling %d-day window, global Q1/Q99, daily update\n", ...
   clamp_window_days);
fprintf("  Q1/Q99 at test start   : %7.1f / %7.1f $/MWh\n", q_by_day(1, 1), q_by_day(1, 2));
fprintf("  Q1/Q99 at test end     : %7.1f / %7.1f $/MWh\n", q_by_day(end, 1), q_by_day(end, 2));
fprintf("Clamped signal std       : %.1f $/MWh\n", std(y_test_c));
fprintf("Lead-time matrix coverage: %d..%d samples per (slot, lead) cell (expect %d)\n", ...
   min(cnt_mat(:)), max(cnt_mat(:)), n_test_days);
fprintf("AR regressors            : consecutive intraday residuals (cross-day slot AR removed)\n");

fprintf("\nTable 1  Aggregate accuracy (clamped prices, $/MWh)\n");
fprintf("%s\n", repmat('-', 1, 104));
fprintf('%-26s %10s %10s %10s %10s %10s %10s %10s\n', ...
   'Model', 'RMSE_2wk', 'RMSE_wk1', 'RMSE_wk2', 'MAE_2wk', 'Bias_2wk', 'RMSE_day9', 'MAE_day9');
fprintf("%s\n", repmat('-', 1, 104));
for m = 1:n_models
   fprintf('%-26s %10.1f %10.1f %10.1f %10.1f %10.1f %10.1f %10.1f\n', ...
      model_names(m), rmse_2wk(m), rmse_wk(m, 1), rmse_wk(m, 2), ...
      mae_2wk(m), bias_2wk(m), rmse_day9(m), mae_day9(m));
end
fprintf("%s\n", repmat('-', 1, 104));
fprintf("Single day: %s\n", char(t_test((single_day-1)*n_slots_day + 1)));

fprintf("\nTable 2  RMSE by forecast lead time, two-week aggregate (clamped, $/MWh)\n");
fprintf("%s\n", repmat('-', 1, 106));
fprintf('%-26s %9s %9s %9s %9s %9s %9s %9s %9s\n', ...
   'Model', h_labels{:}, 'min');
fprintf("%s\n", repmat('-', 1, 106));
for m = 1:n_models
   fprintf('%-26s %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f\n', ...
      model_names(m), rmse_h(m, :), min_lead(m));
end
fprintf("%s\n", repmat('-', 1, 106));
fprintf("RMSE near the clamped signal std (%.1f) = uninformative forecast.\n", std(y_test_c));

fprintf("\nTable 3  RMSE by test day, all lead times pooled (clamped, $/MWh)\n");
fprintf('%-26s', 'Model');
for d = 1:n_test_days
   fprintf(' %7s', day_dates(d));
end
fprintf('\n');
fprintf('%-26s', '');
for d = 1:n_test_days
   fprintf(' %7s', sprintf('D%d', d));
end
fprintf('\n');
for m = 1:n_models
   fprintf('%-26s', model_short(m));
   fprintf(' %7.1f', rmse_day(m, :));
   fprintf('\n');
end
fprintf('%-26s', 'Clamp Q1');
fprintf(' %7.1f', q_by_day(:, 1));
fprintf('\n');
fprintf('%-26s', 'Clamp Q99');
fprintf(' %7.1f', q_by_day(:, 2));
fprintf('\n');
fprintf('%-26s', 'Clamped std');
fprintf(' %7.1f', std_day);
fprintf('\n');

fprintf("\nTable 4  Lead-time RMSE profile across 288 slots (clamped, $/MWh)\n");
fprintf('%-26s %12s %12s %12s %12s\n', 'Model', 'min', 'min at (h)', 'median', 'max');
for m = 1:n_models
   [vmin, imin] = min(lead_mean(m, :));
   fprintf('%-26s %12.1f %12.1f %12.1f %12.1f\n', ...
      model_short(m), vmin, imin / 12, median(lead_mean(m, :)), max(lead_mean(m, :)));
end

fprintf("\nTable 5  Target-slot RMSE profile across 288 lead times (clamped, $/MWh)\n");
fprintf('%-26s %12s %12s %12s\n', 'Model', 'min', 'median', 'max');
for m = 1:n_models
   fprintf('%-26s %12.1f %12.1f %12.1f\n', ...
      model_short(m), min(slot_mean(m, :)), median(slot_mean(m, :)), max(slot_mean(m, :)));
end

fprintf("\nRMSE improvement vs persistence baseline (positive = better):\n");
fprintf('%-26s %12s %12s %12s\n', 'Model', '2wk', '5min', '24h');
for m = 1:n_models
   fprintf('%-26s %11.1f%% %11.1f%% %11.1f%%\n', model_short(m), ...
      100*(1 - rmse_2wk(m)/rmse_2wk(1)), ...
      100*(1 - rmse_h(m, 1)/rmse_h(1, 1)), ...
      100*(1 - rmse_h(m, end)/rmse_h(1, end)));
end

fprintf("\nBest model per lead time:\n");
for k = 1:numel(h_targets)
   [~, bm] = min(rmse_h(:, k));
   fprintf('  %-6s : %-28s (%.1f $/MWh)\n', h_labels{k}, model_names(bm), rmse_h(bm, k));
end

% AR short-term tracking check: T+AR(4) should beat the template at
% short leads and converge to it at long leads (recursion decays to 0).
i_t = 2;   % rolling template
i_a = 4;   % template + AR(4)
fprintf("\nAR short-term tracking check (T+AR(4) vs rolling template):\n");
for k = 1:numel(h_targets)
   fprintf('  lead %-6s : T+AR %6.1f vs T %6.1f  (diff %+5.1f $/MWh)\n', ...
      h_labels{k}, rmse_h(i_a, k), rmse_h(i_t, k), rmse_h(i_a, k) - rmse_h(i_t, k));
end

[~, ib] = min(rmse_2wk);
[~, ib1] = min(rmse_h(:, 1));
[~, ib24] = min(rmse_h(:, end));
fprintf("\nBest two-week RMSE : %s (%.1f $/MWh)\n", model_names(ib), rmse_2wk(ib));
fprintf("Best 5-min RMSE    : %s (%.1f $/MWh)\n", model_names(ib1), rmse_h(ib1, 1));
fprintf("Best 24-h RMSE     : %s (%.1f $/MWh)\n", model_names(ib24), rmse_h(ib24, end));

%% ---------- Fig. 1: two weeks, stacked and week-aligned ----------
week1_idx = 1:(7*n_slots_day);
week2_idx = week1_idx(end) + (1:7*n_slots_day);
w1_anchor = dateshift(t_test(1), 'start', 'day');               % Sunday, week 1
w2_anchor = dateshift(t_test(week2_idx(1)), 'start', 'day');    % Sunday, week 2
x1 = days(t_test(week1_idx) - w1_anchor);
x2 = days(t_test(week2_idx) - w2_anchor);

colors = lines(n_models);

figure('Name', 'Benchmark: week-aligned time series', 'Position', [40 40 1250 820]);
tl = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile(1);
hold on;
plot(x1, y_test_c(week1_idx), 'k-', 'LineWidth', 2, 'DisplayName', 'Actual (clamped)');
for m = 1:n_models
   plot(x1, pred_h1(m, week1_idx), '-', 'Color', colors(m, :), 'LineWidth', 1, ...
      'DisplayName', char(model_short(m)));
end
hold off;
xlim([0 7]);
xticks(0:7);
xticklabels({'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', ''});
grid on;
ylabel('Price ($/MWh)');
title('Week 1 (Feb 1 - Feb 7)');
legend('Location', 'eastoutside');

nexttile(2);
hold on;
plot(x2, y_test_c(week2_idx), 'k-', 'LineWidth', 2, 'DisplayName', 'Actual (clamped)');
for m = 1:n_models
   plot(x2, pred_h1(m, week2_idx), '-', 'Color', colors(m, :), 'LineWidth', 1);
end
hold off;
xlim([0 7]);
xticks(0:7);
xticklabels({'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', ''});
grid on;
ylabel('Price ($/MWh)');
title('Week 2 (Feb 8 - Feb 14)');

xlabel(tl, 'Time within week');
tl.Title.String = 'Two-week comparison, week-aligned (clamped prices, 1-step forecasts, update cadence = 5 min)';

%% ---------- Fig. 2: RMSE vs lead time, per model (mean/median +/- std) ----------
figure('Name', 'Benchmark: RMSE vs lead time', 'Position', [60 60 1250 700]);
tl2 = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
x_h = (1:n_slots_day) / 12;
y_max = max(lead_mean(:) + lead_std(:));
for m = 1:n_models
   nexttile(m);
   xb = [x_h, fliplr(x_h)];
   yb = [lead_mean(m, :) + lead_std(m, :), fliplr(lead_mean(m, :) - lead_std(m, :))];
   fill(xb, yb, colors(m, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
   hold on;
   plot(x_h, lead_mean(m, :), '-', 'Color', colors(m, :), 'LineWidth', 1);
   plot(x_h, lead_med(m, :), '--', 'Color', colors(m, :), 'LineWidth', 1);
   hold off;
   xlim([0 24]);
   ylim([0 y_max]);
   grid on;
   title(model_short(m));
   if m == 1
      legend({'mean +/- std (across slots)', 'mean', 'median'}, 'Location', 'northwest');
   end
end
xlabel(tl2, 'Lead time (h)');
ylabel(tl2, 'RMSE ($/MWh, clamped)');
tl2.Title.String = 'RMSE vs lead time: mean/median over the 288 target slots, band = +/- std across slots';

%% ---------- Fig. 3: RMSE by target slot ----------
figure('Name', 'Benchmark: RMSE by target slot', 'Position', [80 80 1250 440]);
hold on;
for m = 1:n_models
   plot((1:n_slots_day)/12, slot_mean(m, :), '-', 'Color', colors(m, :), 'LineWidth', 1);
end
hold off;
xticks(0:24);
xlabel('Target slot (hour of day)');
ylabel('RMSE ($/MWh, clamped)');
title('RMSE by target slot (averaged over all 288 lead times)');
legend(model_short, 'Location', 'eastoutside');
grid on;

%% ---------- Fig. 4: 288x288 RMSE matrices ----------
figure('Name', 'Benchmark: RMSE(slot, lead) matrices', 'Position', [100 100 1250 700]);
tl4 = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
colormap(turbo);
c_lim = [0, max(cellfun(@(R) max(R(:)), rmse_mat))];
for m = 1:n_models
   nexttile(m);
   imagesc(rmse_mat{m});
   clim(c_lim);
   set(gca, 'XTick', [1 72 144 216 288], 'XTickLabel', {'0', '6', '12', '18', '24'});
   set(gca, 'YTick', [1 72 144 216 288], 'YTickLabel', {'0', '6', '12', '18', '24'});
   title(model_short(m));
end
cb = colorbar;
cb.Layout.Tile = 'east';   % dedicated tile -> colorbar no longer covers the heatmaps
cb.Label.String = 'RMSE ($/MWh, clamped)';
cb.Ticks = linspace(c_lim(1), c_lim(2), 5);
cb.TickLabels = arrayfun(@(v) sprintf('%.0f', v), cb.Ticks, 'UniformOutput', false);

xlabel(tl4, 'Lead time (h)');
ylabel(tl4, 'Target slot (hour of day)');
tl4.Title.String = 'RMSE(slot, lead): 288x288 matrices (rows = target slot, columns = lead time)';