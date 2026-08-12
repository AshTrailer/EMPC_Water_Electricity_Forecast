%% ============================================================
%  DEMO_MAIN  水箱系统 + 电价滤波 演示脚本
%  版本: v3 - 修复开环策略 + 水位闭环反馈 + 滤波分析
% ============================================================

clear; close all; clc;

% ---- 加载配置 ----
cfg = system_config();

% ---- 1. 加载AEMO数据 ----
fprintf("\n========== 1. 加载AEMO数据 ==========\n");
try
   aemo_data = load_aemo_data(cfg.data.folder);
catch ME
   warning("AEMO数据加载失败: %s", ME.message);
   fprintf("将使用合成电价数据进行演示。\n");
   aemo_data = generate_synthetic_data(cfg);
end

% ---- 2. 电价滤波对比 ----
fprintf("\n========== 2. 电价滤波对比 ==========\n");

n_demo = min(7 * 24 * 12, length(aemo_data.price));
price_raw = aemo_data.price(1:n_demo);
time_demo = aemo_data.time(1:n_demo);

ma_buf   = struct();
med_buf  = struct();
rls_state = struct();

price_ma  = zeros(n_demo, 1);
price_med = zeros(n_demo, 1);
price_rls = zeros(n_demo, 1);

rls_params.lambda = cfg.filter.rls_lambda;
rls_params.delta  = cfg.filter.rls_delta;
rls_params.p      = cfg.filter.rls_order;

for i = 1:n_demo
   [price_ma(i),  ma_buf]   = apply_moving_average(price_raw(i), ma_buf,   cfg.filter.ma_window);
   [price_med(i), med_buf]  = apply_median_filter(price_raw(i),  med_buf,  cfg.filter.med_window);
   [price_rls(i), rls_state] = apply_rls_filter(price_raw(i), rls_state, rls_params);
end

% 画图：三种滤波器对比
figure('Name', '电价滤波对比', 'Position', [100, 100, 1200, 800]);

subplot(3,1,1);
plot(time_demo, price_raw, 'Color', [0.7, 0.7, 0.7], 'DisplayName', '原始数据');
hold on;
plot(time_demo, price_ma,  'b-', 'LineWidth', 1.5, 'DisplayName', ...
   sprintf('移动平均 (窗=%d)', cfg.filter.ma_window));
plot(time_demo, price_med, 'r-', 'LineWidth', 1.5, 'DisplayName', ...
   sprintf('移动中值 (窗=%d)', cfg.filter.med_window));
plot(time_demo, price_rls, 'g-', 'LineWidth', 1.5, 'DisplayName', ...
   sprintf('RLS (λ=%.2f, p=%d)', rls_params.lambda, rls_params.p));
xlabel('时间');
ylabel('电价 ($/MWh)');
title('电价数据滤波对比 (一周)');
legend('Location', 'best');
grid on;

% 残差分析
subplot(3,1,2);
plot(time_demo, price_raw - price_ma,  'b-', 'DisplayName', 'MA残差');
hold on;
plot(time_demo, price_raw - price_med, 'r-', 'DisplayName', '中值残差');
plot(time_demo, price_raw - price_rls, 'g-', 'DisplayName', 'RLS残差');
xlabel('时间');
ylabel('残差 ($/MWh)');
title('滤波器残差 (原始-滤波)');
legend('Location', 'best');
grid on;

% 局部放大：观察RLS滞后效应（取第2-3天）
subplot(3,1,3);
zoom_start = 24 * 12 + 1;  % 从第二天开始
zoom_end   = min(3 * 24 * 12, n_demo);
plot(time_demo(zoom_start:zoom_end), price_raw(zoom_start:zoom_end), ...
   'Color', [0.7, 0.7, 0.7], 'LineWidth', 1.0, 'DisplayName', '原始');
hold on;
plot(time_demo(zoom_start:zoom_end), price_ma(zoom_start:zoom_end), ...
   'b-', 'LineWidth', 1.5, 'DisplayName', 'MA');
plot(time_demo(zoom_start:zoom_end), price_rls(zoom_start:zoom_end), ...
   'g-', 'LineWidth', 1.5, 'DisplayName', 'RLS');
xlabel('时间');
ylabel('电价 ($/MWh)');
title('局部放大 (第2-3天) — 观察RLS滞后');
legend('Location', 'best');
grid on;

fprintf("滤波演示完成。RMSE:\n");
fprintf("  移动平均: %.3f $/MWh\n", rms(price_raw - price_ma));
fprintf("  移动中值: %.3f $/MWh\n", rms(price_raw - price_med));
fprintf("  RLS:      %.3f $/MWh\n", rms(price_raw - price_rls));

% ---- 3. 水箱 + 泵站仿真 (带水位反馈的合理策略) ----
fprintf("\n========== 3. 水箱闭环仿真 (水位反馈) ==========\n");

% 初始化系统
tank = WaterTankSystem(cfg);
pumps = [PumpStation(cfg.pump(1)); PumpStation(cfg.pump(2))];

% 仿真参数
dt_sim = cfg.sim.dt_control;  % 秒
n_steps = 288;                % 24小时 (每步5分钟)
t_hours = (0:n_steps-1)' * dt_sim / 3600;

% 生成需求模式
demand_multiplier = 0.8 + 0.6 * sin(pi * (t_hours - 6) / 12);
demand_multiplier = max(demand_multiplier, 0.3);
base_demand = 0.030;  % 30 L/s
demand_flow = base_demand * demand_multiplier;

% ---- 水位反馈控制策略 ----
% 目标水位: 2.5 m (区间中点，给上下留缓冲)
% 策略:
%   水位 < 2.0  → 全开 (PS1:2台, PS2:1台)
%   水位 2.0~2.8 → 中等 (PS1:1台, PS2:0台)
%   水位 > 3.0  → 关闭所有泵
%   中间线性插值避免震荡
target_x = 2.5;
x_low    = 2.0;
x_high   = 3.0;

% 预分配
x_history = zeros(n_steps + 1, 1);
q_in_history  = zeros(n_steps, 1);
q_out_history = zeros(n_steps, 1);
power_history = zeros(n_steps, 1);
n1_history = zeros(n_steps, 1);
n2_history = zeros(n_steps, 1);

x_history(1) = tank.x;

for k = 1:n_steps
   current_x = tank.x;

   % 简单比例反馈：水位越低，泵越多
   if current_x < x_low
      % 水位过低：全开
      n1_continuous = 2.0;
      n2_continuous = 1.0;
   elseif current_x > x_high
      % 水位过高：全关
      n1_continuous = 0.0;
      n2_continuous = 0.0;
   else
      % 中间区域：线性缩放
      frac = (current_x - x_low) / (x_high - x_low);  % 0~1, 0=低水位, 1=高水位
      target_inflow = demand_flow(k);  % 理想入流 = 出流（维持水位）
      % 水位低时多泵（frac小），水位高时少泵（frac大）
      scale = max(0, 1 - frac);  % 水位越低scale越大
      n1_continuous = scale * 2.0;
      n2_continuous = scale * 1.0;
   end

   % 量化到整数台数
   n1 = round(n1_continuous);
   n2 = round(n2_continuous);
   n1 = max(0, min(2, n1));
   n2 = max(0, min(1, n2));

   % 获取泵输出
   [q1, pwr1] = pumps(1).get_output(n1);
   [q2, pwr2] = pumps(2).get_output(n2);
   q_in = q1 + q2;
   total_power = pwr1 + pwr2;

   % 水箱步进
   [q_out_actual, x_new] = tank.step(q_in, demand_flow(k));

   % 记录
   n1_history(k) = n1;
   n2_history(k) = n2;
   q_in_history(k)  = q_in;
   q_out_history(k) = q_out_actual;
   power_history(k) = total_power;
   x_history(k+1)   = x_new;
end

% 画图：水箱仿真结果
figure('Name', '水箱闭环仿真 (水位反馈)', 'Position', [100, 100, 1200, 800]);

% 水位
subplot(3,1,1);
plot(t_hours, x_history(1:end-1), 'b-', 'LineWidth', 1.5);
hold on;
yline(tank.x_min, 'r--', '下界 (1.4m)');
yline(tank.x_max, 'r--', '上界 (3.37m)');
yline(target_x, 'g--', '目标水位 (2.5m)');
xlabel('时间 (小时)');
ylabel('水位 (m)');
title('水箱水位变化 (带水位反馈)');
legend('水位', '下界', '上界', '目标', 'Location', 'best');
grid on;

% 流量
subplot(3,1,2);
plot(t_hours, q_in_history * 1000, 'b-', 'DisplayName', '入流 (泵送)');
hold on;
plot(t_hours, q_out_history * 1000, 'r-', 'DisplayName', '出流 (需求)');
xlabel('时间 (小时)');
ylabel('流量 (L/s)');
title('入流与出流');
legend('Location', 'best');
grid on;

% 控制策略
subplot(3,1,3);
stairs(t_hours, n1_history, 'b-', 'LineWidth', 1.5, 'DisplayName', 'PS1 泵台数');
hold on;
stairs(t_hours, n2_history, 'r-', 'LineWidth', 1.5, 'DisplayName', 'PS2 泵台数');
xlabel('时间 (小时)');
ylabel('运行台数');
title('泵控制策略 (水位反馈)');
ylim([-0.2, 2.5]);
legend('Location', 'best');
grid on;

fprintf("仿真完成: %d 步, 最终水位 %.3f m\n", n_steps, tank.x);
fprintf("  总能耗: %.1f kWh\n", sum(power_history) * dt_sim / 3600);
fprintf("  水位范围: [%.3f, %.3f] m\n", min(x_history), max(x_history));

%% ============================================================
%  辅助函数: 合成电价数据 (当AEMO数据不可用时)
% ============================================================
function data = generate_synthetic_data(cfg)
   n_pts = 7 * 24 * 12;
   t0 = datetime(2026, 1, 1, 0, 0, 0);
   data.time = (t0 + minutes(5) * (0:n_pts-1)')';

   t_hours = (0:n_pts-1) * 5 / 60;
   daily_pattern = 30 + 20 * sin(pi * (mod(t_hours, 24) - 8) / 12);
   noise = 5 * randn(n_pts, 1);
   data.price = max(daily_pattern' + noise, 5);

   data.demand = 4000 + 1000 * sin(pi * (mod(t_hours, 24) - 6) / 12)' + 200 * randn(n_pts, 1);
   data.region = "SYNTHETIC";
   data.num_months = 0;
   data.file_list = {};
end