function figure_handle = plot_basic_mpc_results(results, output_file)
%PLOT_BASIC_MPC_RESULTS Plot and optionally save the Basic 1.3 closed loop.
% Pump states are placed in separate vertical lanes because two pumps can
% have identical schedules; plotting all three directly at 0/1 would hide
% coincident traces. Flow and power use separate axes and line styles.

arguments
    results (1,1) struct
    output_file (1,:) char = ''
end

config = results.config;
pump_actual = results.pump_actual;
pump_styles = {'-', '--', ':'};
pump_colours = [0.0000 0.4470 0.7410; ...
                0.8500 0.3250 0.0980; ...
                0.9290 0.6940 0.1250];
lane_base = [2, 1, 0];
lane_height = 0.70;

figure_handle = figure('Name', 'Basic 1.3 Three-pump MILP', ...
    'Color', 'white', 'Position', [60 20 1500 1350]);
layout = tiledlayout(6,1,'TileSpacing','compact','Padding','compact');
title(layout, sprintf(['Basic 1.3 Multi-pump MILP: %d-step ', ...
    'closed-loop result'], results.optimization_count));

nexttile;
plot(results.time, results.price_aud_per_mwh, 'Color', [0.25 0.25 0.25], ...
    'LineWidth', 1.1);
ylabel('AUD/MWh');
title('Historical VIC1 price (perfect forecast input)');
grid on;

nexttile;
stairs(results.time, 1000*results.demand, '-', 'Color', [0.10 0.55 0.25], ...
    'LineWidth', 1.6);
ylabel('Demand L/s');
title('Richmond demand (one demand signal)');
grid on;

nexttile;
hold on;
pump_lines = gobjects(1,3);
for pump_index = 1:3
    display_state = lane_base(pump_index) ...
        + lane_height*pump_actual(:,pump_index);
    pump_lines(pump_index) = stairs(results.time, display_state, ...
        pump_styles{pump_index}, 'Color', pump_colours(pump_index,:), ...
        'LineWidth', 2.0);
end
hold off;
ylim([-0.15, 2.85]);
yticks(sort(lane_base + lane_height/2));
yticklabels({'P3 (0/1)', 'P2 (0/1)', 'P1 (0/1)'});
ylabel('Separate state lanes');
title(sprintf('Actual pump states (0=off, 1=on) | switches [%s]', ...
    strtrim(sprintf('%d ', results.switch_count_by_pump))));
legend(pump_lines, {'P1: solid', 'P2: dashed', 'P3: dotted'}, ...
    'Location', 'eastoutside');
grid on;

nexttile;
yyaxis left;
flow_line = stairs(results.time, 1000*results.actual_flow_m3s, '-', ...
    'Color', [0.0000 0.4470 0.7410], 'LineWidth', 2.0);
ylabel('Flow L/s');
ylim([0, max(105, 1.08*max(1000*results.actual_flow_m3s))]);
yyaxis right;
power_line = stairs(results.time, results.actual_power_kw, '--', ...
    'Color', [0.8500 0.3250 0.0980], 'LineWidth', 2.0);
ylabel('Power kW');
ylim([0, max(105, 1.08*max(results.actual_power_kw))]);
title('Actual total flow and power (separate y-axes)');
legend([flow_line, power_line], ...
    {'Flow: blue solid, left axis (L/s)', ...
     'Power: orange dashed, right axis (kW)'}, ...
    'Location', 'eastoutside');
grid on;

nexttile;
plot(results.level_time, results.level, 'b-', 'LineWidth', 1.8);
hold on;
yline(config.level_min_m, 'r--', 'Minimum level', 'LineWidth', 1.1);
yline(config.level_max_m, 'r--', 'Maximum level', 'LineWidth', 1.1);
hold off;
ylabel('Level m');
title(sprintf(['Tank level %.4f-%.4f m | final %.4f m | ', ...
    'violations %d'], min(results.level), max(results.level), ...
    results.final_level_m, results.constraint_violations));
grid on;

nexttile;
plot(results.time, results.cumulative_total_cost_aud, 'b-', ...
    'LineWidth', 1.8);
ylabel('Cost AUD');
xlabel('AEMO interval-ending time');
title(sprintf(['Total %.4f AUD = energy %.4f + switching %.4f | ', ...
    'pumped %.0f m^3'], results.total_cost_aud, ...
    results.total_energy_cost_aud, results.total_switching_cost_aud, ...
    results.total_pumped_volume_m3));
grid on;

if ~isempty(output_file)
    exportgraphics(figure_handle, output_file, 'Resolution', 180);
end
end
