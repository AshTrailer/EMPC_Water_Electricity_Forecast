function results = simulate_basic_mpc( ...
    config, scenario_mode, n_steps, make_plot, operating_day)
%SIMULATE_BASIC_MPC Run Basic 1.2 price-driven rolling-horizon MPC.
% Historical mode uses the actual future prices as a perfect forecast. This
% isolates and validates the economic controller; it is not a price predictor.

if nargin < 1 || isempty(config)
    config = basic_mpc_config();
end
if nargin < 2 || isempty(scenario_mode)
    scenario_mode = 'historical';
end
if nargin < 3 || isempty(n_steps)
    n_steps = config.default_simulation_steps;
end
if nargin < 4 || isempty(make_plot)
    make_plot = true;
end
if nargin < 5 || isempty(operating_day)
    operating_day = config.historical_start_day;
end
validateattributes(n_steps, {'numeric'}, {'scalar', 'integer', 'positive'});

N = config.horizon_steps;
required_steps = n_steps+N-1;
if strcmpi(scenario_mode, 'historical')
    history = load_historical_price_data(config.historical_price_file, ...
        config.historical_region);
    selected = select_interval_ending_history(history, operating_day, ...
        required_steps, config.dt_seconds);
    all_data.time = selected.time;
    all_data.price = selected.price;
    all_data.demand = make_richmond_demand_series(config, required_steps);
    all_data.source = selected.source;
    source_file = selected.source_file;
    input_index_in_history = selected.index_in_history;
    interval_convention = selected.interval_convention;
else
    all_data = make_mock_decision_data(datetime(2026,2,1,0,5,0), ...
        required_steps, scenario_mode, config);
    source_file = '';
    input_index_in_history = (1:required_steps)';
    interval_convention = 'synthetic interval-ending';
end

level = zeros(n_steps+1,1);
u_request = zeros(n_steps,1);
u_actual = zeros(n_steps,1);
requested_flow_m3s = zeros(n_steps,1);
actual_flow_m3s = zeros(n_steps,1);
decision_tracking_error_m3s = zeros(n_steps,1);
predicted_next_level_error_m = zeros(n_steps,1);
energy_cost_aud = zeros(n_steps,1);
switch_event = zeros(n_steps,1);
exitflag = zeros(n_steps,1);
optimization_horizon_steps = zeros(n_steps,1);
window_start_index = zeros(n_steps,1);
window_end_index = zeros(n_steps,1);
window_start_time = NaT(n_steps,1);
window_end_time = NaT(n_steps,1);
optimization_first_price = zeros(n_steps,1);
optimization_first_demand = zeros(n_steps,1);
optimization_first_action = zeros(n_steps,1);
level(1) = config.level_initial_m;
u_actual_previous = 0;

for k = 1:n_steps
    index = k:k+N-1;
    if numel(index) ~= N
        error('simulate_basic_mpc:HorizonLength', ...
            'Optimization %d did not receive %d input samples.', k, N);
    end
    window.demand = all_data.demand(index);
    window.price = all_data.price(index);
    window.time = all_data.time(index);
    window.source = all_data.source;

    solution = constrained_tank_mpc(level(k), window, ...
        config, u_actual_previous);
    request = mpc_to_decision_request(solution, all_data.time(k));
    decision_result = mock_decision_optimizer(request, config);

    u_request(k) = solution.u_request;
    requested_flow_m3s(k) = solution.requested_flow_m3s;
    u_actual(k) = decision_result.u_actual;
    actual_flow_m3s(k) = decision_result.actual_flow_m3s;
    decision_tracking_error_m3s(k) = ...
        decision_result.tracking_error_m3s;
    exitflag(k) = solution.exitflag;
    optimization_horizon_steps(k) = numel(solution.u_request_plan);
    window_start_index(k) = index(1);
    window_end_index(k) = index(end);
    window_start_time(k) = window.time(1);
    window_end_time(k) = window.time(end);
    optimization_first_price(k) = solution.price_plan(1);
    optimization_first_demand(k) = solution.demand_plan(1);
    optimization_first_action(k) = solution.u_request_plan(1);

    % u(k), demand(k) and price(k) all belong to the interval ending at
    % time(k); their resulting state is x(k+1) at that same timestamp.
    level(k+1) = level(k)+config.dt_seconds/config.tank_area_m2 ...
        *(actual_flow_m3s(k)-all_data.demand(k));
    predicted_next_level_error_m(k) = ...
        level(k+1)-solution.x_prediction(1);
    energy_cost_aud(k) = all_data.price(k)/1000 ...
        * config.pump_power_kw*(config.dt_seconds/3600)*u_actual(k);
    switch_event(k) = abs(u_actual(k)-u_actual_previous);
    u_actual_previous = u_actual(k);
end

% Inherited price-blind benchmark: alternating operation supplies a fixed
% mean inflow of 25 L/s. Because the unnormalized Richmond mean demand is
% 24.90625 L/s, it is a reference trace rather than an equal-volume claim.
baseline_u = double(mod((1:n_steps)',2) == 1);
baseline_level = zeros(n_steps+1,1);
baseline_level(1) = config.level_initial_m;
for k = 1:n_steps
    baseline_level(k+1) = baseline_level(k) ...
        + config.dt_seconds/config.tank_area_m2 ...
        * (config.pump_flow_m3s*baseline_u(k)-all_data.demand(k));
end
baseline_switch = abs(baseline_u-[0; baseline_u(1:end-1)]);
baseline_energy_cost_aud = all_data.price(1:n_steps)/1000 ...
    * config.pump_power_kw*(config.dt_seconds/3600).*baseline_u;

results.time = all_data.time(1:n_steps);
results.level_time = [results.time(1)-seconds(config.dt_seconds); ...
    results.time];
results.level = level;
results.u_request = u_request;
results.u_actual = u_actual;
results.pump = u_actual;
results.requested_flow_m3s = requested_flow_m3s;
results.actual_flow_m3s = actual_flow_m3s;
results.decision_tracking_error_m3s = decision_tracking_error_m3s;
results.predicted_next_level_error_m = predicted_next_level_error_m;
results.demand = all_data.demand(1:n_steps);
results.price_aud_per_mwh = all_data.price(1:n_steps);
results.energy_cost_aud = energy_cost_aud;
results.switch_event = switch_event;
results.cumulative_total_cost_aud = cumsum(energy_cost_aud ...
    + config.switch_cost_aud*switch_event);
results.total_energy_cost_aud = sum(energy_cost_aud);
results.total_switching_cost_aud = config.switch_cost_aud*sum(switch_event);
results.total_cost_aud = results.total_energy_cost_aud ...
    + results.total_switching_cost_aud;
results.switch_count = sum(switch_event);
results.constraint_violations = sum(level < config.level_min_m-1e-8 ...
    | level > config.level_max_m+1e-8);
results.exitflag = exitflag;
results.scenario_mode = scenario_mode;
results.data_source = all_data.source;
results.source_file = source_file;
results.config = config;
results.input_count = required_steps;
results.input_time = all_data.time;
results.input_price_aud_per_mwh = all_data.price;
results.input_demand_m3s = all_data.demand;
results.input_index_in_history = input_index_in_history;
results.interval_convention = interval_convention;
results.optimization_count = n_steps;
results.optimization.horizon_steps = optimization_horizon_steps;
results.optimization.window_start_index = window_start_index;
results.optimization.window_end_index = window_end_index;
results.optimization.window_start_time = window_start_time;
results.optimization.window_end_time = window_end_time;
results.optimization.first_price_aud_per_mwh = optimization_first_price;
results.optimization.first_demand_m3s = optimization_first_demand;
results.optimization.first_action = optimization_first_action;
results.optimization.last_window_indices = ...
    window_start_index(end):window_end_index(end);

results.baseline.u = baseline_u;
results.baseline.level = baseline_level;
results.baseline.energy_cost_aud = baseline_energy_cost_aud;
results.baseline.total_energy_cost_aud = sum(baseline_energy_cost_aud);
results.baseline.switch_count = sum(baseline_switch);
results.baseline.total_cost_aud = sum(baseline_energy_cost_aud) ...
    + config.switch_cost_aud*sum(baseline_switch);
results.baseline.cumulative_total_cost_aud = ...
    cumsum(baseline_energy_cost_aud ...
    + config.switch_cost_aud*baseline_switch);

if any(u_actual == 1)
    results.average_price_when_on = mean( ...
        results.price_aud_per_mwh(u_actual == 1));
else
    results.average_price_when_on = NaN;
end
results.baseline.average_price_when_on = mean( ...
    results.price_aud_per_mwh(baseline_u == 1));

if make_plot
    figure('Name', 'Basic 1.2 Rolling-horizon Binary MPC', ...
        'Color', 'white', 'Position', [80 20 1400 1350]);
    layout = tiledlayout(6,1, 'TileSpacing', 'compact', ...
        'Padding', 'compact');
    title(layout, sprintf(['Basic 1.2: %d closed-loop optimizations, ', ...
        'each with a %d-step horizon'], n_steps, N));

    nexttile;
    plot(results.time, results.price_aud_per_mwh, 'k-', ...
        'LineWidth', 1.0);
    ylabel('RRP (AUD/MWh)');
    title('Historical VIC1 price used during the displayed 0-24 h');
    grid on;

    nexttile;
    last_window_index = results.optimization.last_window_indices;
    plot(results.input_time(last_window_index), ...
        results.input_price_aud_per_mwh(last_window_index), ...
        'Color', [0.55 0.10 0.65], 'LineWidth', 1.0);
    ylabel('RRP (AUD/MWh)');
    title(sprintf(['Historical VIC1 price from 24-48 h: final MPC ', ...
        'window (%d:%d)'], last_window_index(1), ...
        last_window_index(end)));
    grid on;

    nexttile;
    stairs(results.time, 1000*results.demand, 'Color', ...
        [0.10 0.55 0.25], 'LineWidth', 1.2);
    hold on;
    annotation_count = min(24, ...
        ceil(n_steps*config.dt_seconds/3600));
    annotation_time = results.level_time(1)+minutes(30) ...
        + hours((0:annotation_count-1)');
    annotation_demand_ls = 1000*config.base_water_demand_m3s ...
        .* config.demand_multiplier_hourly(1:annotation_count)';
    plot(annotation_time, annotation_demand_ls, 'o', ...
        'Color', [0.05 0.35 0.15], 'MarkerSize', 3, ...
        'HandleVisibility', 'off');
    text(annotation_time, annotation_demand_ls+0.7, ...
        compose('%.2fx', ...
        config.demand_multiplier_hourly(1:annotation_count)'), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', 7.5, ...
        'Color', [0.05 0.30 0.12]);
    ylabel('Demand (L/s)');
    title('Richmond 24-hour demand profile (labels show d_m)');
    ylim([1000*min(config.water_demand_m3s)-2, ...
        1000*max(config.water_demand_m3s)+4]);
    grid on;

    nexttile;
    stairs(results.time, u_actual, 'b-', 'LineWidth', 1.2);
    hold on;
    stairs(results.time, baseline_u, 'Color', [0.75 0.75 0.75]);
    ylabel('Pump on/off');
    yticks([0 1]);
    legend('Economic MPC', 'Price-blind benchmark', 'Location', 'best');
    grid on;

    nexttile;
    plot(results.level_time, level, 'b-', 'LineWidth', 1.2);
    hold on;
    yline(config.level_min_m, 'r--');
    yline(config.level_max_m, 'r--');
    ylabel('Tank level (m)');
    legend('Actual level', 'Hard bounds', 'Location', 'best');
    grid on;

    nexttile;
    plot(results.time, results.cumulative_total_cost_aud, ...
        'b-', 'LineWidth', 1.2);
    hold on;
    plot(results.time, results.baseline.cumulative_total_cost_aud, ...
        'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
    ylabel('Cumulative cost (AUD)');
    xlabel('Time');
    legend('Economic MPC', 'Price-blind benchmark', 'Location', 'best');
    grid on;
end
end
