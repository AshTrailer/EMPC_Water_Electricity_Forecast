%% ============================================================
%  RUN_PREDICTION_EXPERIMENT  电价日模板 + AR 递归预测实验
%
%  预测协议 (与教授会议纪要一致):
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

clear; close all; clc;

% ---- 路径设置 ----
project_root = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project";
addpath(fullfile(project_root, "filter"));
addpath(fullfile(project_root, "predictor"));

% ---- 数据加载 ----
cfg = system_config();
aemo_data = load_aemo_data(fullfile(project_root, "data"));

t_all = aemo_data.time;
y_all = aemo_data.price;

n_slots_day = 288;   % 每天槽位数 (5 分钟 × 24 小时)
n_test_days = 7;     % 测试期天数

% ---- 训练/测试期划分 ----
% 训练: 2026-01-01 00:05 ~ 2026-02-01 00:00 (1月31天, 8928点)
% 测试: 2026-02-01 00:05 ~ 2026-02-08 00:00 (7天, 2016点)
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

assert(n_train == 31 * n_slots_day, '训练期应恰为 8928 点');
assert(n_test  == 7  * n_slots_day, '测试期应恰为 2016 点');

% ---- RLS 参数 (与 filter/apply_rls_filter 一致) ----
rls_params.lambda = cfg.filter.rls_lambda;   % 0.98
rls_params.delta  = cfg.filter.rls_delta;    % 100
rls_params.p      = cfg.filter.rls_order;    % 4

% ---- 截断 EWMA 参数 ----
ewma_alpha      = 0.15;  % 遗忘因子: 类内有效记忆 ≈ 1/α ≈ 7 个类内天
ewma_min_weight = 0.01;  % 截断阈值: 权重 < ε 的天被彻底丢弃
ewma_K = max(1, floor(log(ewma_min_weight) / log(1 - ewma_alpha)));

fprintf("\n========== 预测实验 ==========\n");
fprintf("训练期: %s ~ %s (%d 点)\n", char(train_start), char(train_end), n_train);
fprintf("测试期: %s ~ %s (%d 点)\n", char(test_start), char(test_end), n_test);
fprintf("截断 EWMA: α=%.2f, ε=%.2f → K=%d 个类内天\n", ...
   ewma_alpha, ewma_min_weight, ewma_K);
fprintf("  (工作日模板覆盖最近 %d 个工作日, 周末模板覆盖最近 %d 个周末日)\n", ...
   ewma_K, ewma_K);

%% ---------- 构建模板 ----------
% 图1模型2: 全体模板 (1月全部, 不分类, 测试期固定)
tpl_all = build_daily_template(y_train, t_train, "none", Inf);
% 图1模型3: 区分模板 (1月全部, 工作日/周末, 测试期固定)
tpl_ws  = build_daily_template(y_train, t_train, "weekday_weekend", Inf);
% 图2方案A/B: 类别内滚动窗口的初始模板 (预热用)
tplA0 = build_daily_template(y_train, t_train, "weekday_weekend", [7, 7]);
tplB0 = build_daily_template(y_train, t_train, "weekday_weekend", [28, 28]);
% 图2方案C: 截断 EWMA 初始状态 (1月全部按指数权重)
[tplC0, day_bufC] = init_ewma_state(y_train, t_train, ewma_alpha, ewma_min_weight);

%% ---------- RLS 预热 (在线训练, 1月数据逐点更新) ----------
% 模型1 (纯AR) 对中心化序列建模: 否则 AR 无截距项, 递归预测会衰减到 0
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

fprintf("RLS 预热完成 (%d 点 × 6 模型)。\n", n_train);

%% ---------- 测试期主循环 ----------
pred1 = zeros(n_test,1);  pred2 = zeros(n_test,1);  pred3 = zeros(n_test,1);
predA = zeros(n_test,1);  predB = zeros(n_test,1);  predC = zeros(n_test,1);

% 历史池: 截至当前预测时刻的所有可用数据
t_hist = t_train;
y_hist = y_train;

tplA = tplA0;  tplB = tplB0;  tplC = tplC0;

for d = 1:n_test_days
   idx = (d-1)*n_slots_day + (1:n_slots_day);
   t_target = t_test(idx);

   % ---- 每日 00:00: 重建/更新模板 (仅图2方案) ----
   % 方案A/B: 类别内滚动窗口 (工作日与周末各自独立计数)
   tplA = build_daily_template(y_hist, t_hist, "weekday_weekend", [7, 7]);
   tplB = build_daily_template(y_hist, t_hist, "weekday_weekend", [28, 28]);
   % 方案C: 截断 EWMA (推入前一天, 丢弃权重<ε的旧数据, 重算加权模板)
   [tplC, day_bufC] = update_template_ewma(tplC, day_bufC, ...
      y_hist(end-287:end), t_hist(end-287:end), ewma_alpha, ewma_min_weight);

   % ---- 冻结 AR 系数, 递归预测 288 步 ----
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

   % ---- 回放当天真实数据, 在线更新 RLS ----
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

   % 更新历史池
   t_hist = [t_hist; t_test(idx)];
   y_hist = [y_hist; y_test(idx)];
end

fprintf("测试期预测完成 (%d 天 × 288 步)。\n", n_test_days);

%% ---------- 指标汇总 ----------
err1 = y_test - pred1;  err2 = y_test - pred2;  err3 = y_test - pred3;
errA = y_test - predA;  errB = y_test - predB;  errC = y_test - predC;

model_names = {'纯 AR(4)', ...
               'AR(4)+全体模板', ...
               'AR(4)+区分模板(固定1月)', ...
               'AR(4)+区分模板(类内7天窗口)', ...
               'AR(4)+区分模板(类内28天窗口)', ...
               sprintf('AR(4)+区分模板(截断EWMA α=%.2f)', ewma_alpha)};
err_cells = {err1, err2, err3, errA, errB, errC};

fprintf("\n========== 测试期整体指标 (2026-02-01 ~ 02-07) ==========\n");
fprintf('%-42s %10s %10s\n', '模型', 'RMSE', 'MAE');
for i = 1:6
   e = err_cells{i};
   fprintf('%-42s %10.1f %10.1f\n', model_names{i}, rms(e), mean(abs(e)));
end
fprintf('信号标准差: %.1f $/MWh (RMSE 接近此值 = 预测无信息)\n', std(y_test));

% 按预测时域聚合的 RMSE (288 行=horizon, 7 列=天)
fprintf("\n按预测时域的 RMSE ($/MWh):\n");
h_targets = [12, 36, 72, 144, 288];
fprintf('%-42s %8s %8s %8s %8s %8s\n', '模型', '1h', '3h', '6h', '12h', '24h');
for i = 1:6
   e_mat = reshape(err_cells{i}, n_slots_day, n_test_days);
   vals = arrayfun(@(h) rms(e_mat(h, :)), h_targets);
   fprintf('%-42s %8.1f %8.1f %8.1f %8.1f %8.1f\n', model_names{i}, vals);
end

%% ---------- 图1: 三种模型对比 (3×2) ----------
figure('Name', '图1: 三种预测模型对比', 'Position', [40, 40, 1250, 950]);
tl1 = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

y_lim   = [min(y_test) - 0.1*range(y_test), max(y_test) + 0.1*range(y_test)];
err_lim = [min([err1;err2;err3]) - 0.1*range([err1;err2;err3]), ...
           max([err1;err2;err3]) + 0.1*range([err1;err2;err3])];
day_edges = t_test((1:n_test_days-1) * n_slots_day + 1);

plot_model_row(tl1, 1, t_test, y_test, pred1, '模型 1: 纯 AR(4) 递归预测', 'r', y_lim, err_lim, day_edges);
plot_model_row(tl1, 2, t_test, y_test, pred2, '模型 2: AR(4) + 全体日模板 (不分类)', 'b', y_lim, err_lim, day_edges);
plot_model_row(tl1, 3, t_test, y_test, pred3, '模型 3: AR(4) + 工作日/周末日模板', 'g', y_lim, err_lim, day_edges);

xlabel(tl1, '时间');
tl1.Title.String = '图1: 三种预测模型对比 (2026-02-01 ~ 02-07, 每天00:00生成未来24h预测)';

%% ---------- 图2: 模板窗口策略对比 (3×2) ----------
figure('Name', '图2: 模板窗口策略对比', 'Position', [60, 60, 1250, 950]);
tl2 = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

err_lim2 = [min([errA;errB;errC]) - 0.1*range([errA;errB;errC]), ...
            max([errA;errB;errC]) + 0.1*range([errA;errB;errC])];

plot_model_row(tl2, 1, t_test, y_test, predA, ...
   'AR(4) + 区分模板 (类内7天窗口: 工作日7个/周末7个)', 'r', y_lim, err_lim2, day_edges);
plot_model_row(tl2, 2, t_test, y_test, predB, ...
   'AR(4) + 区分模板 (类内28天窗口)', 'b', y_lim, err_lim2, day_edges);
plot_model_row(tl2, 3, t_test, y_test, predC, ...
   sprintf('AR(4) + 区分模板 (截断EWMA: α=%.2f, ε=%.2f, K=%d)', ewma_alpha, ewma_min_weight, ewma_K), ...
   'g', y_lim, err_lim2, day_edges);

xlabel(tl2, '时间');
tl2.Title.String = '图2: 模板窗口策略对比 (均使用 AR(4)+工作日/周末模板, 类别内窗口)';

%% ============================================================
%  局部函数: 绘制一行 (左: 真实vs预测, 右: 误差)
% ============================================================
function plot_model_row(tl, row, t_test, y_test, y_pred, model_name, col, y_lim, err_lim, day_edges)
   % 左列: 真实 vs 预测
   % tiledlayout 默认 TileIndexing='columnmajor':
   %   线性索引 1,2,3 → 第1列(左), 4,5,6 → 第2列(右)
   nexttile(tl, (row-1)*2 + 1);
   plot(t_test, y_test, 'k-', 'LineWidth', 1, 'DisplayName', '真实电价');
   hold on;
   rmse_val = sqrt(mean((y_test - y_pred).^2));
   plot(t_test, y_pred, 'Color', col, 'LineWidth', 1, ...
      'DisplayName', sprintf('预测 (RMSE=%.1f)', rmse_val));
   ylabel('电价 ($/MWh)');
   ylim(y_lim);
   title(model_name);
   legend('Location', 'best');
   grid on;

   % 右列: 误差 (真实 - 预测)
   nexttile(tl, (row-1)*2 + 2);
   err = y_test - y_pred;
   plot(t_test, err, 'Color', col, 'LineWidth', 1, ...
      'DisplayName', '误差 (真实-预测)');
   hold on;
   yline(0, 'k-', 'HandleVisibility', 'off');
   % 竖虚线标记每天 00:00 边界 → 可见每块预测内误差随 horizon 增长
   for k = 1:length(day_edges)
      xline(day_edges(k), 'k--', 'HandleVisibility', 'off');
   end
   ylabel('误差 ($/MWh)');
   ylim(err_lim);
   title([model_name, ' : 预测误差']);
   legend('Location', 'best');
   grid on;
end