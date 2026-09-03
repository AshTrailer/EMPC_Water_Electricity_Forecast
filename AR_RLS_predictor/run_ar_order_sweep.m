%% ============================================================
%  RUN_AR_ORDER_SWEEP  Pure AR(p) order sweep, p = 1 .. 10
%
%  Model (pure AR on centered series, no daily template):
%      y(t) = mu + r(t)
%      r(t) = sum_{j=1}^{p} phi_j * r(t-j) + eps(t)            (AR(p))
%      yhat(t+h|t) = mu + sum_{j=1}^{p} phi_j * rhat(t+h-j|t)  (iterated recursion)
%
%  Parameter under test:
%      p (AR order 1..10)  ->  memory length of the recursion;
%      affects short-horizon accuracy (1h) and decay speed toward mu
%
%  Fixed settings:
%      RLS: lambda = cfg.filter.rls_lambda, delta = cfg.filter.rls_delta
%      mu = mean of January prices (frozen)
%      protocol: daily 00:00 forecast, frozen coefficients, 288-step recursion
%      test period: 2026-02-01 ~ 02-07 (7 days)
%
%  Outputs:
%      Fig: per-horizon RMSE curves (x = horizon in hours)
%      Console: overall RMSE/MAE and RMSE at 1h/3h/6h/12h/24h per order
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
n_test_days = 7;

train_start = datetime(2026,1,1,0,5,0);
train_end   = datetime(2026,2,1,0,0,0);
test_start  = datetime(2026,2,1,0,5,0);
test_end    = datetime(2026,2,8,0,0,0);

train_mask = (t_all >= train_start) & (t_all <= train_end);
test_mask  = (t_all >= test_start) & (t_all <= test_end);
t_train = t_all(train_mask);
y_train = y_all(train_mask);
t_test  = t_all(test_mask);
y_test  = y_all(test_mask);

n_train = length(y_train);
n_test  = length(y_test);
assert(n_train == 31 * n_slots_day && n_test == 7 * n_slots_day, 'Period length mismatch');

p_list   = 1:10;
n_orders = numel(p_list);
center   = mean(y_train);

pred_all = zeros(n_test, n_orders);

for m = 1:n_orders
   p = p_list(m);
   rls_params.lambda = cfg.filter.rls_lambda;
   rls_params.delta  = cfg.filter.rls_delta;
   rls_params.p      = p;
   rls = struct();

   % RLS warm-up on January centered series
   for i = 1:n_train
      [~, rls] = apply_rls_filter(y_train(i) - center, rls, rls_params);
   end

   % daily 00:00 forecast (frozen coefficients), then replay the day through RLS
   for d = 1:n_test_days
      idx = (d-1)*n_slots_day + (1:n_slots_day);
      pred_all(idx, m) = predict_ar_recursive(rls.theta, rls.history, n_slots_day) + center;
      for s = 1:n_slots_day
         [~, rls] = apply_rls_filter(y_test(idx(s)) - center, rls, rls_params);
      end
   end
end

%% ---------- metrics ----------
err_all = y_test - pred_all;

rmse_overall = sqrt(mean(err_all .^ 2, 1));
mae_overall  = mean(abs(err_all), 1);

h_targets = [12 36 72 144 288];
rmse_h_target = zeros(n_orders, numel(h_targets));
rmse_h    = zeros(n_orders, n_slots_day);

for m = 1:n_orders
   e_mat = reshape(err_all(:, m), n_slots_day, n_test_days);
   rmse_h(m, :) = sqrt(mean(e_mat .^ 2, 2))';
   for k = 1:numel(h_targets)
      rmse_h_target(m, k) = sqrt(mean(e_mat(h_targets(k), :) .^ 2));
   end
   for hh = 1:24
      blk = e_mat((hh-1)*12 + (1:12), :);
      rmse_hour(m, hh) = sqrt(mean(blk(:) .^ 2));
   end
end

fprintf("\n========== Pure AR order sweep (2026-02-01 ~ 02-07) ==========\n");
fprintf('%-8s %10s %10s %8s %8s %8s %8s %8s\n', 'Order', 'RMSE', 'MAE', '1h', '3h', '6h', '12h', '24h');

fprintf('Signal std dev: %.1f $/MWh (RMSE near this = uninformative)\n', std(y_test));

[~, i_overall] = min(rmse_overall);
[~, i_1h]  = min(rmse_h_target(:, 1));
[~, i_24h] = min(rmse_h_target(:, 5));
fprintf('Best overall: AR(%d)   best 1h: AR(%d)   best 24h: AR(%d)\n', ...
   p_list(i_overall), p_list(i_1h), p_list(i_24h));

%% ---------- figure ----------
% Single-panel per-horizon RMSE; the 6h mark highlights where higher
% orders start to diverge (recursion ringing outweighs extra memory).
figure('Name', 'AR order sweep: per-horizon RMSE', 'Position', [40 40 1100 520]);
hold on;
cols = parula(n_orders);
for m = 1:n_orders
   plot((1:n_slots_day)/12, rmse_h(m, :), '-', 'Color', cols(m, :), 'LineWidth', 1);
end
yline(std(y_test), 'k--', 'LineWidth', 1);
xline(6, 'k:', 'LineWidth', 1);
hold off;
xlabel('Forecast horizon (h)');
ylabel('RMSE ($/MWh)');
title('Pure AR(p): per-horizon RMSE, p = 1..10 (2026-02-01 ~ 02-07)');
legend(arrayfun(@(p) sprintf('AR(%d)', p), p_list, 'UniformOutput', false), ...
   'Location', 'eastoutside');
grid on;
cb = colorbar;
cb.Label.String = 'RMSE ($/MWh)';
xlabel('Hour of day (h)');
ylabel('AR order p');
title('RMSE per hour block');