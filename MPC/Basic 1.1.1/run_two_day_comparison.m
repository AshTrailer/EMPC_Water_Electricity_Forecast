%% RUN_TWO_DAY_COMPARISON Compare two independent one-day EMPC schedules.
% Left: many negative-price intervals, so the optimum stores cheap water
% before the tank reaches its lower bound. Right: fewer negative-price
% intervals, so the lower level constraint becomes active.
clear; close all; clc;

basic_root = fileparts(mfilename('fullpath'));
addpath(basic_root);
addpath(fullfile(basic_root, 'controller'));
addpath(fullfile(basic_root, 'interfaces'));
addpath(fullfile(basic_root, 'scenarios'));

config = basic_mpc_config();
history = load_historical_price_data(config.historical_price_file, ...
    config.historical_region);

comparison_dates = [datetime(2026,2,1); datetime(2026,2,4)];
column_titles = ["2026-02-01: lower bound not reached"; ...
    "2026-02-04: lower bound reached"];
day_result = cell(numel(comparison_dates), 1);

for column = 1:numel(comparison_dates)
    % AEMO labels each five-minute interval by its ending timestamp.
    % Therefore one operating day is (00:00, next-day 00:00].
    day_index = history.time > comparison_dates(column) ... 
        & history.time <= comparison_dates(column)+days(1);
    if nnz(day_index) ~= config.horizon_steps
        error('run_two_day_comparison:IncompleteDay', ...
            '%s has %d samples; expected %d.', ...
            string(comparison_dates(column), 'yyyy-MM-dd'), ...
            nnz(day_index), config.horizon_steps);
    end
    day_result{column} = optimize_one_day(history.time(day_index), ...
        history.price(day_index), config, history.source);
end

figure_handle = figure('Name', 'Basic 1.1.1 two-day comparison', ...
    'Color', 'white', 'Position', [40 40 1800 1200]);
layout = tiledlayout(4, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, ['Basic 1.1.1 independent 24-hour optimization: ', ...
    'effect of negative-price availability'], 'FontWeight', 'bold');

price_axes = gobjects(2,1);
pump_axes = gobjects(2,1);
level_axes = gobjects(2,1);
cost_axes = gobjects(2,1);

for column = 1:2
    result = day_result{column};

    price_axes(column) = nexttile(layout, column);
    plot(result.time, result.price_aud_per_mwh, 'k-', ...
        'LineWidth', 1.0);
    hold on;
    yline(0, 'Color', [0.45 0.45 0.45], 'LineStyle', ':');
    ylabel('RRP (AUD/MWh)');
    title(sprintf('%s | negative: %d steps (%.2f h)', ...
        column_titles(column), result.negative_price_steps, ...
        result.negative_price_hours));
    grid on;

    pump_axes(column) = nexttile(layout, 2+column);
    stairs(result.time, result.u, 'b-', 'LineWidth', 1.3);
    hold on;
    stairs(result.time, result.baseline.u, ...
        'Color', [0.72 0.72 0.72], 'LineWidth', 0.7);
    ylabel('Pump on/off');
    ylim([-0.08 1.08]);
    yticks([0 1]);
    title(sprintf('Economic pump ON: %.2f h | switches: %d', ...
        result.on_hours, result.switch_count));
    legend('Economic MPC', 'Price-blind benchmark', ...
        'Location', 'best', 'FontSize', 8);
    grid on;

    level_axes(column) = nexttile(layout, 4+column);
    plot(result.level_time, result.level, 'b-', 'LineWidth', 1.4);
    hold on;
    yline(config.level_min_m, 'r--', 'LineWidth', 1.0);
    yline(config.level_max_m, 'r--', 'LineWidth', 1.0);
    plot(result.level_time(result.minimum_level_index), ...
        result.minimum_level_m, 'ro', 'MarkerFaceColor', 'r', ...
        'MarkerSize', 5);
    ylabel('Tank level (m)');
    ylim([1.30 3.50]);
    title(sprintf('Minimum level: %.4f m | final: %.4f m', ...
        result.minimum_level_m, result.final_level_m));
    legend('Actual level', 'Hard bounds', '', 'Minimum level', ...
        'Location', 'best', 'FontSize', 8);
    grid on;

    cost_axes(column) = nexttile(layout, 6+column);
    plot(result.time, result.cumulative_total_cost_aud, ...
        'b-', 'LineWidth', 1.3);
    hold on;
    plot(result.time, result.baseline.cumulative_total_cost_aud, ...
        'Color', [0.35 0.35 0.35], 'LineWidth', 1.0);
    yline(0, 'Color', [0.45 0.45 0.45], 'LineStyle', ':');
    ylabel('Cumulative cost (AUD)');
    xlabel('Time');
    title(sprintf('Total cost: %.2f AUD | benchmark: %.2f AUD', ...
        result.total_cost_aud, result.baseline.total_cost_aud));
    legend('Economic MPC', 'Price-blind benchmark', ...
        'Location', 'best', 'FontSize', 8);
    grid on;

    all_axes = [price_axes(column), pump_axes(column), ...
        level_axes(column), cost_axes(column)];
    for axis_index = 1:numel(all_axes)
        xlim(all_axes(axis_index), ...
            [result.level_time(1), result.level_time(end)]);
    end
end

linkaxes(price_axes, 'y');
linkaxes(level_axes, 'y');
linkaxes(cost_axes, 'y');

output_file = fullfile(basic_root, ...
    'Basic_1_1_1_two_day_comparison.png');
exportgraphics(figure_handle, output_file, 'Resolution', 200);

for column = 1:2
    result = day_result{column};
    fprintf(['%s: negative=%d steps (%.2f h), pump ON=%d steps ', ...
        '(%.2f h), switches=%d, min=%.4f m, final=%.4f m, ', ...
        'cost=%.4f AUD, benchmark=%.4f AUD.\n'], ...
        string(comparison_dates(column), 'yyyy-MM-dd'), ...
        result.negative_price_steps, result.negative_price_hours, ...
        result.on_steps, result.on_hours, result.switch_count, ...
        result.minimum_level_m, result.final_level_m, ...
        result.total_cost_aud, result.baseline.total_cost_aud);
end
fprintf('Saved comparison figure: %s\n', output_file);

function result = optimize_one_day(time, price, config, source)
%OPTIMIZE_ONE_DAY Solve one calendar day with no repeated-day assumption.
N = numel(price);
day_config = config;
day_config.horizon_steps = N;

window.time = time(:);
window.price = price(:);
window.demand = config.water_demand_m3s*ones(N,1);
window.source = source;
solution = constrained_tank_mpc(config.level_initial_m, window, ...
    day_config, 0);

u = solution.u_plan;
level = [config.level_initial_m; solution.x_prediction];
level_time = [time(1)-seconds(config.dt_seconds); time(:)];
switch_event = abs(u-[0; u(1:end-1)]);
energy_cost = price(:)/1000*config.pump_power_kw ...
    *(config.dt_seconds/3600).*u;

baseline_u = double(mod((1:N)',2) == 1);
baseline_level = zeros(N+1,1);
baseline_level(1) = config.level_initial_m;
for k = 1:N
    baseline_level(k+1) = baseline_level(k) ...
        + config.dt_seconds/config.tank_area_m2 ...
        *(config.pump_flow_m3s*baseline_u(k) ...
        - config.water_demand_m3s);
end
baseline_switch = abs(baseline_u-[0; baseline_u(1:end-1)]);
baseline_energy_cost = price(:)/1000*config.pump_power_kw ...
    *(config.dt_seconds/3600).*baseline_u;

[minimum_level_m, minimum_level_index] = min(level);
result.time = time(:);
result.price_aud_per_mwh = price(:);
result.level_time = level_time;
result.level = level;
result.u = u;
result.switch_event = switch_event;
result.cumulative_total_cost_aud = cumsum(energy_cost ...
    + config.switch_cost_aud*switch_event);
result.total_cost_aud = result.cumulative_total_cost_aud(end);
result.negative_price_steps = nnz(price < 0);
result.negative_price_hours = result.negative_price_steps ...
    * config.dt_seconds/3600;
result.on_steps = nnz(u);
result.on_hours = result.on_steps*config.dt_seconds/3600;
result.switch_count = sum(switch_event);
result.minimum_level_m = minimum_level_m;
result.minimum_level_index = minimum_level_index;
result.final_level_m = level(end);
result.baseline.u = baseline_u;
result.baseline.level = baseline_level;
result.baseline.cumulative_total_cost_aud = ...
    cumsum(baseline_energy_cost ...
    + config.switch_cost_aud*baseline_switch);
result.baseline.total_cost_aud = ...
    result.baseline.cumulative_total_cost_aud(end);
end
