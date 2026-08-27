%% ============================================================
%  RUN_UPDATE_CADENCE_SWEEP  Forecast update cadence sweep (pure AR)
%
%  Model: pure AR(4) on centered series (same as the order sweep):
%      yhat(t+h|t) = mu + sum_{j=1}^{4} phi_j * rhat(t+h-j|t)
%
%  Parameter under test:
%      K = update cadence (steps between two consecutive forecasts)
%          K = 1 (every 5 min), 6 (30 min), 12 (1 h), 72 (6 h), 288 (24 h)
%      -> the forecast for any point is taken from the most recent update,
%         so the effective horizon lies in [1, K];
%         larger K = longer average lead time = larger error, and also
%         staler RLS coefficients / history buffer
%
%  Fixed settings: AR(4), RLS (lambda, delta as configured),
%      mu = January mean, test = 2026-02-01 ~ 02-07
%
%  Outputs:
%      Fig: per-horizon RMSE (log x), RMSE by hour of day, overall RMSE bars
%      Console: overall RMSE/MAE per cadence + same-horizon comparison table
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
p_fixed = 4;

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

K_list  = [1 6 12 72 288];
K_label = {'5 min', '30 min', '1 h', '6 h', '24 h'};
n_cad   = numel(K_list);
center  = mean(y_train);

pred_cad = zeros(n_test, n_cad);
err_h    = cell(n_cad, 1);

for m = 1:n_cad
   K = K_list(m);

   rls_params.lambda = cfg.filter.rls_lambda;
   rls_params.delta  = cfg.filter.rls_delta;
   rls_params.p      = p_fixed;
   rls = struct();

   for i = 1:n_train
      [~, rls] = apply_rls_filter(y_train(i) - center, rls, rls_params);
   end

   n_upd = ceil(n_test / K);
   e_h = nan(K, n_upd);

   for u = 0:n_upd-1
      i0 = u * K + 1;
      if i0 > n_test
         break;
      end
      % snapshot at update time: forecast the next 288 steps
      f_pred = predict_ar_recursive(rls.theta, rls.history, n_slots_day) + center;
      n_h = min(K, n_test - i0 + 1);
      idx = i0 : i0 + n_h - 1;
      pred_cad(idx, m) = f_pred(1:n_h);
      e_h(1:n_h, u+1) = y_test(idx) - f_pred(1:n_h);

      % data of this block arrive and update RLS online
      for s = 1:n_h
         [~, rls] = apply_rls_filter(y_test(i0 + s - 1) - center, rls, rls_params);
      end
   end
   err_h{m} = e_h;
end

%% ---------- metrics ----------
err_cad = y_test - pred_cad;
rmse_cad = sqrt(mean(err_cad .^ 2, 1));
mae_cad  = mean(abs(err_cad), 1);

% RMSE by hour of day (0..23)
rmse_hod = zeros(n_cad, 24);
hour_test = hour(t_test);
for m = 1:n_cad
   for hh = 0:23
      mask = (hour_test == hh);
      rmse_hod(m, hh+1) = sqrt(mean(err_cad(mask, m) .^ 2));
   end
end

fprintf("\n========== Update cadence sweep, pure AR(%d) ==========\n", p_fixed);
fprintf('%-8s %12s %10s %10s\n', 'Cadence', 'EffHorizon', 'RMSE', 'MAE');
for m = 1:n_cad
   fprintf('%-8s %7d..%-5d %10.1f %10.1f\n', K_label{m}, 1, K_list(m), rmse_cad(m), mae_cad(m));
end

% same-horizon comparison (only cadences long enough to reach that horizon)
fprintf("\nRMSE at the same horizon across cadences ($/MWh):\n");
h_comp = [1 6 12 72 288];
fprintf('%-12s %10s %10s %10s %10s %10s\n', 'Horizon', K_label{:});
for i = 1:numel(h_comp)
   h = h_comp(i);
   row = nan(1, n_cad);
   for m = 1:n_cad
      if K_list(m) >= h
         row(m) = sqrt(mean(err_h{m}(h, :) .^ 2));
      end
   end
   fprintf('%-6d steps  %10.1f %10.1f %10.1f %10.1f %10.1f\n', h, row);
end

%% ---------- figure ----------
figure('Name', 'Update cadence sweep', 'Position', [40 40 1300 950]);
tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = parula(n_cad);

nexttile(tl, 1);
hold on;
for m = 1:n_cad
   h_axis = (1:K_list(m)) / 12;
   r_m = sqrt(mean(err_h{m} .^ 2, 2))';
   plot(h_axis, r_m, '-o', 'Color', cols(m, :), 'LineWidth', 1.5, 'MarkerSize', 4);
end
set(gca, 'XScale', 'log');
hold off;
xlabel('Forecast horizon (h, log scale)');
ylabel('RMSE ($/MWh)');
title('Per-horizon RMSE per update cadence');
legend(K_label, 'Location', 'best');
grid on;

nexttile(tl, 2);
hold on;
for m = 1:n_cad
   plot(0:23, rmse_hod(m, :), '-o', 'Color', cols(m, :), 'LineWidth', 1.5, 'MarkerSize', 4);
end
hold off;
xlabel('Hour of day (h)');
ylabel('RMSE ($/MWh)');
title('RMSE by hour of day per cadence');
legend(K_label, 'Location', 'best');
grid on;

nexttile(tl, 3, [1 2]);
bar(rmse_cad);
set(gca, 'XTick', 1:n_cad, 'XTickLabel', K_label);
ylabel('RMSE ($/MWh)');
title('Overall RMSE vs update cadence (more frequent updates = lower error)');
grid on;