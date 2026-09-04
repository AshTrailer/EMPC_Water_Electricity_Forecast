%% ============================================================
%  RUN_PREDICTION_EXPERIMENT  电价日模板 + AR 递归预测实验
%
%  预测协议:
%     - 每天 00:00 (即前一天最后一个采样点 24:00) 生成未来
%       24 小时 (288 步) 的预测
%     - 预测时冻结 RLS 的 AR 系数, 递归递推 288 步
%     - 预测后, 当天真实数据逐步"到达", 继续在线更新 RLS 系数
%     - 模板按方案每日更新 (类别内滚动窗口重建 / 截断 EWMA)
%
%  图1: 三种模型对比 (回答"为什么纯 AR 预测不了 6 小时")
%       行1: 纯 AR(4) 递归预测 (无模板)
%       行2: AR(4) + 全体日模板 (1月全部平均, 不分类)
%       行3: AR(4) + 工作日/周末日模板
%
%  图2: 模板窗口策略对比 (回答"均值采用多久")
%       行1: AR(4) + 区分模板, 类别内滚动窗口 (工作日 7 个工作日,
%            周末 7 个周末日) —— 类别分离, 消除周末样本不足
%       行2: AR(4) + 区分模板, 类别内滚动窗口 (各 28 个类内天)
%       行3: AR(4) + 区分模板, 截断 EWMA (α=0.15, ε=0.01, K=28)
%
%  训练期: 2026-01 (31 天)   测试期: 2026-02-01 ~ 02-07 (7 天)
% ============================================================
%  RUN_PREDICTION_EXPERIMENT  Electricity price daily template + AR recursive forecasting experiment
%
%  Forecasting protocol:
%     - At 00:00 each day (i.e., the last sample point of the previous day at 24:00),
%       generate a forecast for the next 24 hours (288 steps)
%     - During forecasting, freeze the RLS AR coefficients and recursively propagate 288 steps
%     - After forecasting, the actual data of the day "arrives" step by step, and the RLS
%       coefficients continue to be updated online
%     - Templates are updated daily according to the scheme (rolling-window rebuild within
%       class / truncated EWMA)
%
%  Fig. 1: Comparison of three models (answering "why pure AR cannot forecast 6 hours")
%       Row 1: Pure AR(4) recursive forecast (no template)
%       Row 2: AR(4) + all-day template (average over entire January, no classification)
%       Row 3: AR(4) + weekday/weekend daily template
%
%  Fig. 2: Comparison of template window strategies (answering "how long should the mean be taken")
%       Row 1: AR(4) + class-specific template, rolling window within class (7 weekdays,
%              7 weekend days) -- class separation, eliminating weekend sample shortage
%       Row 2: AR(4) + class-specific template, rolling window within class (28 days per class)
%       Row 3: AR(4) + class-specific template, truncated EWMA (alpha=0.15, epsilon=0.01, K=28)
clear; close all; clc;

% ---- 路径设置 ----
project_root = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project";
addpath(fullfile(project_root, "filter"));
addpath(fullfile(project_root, "AR_RLS_predictor"));

% ---- 数据加载 ----
cfg = system_config();
aemo_data = load_aemo_data(fullfile(project_root, "data"));

t_all = aemo_data.time;
y_all = aemo_data.price;

n_slots_day = 288;   % Number of slots per day (5 minutes × 24 hours)
n_test_days = 7;     % Number of test days

% ---- Train/test split ----
% Train: 2026-01-01 00:05 ~ 2026-02-01 00:00 (31 days in January, 8928 points)
% Test: 2026-02-01 00:05 ~ 2026-02-08 00:00 (7 days, 2016 points)

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

assert(n_train == 31 * n_slots_day, 'Training period should be exactly 8928 points');
assert(n_test  == 7  * n_slots_day, 'Test period should be exactly 2016 points');

% ---- RLS parameters (consistent with filter/apply_rls_filter) ----
rls_params.lambda = cfg.filter.rls_lambda;   % 0.98
rls_params.delta  = cfg.filter.rls_delta;    % 100
rls_params.p      = cfg.filter.rls_order;    % 4

% ---- Truncated EWMA parameters ----
ewma_alpha      = 0.15;  % Forgetting factor: effective in-class memory ≈ 1/alpha ≈ 7 in-class days
ewma_min_weight = 0.01;  % Truncation threshold: days with weight < epsilon are discarded completely
ewma_K = max(1, floor(log(ewma_min_weight) / log(1 - ewma_alpha)));

fprintf("\n========== Prediction Experiment ==========\n");
fprintf("Training period: %s ~ %s (%d 点)\n", char(train_start), char(train_end), n_train);
fprintf("Test period: %s ~ %s (%d 点)\n", char(test_start), char(test_end), n_test);
fprintf("Truncated EWMA: α=%.2f, ε=%.2f → K=%d in-class days\n", ...
   ewma_alpha, ewma_min_weight, ewma_K);
fprintf("  (Weekday template covers last %d weekdays, weekend template covers last %d weekend day)\n", ...
   ewma_K, ewma_K);

%% ---------- Build templates ----------
% Fig.1 Model 2: all-day template (entire January, no classification, fixed during test)
tpl_all = build_daily_template(y_train, t_train, "none", Inf);
% Fig.1 Model 3: class-specific template (entire January, weekday/weekend, fixed during test)
tpl_ws  = build_daily_template(y_train, t_train, "weekday_weekend", Inf);
% Fig.2 Scheme A/B: initial templates for in-class rolling windows (for warm-up)
tplA0 = build_daily_template(y_train, t_train, "weekday_weekend", [7, 7]);
tplB0 = build_daily_template(y_train, t_train, "weekday_weekend", [28, 28]);
% Fig.2 Scheme C: initial state for truncated EWMA (entire January with exponential weights)
[tplC0, day_bufC] = init_ewma_state(y_train, t_train, ewma_alpha, ewma_min_weight);

%% ---------- RLS warm-up (online training, point-by-point update on January data) ----------
% Model 1 (pure AR) models the centered series: otherwise AR has no intercept term and recursive forecasts decay to 0
center1 = mean(y_train);
rls1 = struct();  rls2 = struct();  rls3 = struct();
rlsA = struct();  rlsB = struct();  rlsC = struct();

for i = 1:n_train
   y_i = y_train(i);
   t_i = t_train(i);
   slot = get_slot_index(t_i);
   cls  = get_day_class(t_i);

   [~, rls1] = apply_rls_filter(y_i - center1, rls1, rls_params);
   [~, rls2] = apply_rls_filter(y_i - tpl_all.values(1, slot), rls2, rls_params);
   [~, rls3] = apply_rls_filter(y_i - tpl_ws.values(cls, slot),  rls3, rls_params);
   [~, rlsA] = apply_rls_filter(y_i - tplA0.values(cls, slot),   rlsA, rls_params);
   [~, rlsB] = apply_rls_filter(y_i - tplB0.values(cls, slot),   rlsB, rls_params);
   [~, rlsC] = apply_rls_filter(y_i - tplC0.values(cls, slot),   rlsC, rls_params);
end

fprintf("RLS warm-up completed (%d points x 6 models).\n", n_train);

%% ---------- Test period main loop ----------
pred1 = zeros(n_test,1);  pred2 = zeros(n_test,1);  pred3 = zeros(n_test,1);
predA = zeros(n_test,1);  predB = zeros(n_test,1);  predC = zeros(n_test,1);

% Historical pool: all available data up to the current forecast time
t_hist = t_train;
y_hist = y_train;

tplA = tplA0;  tplB = tplB0;  tplC = tplC0;

for d = 1:n_test_days
   idx = (d-1)*n_slots_day + (1:n_slots_day);
   t_target = t_test(idx);

   % ---- At 00:00 each day: rebuild/update templates (only for Fig.2 schemes) ----
   % Scheme A/B: in-class rolling windows (weekdays and weekends counted separately)
   tplA = build_daily_template(y_hist, t_hist, "weekday_weekend", [7, 7]);
   tplB = build_daily_template(y_hist, t_hist, "weekday_weekend", [28, 28]);
   % Scheme C: truncated EWMA (push in the previous day, discard old data with weight<epsilon, recompute weighted template)
   [tplC, day_bufC] = update_template_ewma(tplC, day_bufC, ...
      y_hist(end-287:end), t_hist(end-287:end), ewma_alpha, ewma_min_weight);

   % ---- Freeze AR coefficients, recursively forecast 288 steps ----
   pred1(idx) = predict_ar_recursive(rls1.theta, rls1.history, n_slots_day) + center1;

   tpl2_seq = get_template_sequence(tpl_all, t_target);
   pred2(idx) = tpl2_seq + predict_ar_recursive(rls2.theta, rls2.history, n_slots_day);

   tpl3_seq = get_template_sequence(tpl_ws, t_target);
   pred3(idx) = tpl3_seq + predict_ar_recursive(rls3.theta, rls3.history, n_slots_day);

   tplA_seq = get_template_sequence(tplA, t_target);
   predA(idx) = tplA_seq + predict_ar_recursive(rlsA.theta, rlsA.history, n_slots_day);

   tplB_seq = get_template_sequence(tplB, t_target);
   predB(idx) = tplB_seq + predict_ar_recursive(rlsB.theta, rlsB.history, n_slots_day);

   tplC_seq = get_template_sequence(tplC, t_target);
   predC(idx) = tplC_seq + predict_ar_recursive(rlsC.theta, rlsC.history, n_slots_day);

   % ---- Replay actual data of the day, update RLS online ----
   for s = 1:n_slots_day
      y_true = y_test(idx(s));
      t_true = t_target(s);
      slot = get_slot_index(t_true);
      cls  = get_day_class(t_true);

      [~, rls1] = apply_rls_filter(y_true - center1, rls1, rls_params);
      [~, rls2] = apply_rls_filter(y_true - tpl_all.values(1, slot), rls2, rls_params);
      [~, rls3] = apply_rls_filter(y_true - tpl_ws.values(cls, slot),  rls3, rls_params);
      [~, rlsA] = apply_rls_filter(y_true - tplA.values(cls, slot),    rlsA, rls_params);
      [~, rlsB] = apply_rls_filter(y_true - tplB.values(cls, slot),    rlsB, rls_params);
      [~, rlsC] = apply_rls_filter(y_true - tplC.values(cls, slot),    rlsC, rls_params);
   end

   % Update historical pool
   t_hist = [t_hist; t_test(idx)];
   y_hist = [y_hist; y_test(idx)];
end

fprintf("Test period prediction completed (%d days x 288 steps).\n", n_test_days);

%% ---------- Metric summary ----------
err1 = y_test - pred1;  err2 = y_test - pred2;  err3 = y_test - pred3;
errA = y_test - predA;  errB = y_test - predB;  errC = y_test - predC;

model_names = {'Pure AR(4)                                                ', ...
               'AR(4)+All-day template                                    ', ...
               'AR(4)+Weekday/weekend template (fixed Jan)                ', ...
               'AR(4)+Weekday/weekend template (7-day in-class window)    ', ...
               'AR(4)+Weekday/weekend template (28-day in-class window)   ', ...
               sprintf('AR(4)+Weekday/weekend template (truncated EWMA alpha=%.2f)', ewma_alpha)};
err_cells = {err1, err2, err3, errA, errB, errC};

fprintf("\n========== Overall Test Metrics (2026-02-01 ~ 02-07) ==========\n");
fprintf('%-58s %10s %10s\n', 'Model', 'RMSE', 'MAE');
for i = 1:6
   e = err_cells{i};
   fprintf('%-42s %10.1f %10.1f\n', model_names{i}, rms(e), mean(abs(e)));
end
fprintf('Signal std dev: %.1f $/MWh (RMSE close to this value = uninformative forecast)\n', std(y_test));

% RMSE aggregated by forecast horizon (288 rows = horizon, 7 columns = days)
fprintf("\nRMSE by forecast horizon ($/MWh):\n");
h_targets = [12, 36, 72, 144, 288];
fprintf('%0s %60s %8s %8s %8s %8s\n', 'Model', '1h', '3h', '6h', '12h', '24h');
for i = 1:6
   e_mat = reshape(err_cells{i}, n_slots_day, n_test_days);
   vals = arrayfun(@(h) rms(e_mat(h, :)), h_targets);
   fprintf('%-42s %8.1f %8.1f %8.1f %8.1f %8.1f\n', model_names{i}, vals);
end

%% ---------- Fig. 1: Comparison of three models (3x2) ----------
figure('Name', 'Fig. 1: Comparison of three forecasting models', 'Position', [40, 40, 1250, 950]);
tl1 = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

y_lim   = [min(y_test) - 0.1*range(y_test), max(y_test) + 0.1*range(y_test)];
err_lim = [min([err1;err2;err3]) - 0.1*range([err1;err2;err3]), ...
           max([err1;err2;err3]) + 0.1*range([err1;err2;err3])];
day_edges = t_test((1:n_test_days-1) * n_slots_day + 1);

plot_model_row(tl1, 1, t_test, y_test, pred1, 'Model 1: Pure AR(4) recursive forecast', 'r', y_lim, err_lim, day_edges);
plot_model_row(tl1, 2, t_test, y_test, pred2, 'Model 2: AR(4) + all-day template (no classification)', 'b', y_lim, err_lim, day_edges);
plot_model_row(tl1, 3, t_test, y_test, pred3, 'Model 3: AR(4) + weekday/weekend daily template', 'g', y_lim, err_lim, day_edges);

xlabel(tl1, 'Time');
tl1.Title.String = 'Fig. 1: Comparison of three forecasting models (2026-02-01 ~ 02-07, 24h forecast generated daily at 00:00)';

%% ---------- Fig. 2: Comparison of template window strategies (3x2) ----------
figure('Name', 'Fig. 2: Comparison of template window strategies', 'Position', [60, 60, 1250, 950]);
tl2 = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

err_lim2 = [min([errA;errB;errC]) - 0.1*range([errA;errB;errC]), ...
            max([errA;errB;errC]) + 0.1*range([errA;errB;errC])];

plot_model_row(tl2, 1, t_test, y_test, predA, ...
   'AR(4) + weekday/weekend template (7-day in-class window: 7 weekdays / 7 weekend days)', 'r', y_lim, err_lim2, day_edges);
plot_model_row(tl2, 2, t_test, y_test, predB, ...
   'AR(4) + weekday/weekend template (28-day in-class window)', 'b', y_lim, err_lim2, day_edges);
plot_model_row(tl2, 3, t_test, y_test, predC, ...
   sprintf('AR(4) + weekday/weekend template (truncated EWMA: alpha=%.2f, epsilon=%.2f, K=%d)', ewma_alpha, ewma_min_weight, ewma_K), ...
   'g', y_lim, err_lim2, day_edges);

xlabel(tl2, 'Time');
tl2.Title.String = 'Fig. 2: Comparison of template window strategies (all use AR(4)+weekday/weekend template, in-class windows)';

%% ============================================================
%  Local function: plot one row (left: actual vs forecast, right: error)
% ============================================================
function plot_model_row(tl, row, t_test, y_test, y_pred, model_name, col, y_lim, err_lim, day_edges)
   % Left column: actual vs forecast
   nexttile(tl, (row-1)*2 + 1);
   plot(t_test, y_test, 'k-', 'LineWidth', 1, 'DisplayName', 'Actual price');
   hold on;
   rmse_val = sqrt(mean((y_test - y_pred).^2));
   plot(t_test, y_pred, 'Color', col, 'LineWidth', 1, ...
      'DisplayName', sprintf('Forecast (RMSE=%.1f)', rmse_val));
   ylabel('Price ($/MWh)');
   ylim(y_lim);
   title(model_name);
   legend('Location', 'best');
   grid on;

   % Right column: error (actual - forecast)
   nexttile(tl, (row-1)*2 + 2);
   err = y_test - y_pred;
   plot(t_test, err, 'Color', col, 'LineWidth', 1, ...
      'DisplayName', 'Error (actual - forecast)');
   hold on;
   yline(0, 'k-', 'HandleVisibility', 'off');
   % Vertical dashed lines mark daily 00:00 boundaries -> visible error growth within each forecast block as horizon increases
   for k = 1:length(day_edges)
      xline(day_edges(k), 'k--', 'HandleVisibility', 'off');
   end
   ylabel('Error ($/MWh)');
   ylim(err_lim);
   title([model_name, ' : Forecast Error']);
   legend('Location', 'best');
   grid on;
end