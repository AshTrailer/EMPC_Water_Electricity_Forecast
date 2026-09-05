function results = simulate_basic_mpc(config, scenario_mode, n_hours, make_plot)
%SIMULATE_BASIC_MPC 运行水箱 MPC 与 Decision 接口的滚动闭环仿真。

if nargin < 1 || isempty(config)
    config = basic_mpc_config();
end
if nargin < 2 || isempty(scenario_mode)
    scenario_mode = 'periodic';
end
if nargin < 3 || isempty(n_hours)
    n_hours = 72;
end
if nargin < 4 || isempty(make_plot)
    make_plot = true;
end

N = config.horizon_steps;
all_data = make_mock_decision_data(datetime(2026, 2, 1), ...
    n_hours + N - 1, scenario_mode);

level = zeros(n_hours + 1, 1);
u_request = zeros(n_hours, 1);
u_actual = zeros(n_hours, 1);
requested_flow_m3s = zeros(n_hours, 1);
actual_flow_m3s = zeros(n_hours, 1);
decision_tracking_error_m3s = zeros(n_hours, 1);
reference = all_data.level_ref(1:n_hours);
demand = all_data.demand(1:n_hours);
exitflag = zeros(n_hours, 1);
level(1) = config.level_initial_m;
u_actual_previous = 0;

for k = 1:n_hours
    index = k:k+N-1;
    window.demand = all_data.demand(index);
    window.level_ref = all_data.level_ref(index);
    window.time = all_data.time(index);
    window.price = all_data.price(index);
    window.source = all_data.source;

    solution = constrained_tank_mpc(level(k), window, ...
        config, u_actual_previous);

    % MPC 先给出连续期望流量，再交给 Decision 决定实际执行结果
    request = mpc_to_decision_request(solution, all_data.time(k));
    decision_result = mock_decision_optimizer(request, config);

    u_request(k) = solution.u_request;
    requested_flow_m3s(k) = solution.requested_flow_m3s;
    u_actual(k) = decision_result.u_actual;
    actual_flow_m3s(k) = decision_result.actual_flow_m3s;
    decision_tracking_error_m3s(k) = ...
        decision_result.tracking_error_m3s;
    exitflag(k) = solution.exitflag;

    % 水箱只能受到实际流量影响，不能直接使用 MPC 的要求值
    level(k+1) = level(k) ...
        + config.dt_seconds/config.tank_area_m2 ...
        * (actual_flow_m3s(k) - demand(k));
    u_actual_previous = u_actual(k);
end

results.time = all_data.time(1:n_hours);
results.level_time = [results.time; results.time(end) + hours(1)];
results.level = level;
results.u_request = u_request;
results.u_actual = u_actual;
results.requested_flow_m3s = requested_flow_m3s;
results.actual_flow_m3s = actual_flow_m3s;
results.decision_tracking_error_m3s = decision_tracking_error_m3s;
results.demand = demand;
results.level_ref = reference;
results.exitflag = exitflag;
results.scenario_mode = scenario_mode;
results.config = config;

% 兼容旧代码的字段；它现在表示实际归一化总流量
results.pump = u_actual;

if make_plot
    figure('Name', '基础约束水箱 MPC');
    tiledlayout(3, 1);

    nexttile;
    plot(results.level_time, level, 'b-', 'LineWidth', 1.4);
    hold on;
    plot(results.time, reference, 'k--', 'LineWidth', 1.0);
    yline(config.level_min_m, 'r--');
    yline(config.level_max_m, 'r--');
    ylabel('水位（m）');
    legend('实际水位', '参考水位', '约束边界', ...
        'Location', 'best');
    grid on;

    nexttile;
    stairs(results.time, u_request, 'b-', 'LineWidth', 1.4);
    hold on;
    stairs(results.time, u_actual, 'r--', 'LineWidth', 1.2);
    ylabel('归一化总流量');
    legend('MPC要求值', 'Decision实际值', 'Location', 'best');
    ylim([config.u_min-0.05, config.u_max+0.05]);
    grid on;

    nexttile;
    plot(results.time, demand, 'LineWidth', 1.4);
    ylabel('用水需求（m^3/s）');
    xlabel('时间');
    grid on;
end
end
