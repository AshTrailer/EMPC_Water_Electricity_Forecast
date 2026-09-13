%% RUN_TWO_DAY_COMPARISON Compare two independent rolling-MPC runs.
% Each column performs 288 closed-loop optimizations. Each optimization
% receives 288 consecutive future samples and implements only its first
% action. This script contains no one-shot daily-schedule shortcut.
clear; close all; clc;

basic_root = fileparts(mfilename('fullpath'));
addpath(basic_root);
addpath(fullfile(basic_root, 'controller'));
addpath(fullfile(basic_root, 'interfaces'));
addpath(fullfile(basic_root, 'scenarios'));
addpath(fullfile(basic_root, 'simulation'));

config = basic_mpc_config();
comparison_dates = [datetime(2026,2,1); datetime(2026,2,4)];
day_result = cell(numel(comparison_dates), 1);
for column = 1:numel(comparison_dates)
    day_result{column} = simulate_basic_mpc(config, 'historical', ...
        config.default_simulation_steps, false, comparison_dates(column));
end

figure_handle = figure('Name', 'Basic 1.2 rolling-MPC comparison', ...
    'Color', 'white', 'Position', [40 20 1800 1350]);
layout = tiledlayout(5, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, ['Basic 1.2: two independent 24-hour closed-loop runs ', ...
    '(288 optimizations per column)'], 'FontWeight', 'bold');

price_axes = gobjects(2,1);
demand_axes = gobjects(2,1);
pump_axes = gobjects(2,1);
level_axes = gobjects(2,1);
cost_axes = gobjects(2,1);

for column = 1:2
    result = day_result{column};
    date_label = string(comparison_dates(column), 'yyyy-MM-dd');

    price_axes(column) = nexttile(layout, column);
    plot(result.time, result.price_aud_per_mwh, 'k-', ...
        'LineWidth', 1.0);
    hold on;
    yline(0, 'Color', [0.45 0.45 0.45], 'LineStyle', ':');
    ylabel('RRP (AUD/MWh)');
    title(sprintf('%s | %d negative-price intervals', ...
        date_label, nnz(result.price_aud_per_mwh < 0)));
    grid on;

    demand_axes(column) = nexttile(layout, 2+column);
    stairs(result.time, 1000*result.demand, ...
        'Color', [0.10 0.55 0.25], 'LineWidth', 1.2);
    ylabel('Demand (L/s)');
    title('Richmond demand (first multiplier = 00:00-01:00)');
    grid on;

    pump_axes(column) = nexttile(layout, 4+column);
    stairs(result.time, result.u_actual, 'b-', 'LineWidth', 1.3);
    hold on;
    stairs(result.time, result.baseline.u, ...
        'Color', [0.72 0.72 0.72], 'LineWidth', 0.7);
    ylabel('Pump on/off');
    ylim([-0.08 1.08]);
    yticks([0 1]);
    title(sprintf('Rolling MPC switches: %d', result.switch_count));
    legend('Rolling MPC', 'Price-blind reference', ...
        'Location', 'best', 'FontSize', 8);
    grid on;

    level_axes(column) = nexttile(layout, 6+column);
    plot(result.level_time, result.level, 'b-', 'LineWidth', 1.4);
    hold on;
    yline(config.level_min_m, 'r--', 'LineWidth', 1.0);
    yline(config.level_max_m, 'r--', 'LineWidth', 1.0);
    ylabel('Tank level (m)');
    ylim([1.30 3.50]);
    title(sprintf('Range: %.4f-%.4f m | violations: %d', ...
        min(result.level), max(result.level), ...
        result.constraint_violations));
    legend('Actual level', 'Hard bounds', '', ...
        'Location', 'best', 'FontSize', 8);
    grid on;

    cost_axes(column) = nexttile(layout, 8+column);
    plot(result.time, result.cumulative_total_cost_aud, ...
        'b-', 'LineWidth', 1.3);
    hold on;
    plot(result.time, result.baseline.cumulative_total_cost_aud, ...
        'Color', [0.35 0.35 0.35], 'LineWidth', 1.0);
    ylabel('Cumulative cost (AUD)');
    xlabel('AEMO interval-ending time');
    title(sprintf('Rolling MPC: %.2f AUD | reference: %.2f AUD', ...
        result.total_cost_aud, result.baseline.total_cost_aud));
    legend('Rolling MPC', 'Price-blind reference', ...
        'Location', 'best', 'FontSize', 8);
    grid on;

    all_axes = [price_axes(column), demand_axes(column), ...
        pump_axes(column), level_axes(column), cost_axes(column)];
    for axis_index = 1:numel(all_axes)
        xlim(all_axes(axis_index), ...
            [result.level_time(1), result.level_time(end)]);
    end
end

linkaxes(price_axes, 'y');
linkaxes(demand_axes, 'y');
linkaxes(level_axes, 'y');
linkaxes(cost_axes, 'y');

output_file = fullfile(basic_root, ...
    'Basic_1_2_two_day_rolling_comparison.png');
exportgraphics(figure_handle, output_file, 'Resolution', 200);

for column = 1:2
    result = day_result{column};
    fprintf(['%s: optimizations=%d, horizon=%d, inputs=%d, ', ...
        'last window=%d:%d, switches=%d, level=%.4f-%.4f m, ', ...
        'violations=%d, cost=%.4f AUD.\n'], ...
        string(comparison_dates(column), 'yyyy-MM-dd'), ...
        result.optimization_count, result.config.horizon_steps, ...
        result.input_count, ...
        result.optimization.window_start_index(end), ...
        result.optimization.window_end_index(end), ...
        result.switch_count, min(result.level), max(result.level), ...
        result.constraint_violations, result.total_cost_aud);
end
fprintf('Saved rolling comparison figure: %s\n', output_file);
