%% ============================================================
%  RUN_KALMAN_PREDICTION  方案A: 谐波状态空间卡尔曼滤波预测
%
%  模型:
%     y(t) = μ(t) + Σ_{k=1}^{3} [a_k(t) sin θ_k(t) + b_k(t) cos θ_k(t)] + r(t)
%     状态: x = [μ, a1, b1, a2, b2, a3, b3, r_t, r_{t-1}, r_{t-2}, r_{t-3}]'
%
%  预测协议 (与方案 B 完全一致):
%     - 1 月数据训练: OLS 谐波拟合 + 残差 AR(4) 拟合 + Q 估计 + 滤波预热
%     - 每天 00:00 用当前滤波状态做未来 288 步预测
%     - 当天数据逐点到达, 卡尔曼滤波在线更新状态与协方差
%
%  与方案 B 的本质区别:
%     方案 B: 离散模板 + RLS (系数在线估计, 无协方差)
%     方案 A: 连续谐波基 + 卡尔曼滤波 (状态与协方差联合递推),
%             P(t+h|t) 闭式递推给出理论预测误差带
%             → 教授要的 "mathematics solution for theory prediction error"
%
%  图1: 预测结果 (95% 理论带 / 周期分量 / 误差与理论误差曲线)
%  图2: 状态分解 (趋势自适应 / 谐波系数漂移 / 残差与新息)
%
%  训练期: 2026-01 (31 天)   测试期: 2026-02-01 ~ 02-07 (7 天)
% ============================================================

clear; close all; clc;

% ---- 路径设置 ----
project_root = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project";
addpath(fullfile(project_root, "predictor"));        % get_slot_index
addpath(fullfile(project_root, "kalman_predictor")); % 方案A 各函数

% ---- 数据加载 ----
cfg = system_config();
aemo_data = load_aemo_data(fullfile(project_root, "data"));
t_all = aemo_data.time;
y_all = aemo_data.price;

n_slots_day = 288;
n_test_days = 7;

% ---- 训练/测试期划分 (与方案 B 一致) ----
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
assert(n_train == 31*n_slots_day && n_test == 7*n_slots_day, '训练/测试期点数不符');

% ---- 模型训练 (仅 1 月) ----
n_harm = 3;
ar_order = 4;
model = build_harmonic_ss_model(y_train, t_train, n_harm, ar_order);

fprintf("\n========== 方案A: 谐波状态空间卡尔曼滤波 ==========\n");
fprintf("训练期: %s ~ %s (%d 点)\n", char(train_start), char(train_end), n_train);
fprintf("测试期: %s ~ %s (%d 点)\n", char(test_start), char(test_end), n_test);
fprintf("1月谐波 OLS 拟合 R²: %.3f\n", model.r2_train);
fprintf("OLS 系数: μ=%.1f, a=[%s], b=[%s]\n", model.coef0(1), ...
   sprintf('%.1f ', model.coef0(2:2:end)), sprintf('%.1f ', model.coef0(3:2:end)));
fprintf("残差 AR(%d) 系数: [%s], σ_ε=%.1f $/MWh\n", ar_order, ...
   sprintf('%.3f ', model.phi), model.sigma_eps);
A288 = model.A(2:2*n_harm+1, 2:2*n_harm+1)^n_slots_day;
fprintf("A^288 谐波块与单位阵偏差: %.2e (288步=旋转一圈, 解析性质验证)\n", ...
   norm(A288 - eye(2*n_harm)));

x = model.x0;
P = model.P0;

%% ---------- 测试期主循环 ----------
pred_mean_all = zeros(n_test, 1);
pred_sd_all   = zeros(n_test, 1);
pred_harm_all = zeros(n_test, 1);
x_mu_all    = zeros(n_test, 1);   % 趋势状态
x_harm_all  = zeros(n_test, 1);   % 谐波分量
x_resid_all = zeros(n_test, 1);   % 残差状态 r(t)
x_a1_all    = zeros(n_test, 1);   % 基波系数 a1
x_b1_all    = zeros(n_test, 1);   % 基波系数 b1
innov_all   = zeros(n_test, 1);   % 新息

i_ar = 1 + 2*n_harm + 1;

for d = 1:n_test_days
   idx = (d-1)*n_slots_day + (1:n_slots_day);

   % ---- 每天 00:00: 288 步预测 (A^h 解析递推 + P 闭式递推) ----
   [pred_mean, pred_sd, pred_harm] = kalman_predict_288(x, P, n_slots_day, model);
   pred_mean_all(idx) = pred_mean;
   pred_sd_all(idx)   = pred_sd;
   pred_harm_all(idx) = pred_harm;

   % ---- 当天数据逐点到达: 卡尔曼滤波在线更新 ----
   for s = 1:n_slots_day
      slot = get_slot_index(t_test(idx(s)));
      [x, P, innov] = kalman_filter_step(x, P, y_test(idx(s)), slot, model);

      innov_all(idx(s)) = innov;
      x_mu_all(idx(s)) = x(1);
      C_harm = make_harmonic_C(model, slot);
      C_harm(i_ar) = 0;
      x_harm_all(idx(s)) = C_harm * x - x(1);
      x_resid_all(idx(s)) = x(i_ar);
      x_a1_all(idx(s)) = x(2);
      x_b1_all(idx(s)) = x(3);
   end
end

fprintf("测试期预测完成 (%d 天 × 288 步)。\n", n_test_days);

%% ---------- 指标汇总 ----------
err = y_test - pred_mean_all;
rmse_all = rms(err);
mae_all = mean(abs(err));
z = abs(err) ./ pred_sd_all;
coverage_all = mean(z <= 1.96);

fprintf("\n========== 测试期整体指标 (2026-02-01 ~ 02-07) ==========\n");
fprintf('%-42s %10s %10s\n', '模型', 'RMSE', 'MAE');
fprintf('%-42s %10.1f %10.1f\n', '方案A: 谐波状态空间卡尔曼 (3谐波+AR4)', rmse_all, mae_all);
fprintf('信号标准差: %.1f $/MWh\n', std(y_test));
fprintf('95%% 理论预测带覆盖率: %.1f%% (目标 95%%, 偏差→Q/R 标定)\n', coverage_all*100);

fprintf("\n按预测时域的 RMSE ($/MWh) 与 95%% 带覆盖率:\n");
h_targets = [12, 36, 72, 144, 288];
fprintf('%-10s %8s %8s %8s %8s %8s\n', 'horizon', '1h', '3h', '6h', '12h', '24h');
e_mat = reshape(err, n_slots_day, n_test_days);
z_mat = reshape(z <= 1.96, n_slots_day, n_test_days);
fprintf('%-10s', 'RMSE');
for i = 1:5
   fprintf(' %8.1f', rms(e_mat(h_targets(i), :)));
end
fprintf('\n%-10s', '覆盖');
for i = 1:5
   fprintf(' %7.1f%%', 100*mean(z_mat(h_targets(i), :)));
end
fprintf('\n');

%% ---------- 图1: 预测结果 ----------
figure('Name', '方案A 图1: 谐波状态空间卡尔曼预测', 'Position', [40, 40, 1250, 950]);
tl1 = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

y_lim = [min(y_test) - 0.1*range(y_test), max(y_test) + 0.1*range(y_test)];
err_lim = [min(err) - 0.1*range(err), max(err) + 0.1*range(err)];
day_edges = t_test((1:n_test_days-1)*n_slots_day + 1);
band_lo = pred_mean_all - 1.96*pred_sd_all;
band_hi = pred_mean_all + 1.96*pred_sd_all;

% 行1 左: 预测 vs 真实 (95% 理论带)
nexttile(tl1, 1);
fill([t_test; flipud(t_test)], [band_lo; flipud(band_hi)], ...
   [0.6 0.6 0.6], 'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
   'DisplayName', '95% 理论预测带 (P 递推)');
hold on;
plot(t_test, y_test, 'k-', 'LineWidth', 1, 'DisplayName', '真实电价');
plot(t_test, pred_mean_all, 'r-', 'LineWidth', 1, ...
   'DisplayName', sprintf('预测 (RMSE=%.1f)', rmse_all));
ylabel('电价 ($/MWh)');  ylim(y_lim);
title('谐波状态空间卡尔曼: 预测 vs 真实 (含理论误差带)');
legend('Location', 'best');  grid on;

% 行1 右: 误差 vs 理论带
nexttile(tl1, 4);
fill([t_test; flipud(t_test)], [-1.96*pred_sd_all; flipud(1.96*pred_sd_all)], ...
   [0.6 0.6 0.6], 'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
   'DisplayName', '±1.96σ 理论带');
hold on;
plot(t_test, err, 'r-', 'LineWidth', 1, 'DisplayName', '预测误差');
yline(0, 'k-', 'HandleVisibility', 'off');
for k = 1:length(day_edges)
   xline(day_edges(k), 'k--', 'HandleVisibility', 'off');
end
ylabel('误差 ($/MWh)');  ylim(err_lim);
title(sprintf('预测误差与理论带 (覆盖率 %.1f%%)', coverage_all*100));
legend('Location', 'best');  grid on;

% 行2 左: 周期分量预测 (μ+谐波, 无AR)
nexttile(tl1, 2);
plot(t_test, y_test, 'k-', 'LineWidth', 1, 'DisplayName', '真实电价');
hold on;
plot(t_test, pred_harm_all, 'b-', 'LineWidth', 1, ...
   'DisplayName', '周期分量预测 (μ+谐波, 无AR)');
ylabel('电价 ($/MWh)');  ylim(y_lim);
title('周期结构本身捕捉了多少 (μ + 3谐波)');
legend('Location', 'best');  grid on;

% 行2 右: 周期模型误差 (需 AR 残差弥补的部分)
nexttile(tl1, 5);
err_harm = y_test - pred_harm_all;
plot(t_test, err_harm, 'b-', 'LineWidth', 1, ...
   'DisplayName', '周期模型误差 (需 AR 残差弥补)');
hold on;
yline(0, 'k-', 'HandleVisibility', 'off');
ylabel('误差 ($/MWh)');
title(sprintf('周期分量误差 (RMSE=%.1f)', rms(err_harm)));
legend('Location', 'best');  grid on;

% 行3 左: 理论预测误差 σ(h) 的形状 (P 闭式递推的直接输出)
nexttile(tl1, 3);
sd_mat = reshape(pred_sd_all, n_slots_day, n_test_days);
h_axis = (1:n_slots_day) / 12;   % 小时
plot(h_axis, sd_mat, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5, ...
   'HandleVisibility', 'off');
hold on;
plot(h_axis, mean(sd_mat, 2), 'r-', 'LineWidth', 2, 'DisplayName', '7天平均');
xlabel('预测时域 (h)');  ylabel('σ(h) ($/MWh)');
title('理论预测误差 σ(h): P(t+h|t) 闭式递推');
legend('Location', 'best');  grid on;

% 行3 右: 覆盖率随 horizon
nexttile(tl1, 6);
cov_h = mean(z_mat, 2) * 100;
plot(h_axis, cov_h, 'b-', 'LineWidth', 1.5, 'DisplayName', '实际覆盖率');
hold on;
yline(95, 'r--', '目标 95%', 'HandleVisibility', 'on');
xlabel('预测时域 (h)');  ylabel('覆盖率 (%)');
title('95% 带实际覆盖率 vs horizon');
ylim([0 100]);  grid on;

%% ---------- 图2: 状态分解 ----------
figure('Name', '方案A 图2: 状态分解', 'Position', [60, 60, 1250, 950]);
tl2 = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

daily_mean_t = t_test(144 + (0:n_test_days-1)*n_slots_day);
daily_mean = zeros(n_test_days, 1);
for d = 1:n_test_days
   idx = (d-1)*n_slots_day + (1:n_slots_day);
   daily_mean(d) = mean(y_test(idx));
end

% 行1 左: 趋势 μ̂(t) vs 每日实际均价
nexttile(tl2, 1);
plot(t_test, x_mu_all, 'r-', 'LineWidth', 1, 'DisplayName', '滤波趋势 μ̂(t)');
hold on;
plot(daily_mean_t, daily_mean, 'ko', 'MarkerSize', 7, 'LineWidth', 1.5, ...
   'DisplayName', '每日实际均价');
yline(model.coef0(1), 'b--', '1月OLS水平', 'HandleVisibility', 'on');
ylabel('电价 ($/MWh)');
title('趋势分量: μ̂(t) 在线自适应 (1月→2月水平漂移)');
legend('Location', 'best');  grid on;

% 行1 右: 趋势漂移量
nexttile(tl2, 4);
plot(t_test, x_mu_all - model.coef0(1), 'r-', 'LineWidth', 1);
hold on;
yline(0, 'k-');
ylabel('漂移量 ($/MWh)');
title('趋势漂移: μ̂(t) - μ̂_{1月OLS}');
grid on;

% 行2 左: 谐波分量 (日内周期形态)
nexttile(tl2, 2);
plot(t_test, x_harm_all, 'b-', 'LineWidth', 0.8);
ylabel('电价 ($/MWh)');
title('谐波分量 Σ a_k sin θ_k + b_k cos θ_k (日内周期形态)');
grid on;

% 行2 右: 基波系数在线漂移
nexttile(tl2, 5);
plot(t_test, x_a1_all, 'r-', 'LineWidth', 0.8, 'DisplayName', 'a_1(t)');
hold on;
plot(t_test, x_b1_all, 'b-', 'LineWidth', 0.8, 'DisplayName', 'b_1(t)');
yline(model.coef0(2), 'r--', 'a_1 OLS初值');
yline(model.coef0(3), 'b--', 'b_1 OLS初值');
ylabel('系数');
title('基波系数 a_1, b_1 在线漂移 (卡尔曼自适应)');
legend('Location', 'best');  grid on;

% 行3 左: 残差分量 (分解自洽性验证)
nexttile(tl2, 3);
actual_resid = y_test - x_mu_all - x_harm_all;
plot(t_test, actual_resid, 'k-', 'LineWidth', 0.6, 'DisplayName', '实际 y - μ̂ - 谐波');
hold on;
plot(t_test, x_resid_all, 'g-', 'LineWidth', 0.6, 'DisplayName', '滤波残差状态 r̂(t)');
ylabel('电价 ($/MWh)');
title('AR 残差分量: 状态 r̂(t) 与观测分解一致性');
legend('Location', 'best');  grid on;

% 行3 右: 新息序列 (白化检验)
nexttile(tl2, 6);
plot(t_test, innov_all, 'm-', 'LineWidth', 0.6);
hold on;
yline(0, 'k-');
ylabel('新息 ($/MWh)');
title(sprintf('新息序列 (应近似白噪声, σ=%.1f)', std(innov_all)));
grid on;