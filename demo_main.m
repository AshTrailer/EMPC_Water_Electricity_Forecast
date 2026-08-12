%% ============================================================
%  DEMO_MAIN  水箱系统 + 电价滤波 演示脚本
%
%  本脚本演示:
%    1. 批量加载AEMO电价数据
%    2. 对电价应用三种滤波方法并对比
%    3. 初始化水箱系统和泵站
%    4. 运行开环仿真 (固定泵控制策略)
%    5. 可视化结果
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
% 取前一周数据做滤波演示
n_demo = min(7 * 24 * 12, length(aemo_data.price));
price_raw = aemo_data.price(1:n_demo);
time_demo = aemo_data.time(1:n_demo);
% 初始化滤波器状态 (使用 struct() 而非 [])
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
figure('Name', '电价滤波对比', 'Position', [100, 100, 1200, 600]);

subplot(2,1,1);
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
title('电价数据滤波对比');
legend('Location', 'best');
grid on;

% 残差分析
subplot(2,1,2);
plot(time_demo, price_raw - price_ma,  'b-', 'DisplayName', 'MA残差');
hold on;
plot(time_demo, price_raw - price_med, 'r-', 'DisplayName', '中值残差');
plot(time_demo, price_raw - price_rls, 'g-', 'DisplayName', 'RLS残差');
xlabel('时间');
ylabel('残差 ($/MWh)');
title('滤波器残差 (原始-滤波)');
legend('Location', 'best');
grid on;

fprintf("滤波演示完成。RMSE:\n");
fprintf("  移动平均: %.3f $/MWh\n", rms(price_raw - price_ma));
fprintf("  移动中值: %.3f $/MWh\n", rms(price_raw - price_med));
fprintf("  RLS:      %.3f $/MWh\n", rms(price_raw - price_rls));

% ---- 3. 水箱 + 泵站开环仿真 ----
fprintf("\n========== 3. 水箱开环仿真 ==========\n");

% 初始化系统
tank = WaterTankSystem(cfg);
pumps = [PumpStation(cfg.pump(1)); PumpStation(cfg.pump(2))];

% 仿真参数
dt_sim = cfg.sim.dt_control;  % 秒
n_steps = 24 * 3600 / dt_sim; % 24小时 (每步5分钟 → 288步)
n_steps = round(n_steps);

% 生成需求模式 (类似论文 Fig.2 的需求乘子)
t_hours = (0:n_steps-1)' * dt_sim / 3600;
demand_multiplier = 0.8 + 0.6 * sin(pi * (t_hours - 6) / 12);  % 简化的日周期
demand_multiplier = max(demand_multiplier, 0.3);                  % 最低0.3
base_demand = 0.030;  % 基准需求 30 L/s = 0.030 m³/s (类似论文 ¯d10=25 L/s)
demand_flow = base_demand * demand_multiplier;

% 固定泵控制策略 (用于演示)
% 策略: 非峰时段用2台泵 (PS1:2台, PS2:1台), 峰时段用1台 (PS1:1台, PS2:0台)
% 峰时段简单定义为 8:00-20:00
peak_hours_mask = (mod(t_hours, 24) >= 8) & (mod(t_hours, 24) < 20);
control_strategy = zeros(n_steps, 2);  % [n1, n2]
control_strategy(~peak_hours_mask, :) = repmat([2, 1], sum(~peak_hours_mask), 1);
control_strategy(peak_hours_mask, :)  = repmat([1, 0], sum(peak_hours_mask), 1);

% 预分配存储
x_history = zeros(n_steps + 1, 1);
q_in_history  = zeros(n_steps, 1);
q_out_history = zeros(n_steps, 1);
power_history = zeros(n_steps, 1);

x_history(1) = tank.x;

% 仿真循环
for k = 1:n_steps
   n1 = control_strategy(k, 1);
   n2 = control_strategy(k, 2);

   % 获取泵输出
   [q1, pwr1] = pumps(1).get_output(n1);
   [q2, pwr2] = pumps(2).get_output(n2);
   q_in = q1 + q2;
   total_power = pwr1 + pwr2;

   % 水箱步进 (含扰动)
   [q_out_actual, x_new] = tank.step(q_in, demand_flow(k));

   % 记录
   q_in_history(k)  = q_in;
   q_out_history(k) = q_out_actual;
   power_history(k) = total_power;
   x_history(k+1)   = x_new;
end

% 画图：水箱仿真结果
figure('Name', '水箱开环仿真', 'Position', [100, 100, 1200, 800]);

% 水位
subplot(3,1,1);
plot(t_hours, x_history(1:end-1), 'b-', 'LineWidth', 1.5);
hold on;
yline(tank.x_min, 'r--', '下界');
yline(tank.x_max, 'r--', '上界');
xlabel('时间 (小时)');
ylabel('水位 (m)');
title('水箱水位变化');
legend('水位', '下界', '上界', 'Location', 'best');
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
stairs(t_hours, control_strategy(:,1), 'b-', 'LineWidth', 1.5, 'DisplayName', 'PS1 泵台数');
hold on;
stairs(t_hours, control_strategy(:,2), 'r-', 'LineWidth', 1.5, 'DisplayName', 'PS2 泵台数');
xlabel('时间 (小时)');
ylabel('运行台数');
title('泵控制策略');
ylim([-0.2, 2.5]);
legend('Location', 'best');
grid on;

fprintf("仿真完成: %d 步, 最终水位 %.3f m\n", n_steps, tank.x);
fprintf("  总能耗: %.1f kWh\n", sum(power_history) * dt_sim / 3600);

%% ============================================================
%  辅助函数: 合成电价数据 (当AEMO数据不可用时)
% ============================================================
function data = generate_synthetic_data(cfg)
   % 生成一周的合成数据用于演示
   n_pts = 7 * 24 * 12;  % 一周, 5分钟间隔
   t0 = datetime(2026, 1, 1, 0, 0, 0);
   data.time = (t0 + minutes(5) * (0:n_pts-1)')';

   % 合成电价: 日周期 + 随机噪声
   t_hours = (0:n_pts-1) * 5 / 60;
   daily_pattern = 30 + 20 * sin(pi * (mod(t_hours, 24) - 8) / 12);
   noise = 5 * randn(n_pts, 1);
   data.price = max(daily_pattern' + noise, 5);  % 最低5 $/MWh

   % 合成需求: 日周期
   data.demand = 4000 + 1000 * sin(pi * (mod(t_hours, 24) - 6) / 12)' + 200 * randn(n_pts, 1);
   data.region = "SYNTHETIC";
   data.num_months = 0;
   data.file_list = {};
end