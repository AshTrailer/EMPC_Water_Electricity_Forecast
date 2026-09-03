%% ============================================================
%  RUN_TEMPLATE_CLASS_LONG_TEST  No-split vs weekday/weekend template
%                                on a 1-3 month test window
%
%  Templates (28-day rolling window, rebuilt daily at 00:00):
%      mode "none":            T(s)   = mean{y_d(s) : d in last 28 calendar days}
%      mode "weekday_weekend": T_c(s) = mean{y_d(s) : d in last 28 days of class c}
%
%  Residual AR(4) recursion (same as before):
%      r(t) = y(t) - T(t)
%      rhat(t+h|t) = sum_{j=1}^{4} phi_j * rhat(t+h-j|t)
%      yhat(t+h|t) = T(t+h) + rhat(t+h|t)
%
%  Parameter under test:
%      template class split (none vs weekday/weekend), evaluated on
%      disjoint subsets: all points / weekdays only / weekends only
%      -> the split should mainly reduce bias on weekend days; the
%         weekday-only comparison shows whether weekend samples
%         contaminate the no-split template
%
%  Fixed settings: AR(4), RLS (lambda, delta as configured),
%      window = 28 days (best config from last week),
%      test = 2026-02-01 ~ up to 2026-04-30 (auto-truncated if data ends earlier)
%
%  Note: public holidays (e.g. 2026-03-09 Labour Day, 2026-04-03 Good
%      Friday) are still counted as weekdays by get_day_class; this may
%      dilute the weekday template slightly. Holiday mapping is a
%      follow-up refinement, not done here to keep comparability with
%      last week's results.
%
%  Outputs:
%      Fig: weekday/weekend per-horizon RMSE and per-hour-of-day RMSE,
%           no-split vs split (2x2)
%      Console: overall / weekday-only / weekend-only RMSE, MAE, ME table
% ============================================================
clear; close all; clc;

project_root = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project";
addpath(fullfile(project_root, "filter"));
addpath(fullfile(project_root, "AR_RLS_predictor"));

cfg = system_config();
aemo_data = load_aemo_data(fullfile(project_root, "data"));
t_all = aemo_data.time;
y_all = aemo_data.price;

n_slots_day = 288;
p_fixed = 4;

train_start = datetime(2026,1,1,0,5,0);
train_end   = datetime(2026,2,1,0,0,0);
test_start  = datetime(2026,2,1,0,5,0);
test_end_goal = datetime(2026,5,1,0,0,0);

if t_all(end) < test_end_goal
   fprintf('Data ends at %s, test period truncated to that date.\n', char(t_all(end)));
end
test_end = min(test_end_goal, t_all(end));

train_mask = (t_all >= train_start) & (t_all <= train_end);
test_mask  = (t_all >= test_start) & (t_all <= test_end);
t_train = t_all(train_mask);
y_train = y_all(train_mask);
idx_test = find(test_mask);
n_test = floor(length(idx_test) / n_slots_day) * n_slots_day;
idx_test = idx_test(1:n_test);
t_test = t_all(idx_test);
y_test = y_all(idx_test);
n_train = length(y_train);
n_test_days = n_test / n_slots_day;

assert(n_train == 31 * n_slots_day, 'Training period mismatch');
assert(n_test_days >= 28, 'Test period too short for a monthly comparison');

%% ---------- initial templates and RLS warm-up ----------
tplA0 = build_daily_template(y_train, t_train, "none", 28);
tplB0 = build_daily_template(y_train, t_train, "weekday_weekend", [28, 28]);

rls_params.lambda = cfg.filter.rls_lambda;
rls_params.delta  = cfg.filter.rls_delta;
rls_params.p      = p_fixed;
rlsA = struct();
rlsB = struct();

for i = 1:n_train
   slot = get_slot_index(t_train(i));
   cls  = get_day_class(t_train(i));
   [~, rlsA] = apply_rls_filter(y_train(i) - tplA0.values(1, slot), rlsA, rls_params);
   [~, rlsB] = apply_rls_filter(y_train(i) - tplB0.values(cls, slot),  rlsB, rls_params);
end

%% ---------- test loop (same daily protocol as last week) ----------
predA = zeros(n_test, 1);
predB = zeros(n_test, 1);

t_hist = t_train;
y_hist = y_train;
tplA = tplA0;
tplB = tplB0;

for d = 1:n_test_days
   idx = (d-1)*n_slots_day + (1:n_slots_day);
   t_target = t_test(idx);

   % rebuild 28-day rolling templates at 00:00
   tplA = build_daily_template(y_hist, t_hist, "none", 28);
   tplB = build_daily_template(y_hist, t_hist, "weekday_weekend", [28, 28]);

   seqA = get_template_sequence(tplA, t_target);
   seqB = get_template_sequence(tplB, t_target);
   predA(idx) = seqA + predict_ar_recursive(rlsA.theta, rlsA.history, n_slots_day);
   predB(idx) = seqB + predict_ar_recursive(rlsB.theta, rlsB.history, n_slots_day);

   for s = 1:n_slots_day
      y_true = y_test(idx(s));
      slot = get_slot_index(t_target(s));
      cls  = get_day_class(t_target(s));
      [~, rlsA] = apply_rls_filter(y_true - tplA.values(1, slot), rlsA, rls_params);
      [~, rlsB] = apply_rls_filter(y_true - tplB.values(cls, slot),  rlsB, rls_params);
   end

   t_hist = [t_hist; t_target];
   y_hist = [y_hist; y_test(idx)];
end

%% ---------- metrics ----------
errA = y_test - predA;   % A = no-split template
errB = y_test - predB;   % B = weekday/weekend template

cls_test = get_day_class(t_test);
wd_mask = (cls_test == 1);
we_mask = (cls_test == 2);
n_wd = sum(wd_mask);
n_we = sum(we_mask);

subset_names  = {'Overall', 'Weekdays only', 'Weekends only'};
subset_masks  = {true(n_test, 1), wd_mask, we_mask};
subset_counts = [n_test; n_wd; n_we];

fprintf("\n========== No-split vs weekday/weekend template (28-day windows) ==========\n");
fprintf("Test period: %s ~ %s (%d days)\n", char(t_test(1)), char(t_test(end)), n_test_days);
fprintf("A = no-split 28-day window,  B = weekday/weekend 28-day in-class windows\n");
fprintf('%-16s %8s %10s %10s %10s %10s %10s %10s\n', ...
   'Subset', 'n_pts', 'A_RMSE', 'B_RMSE', 'A_MAE', 'B_MAE', 'A_ME', 'B_ME');
for s = 1:3
   m = subset_masks{s};
   fprintf('%-16s %8d %10.1f %10.1f %10.1f %10.1f %10.1f %10.1f\n', ...
      subset_names{s}, subset_counts(s), ...
      sqrt(mean(errA(m) .^ 2)), sqrt(mean(errB(m) .^ 2)), ...
      mean(abs(errA(m))), mean(abs(errB(m))), ...
      mean(errA(m)), mean(errB(m)));
end

% per-horizon and per-hour-of-day RMSE on weekday / weekend subsets
h_idx = mod((0:n_test-1)', n_slots_day) + 1;

rmse_h_wd_A = zeros(n_slots_day, 1);  rmse_h_wd_B = zeros(n_slots_day, 1);
rmse_h_we_A = zeros(n_slots_day, 1);  rmse_h_we_B = zeros(n_slots_day, 1);
for h = 1:n_slots_day
   m_wd = wd_mask & (h_idx == h);
   m_we = we_mask & (h_idx == h);
   rmse_h_wd_A(h) = sqrt(mean(errA(m_wd) .^ 2));
   rmse_h_wd_B(h) = sqrt(mean(errB(m_wd) .^ 2));
   rmse_h_we_A(h) = sqrt(mean(errA(m_we) .^ 2));
   rmse_h_we_B(h) = sqrt(mean(errB(m_we) .^ 2));
end

hour_test = hour(t_test);
rmse_hod_wd_A = zeros(24, 1);  rmse_hod_wd_B = zeros(24, 1);
rmse_hod_we_A = zeros(24, 1);  rmse_hod_we_B = zeros(24, 1);
for hh = 0:23
   m_wd = wd_mask & (hour_test == hh);
   m_we = we_mask & (hour_test == hh);
   rmse_hod_wd_A(hh+1) = sqrt(mean(errA(m_wd) .^ 2));
   rmse_hod_wd_B(hh+1) = sqrt(mean(errB(m_wd) .^ 2));
   rmse_hod_we_A(hh+1) = sqrt(mean(errA(m_we) .^ 2));
   rmse_hod_we_B(hh+1) = sqrt(mean(errB(m_we) .^ 2));
end

h_targets2 = [12 36 72 144 288];
fprintf("\nPer-horizon RMSE on subsets ($/MWh):\n");
fprintf('%-10s %12s %12s %12s %12s\n', 'Horizon', 'WD no-split', 'WD split', 'WE no-split', 'WE split');
for k = 1:numel(h_targets2)
   h = h_targets2(k);
   fprintf('%-10s %12.1f %12.1f %12.1f %12.1f\n', sprintf('%.0fh', h/12), ...
      rmse_h_wd_A(h), rmse_h_wd_B(h), rmse_h_we_A(h), rmse_h_we_B(h));
end

%% ---------- figure ----------
figure('Name', 'Template class split: long test', 'Position', [40 40 1300 950]);
tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile(tl, 1);
plot((1:n_slots_day)/12, rmse_h_wd_A, 'r-', 'LineWidth', 1.5, 'DisplayName', 'No-split template');
hold on;
plot((1:n_slots_day)/12, rmse_h_wd_B, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Weekday/weekend template');
hold off;
xlabel('Forecast horizon (h)');
ylabel('RMSE ($/MWh)');
title(sprintf('Weekday points only (%d days): per-horizon RMSE', n_wd/n_slots_day));
legend('Location', 'best');
grid on;

nexttile(tl, 2);
plot((1:n_slots_day)/12, rmse_h_we_A, 'r-', 'LineWidth', 1.5, 'DisplayName', 'No-split template');
hold on;
plot((1:n_slots_day)/12, rmse_h_we_B, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Weekday/weekend template');
hold off;
xlabel('Forecast horizon (h)');
ylabel('RMSE ($/MWh)');
title(sprintf('Weekend points only (%d days): per-horizon RMSE', n_we/n_slots_day));
legend('Location', 'best');
grid on;

nexttile(tl, 3);
plot(0:23, rmse_hod_wd_A, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', 'No-split template');
hold on;
plot(0:23, rmse_hod_wd_B, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', 'Weekday/weekend template');
hold off;
xlabel('Hour of day (h)');
ylabel('RMSE ($/MWh)');
title('Weekday points only: RMSE by hour of day');
legend('Location', 'best');
grid on;

nexttile(tl, 4);
plot(0:23, rmse_hod_we_A, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', 'No-split template');
hold on;
plot(0:23, rmse_hod_we_B, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', 'Weekday/weekend template');
hold off;
xlabel('Hour of day (h)');
ylabel('RMSE ($/MWh)');
title('Weekend points only: RMSE by hour of day');
legend('Location', 'best');
grid on;