function results = simulate_basic_mpc(config, scenario_mode, n_steps, make_plot)
%SIMULATE_BASIC_MPC Run Basic 1.1.1 price-driven receding-horizon control.
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
validateattributes(n_steps, {'numeric'}, {'scalar', 'integer', 'positive'});

N = config.horizon_steps;
required_steps = n_steps+N-1;
if strcmpi(scenario_mode, 'historical')
    history = load_historical_price_data(config.historical_price_file, ...
        config.historical_region);
    if numel(history.price) < required_steps
        error('simulate_basic_mpc:ShortHistory', ...
            'Historical CSV has %d samples; simulation requires %d.', ...
            numel(history.price), required_steps);
    end
    all_data.time = history.time(1:required_steps);
    all_data.price = history.price(1:required_steps);
    all_data.demand = config.water_demand_m3s*ones(required_steps,1);
    all_data.source = history.source;
    source_file = history.source_file;
else
    all_data = make_mock_decision_data(datetime(2026,2,1,0,5,0), ...
        required_steps, scenario_mode, config);
    source_file = '';
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
level(1) = config.level_initial_m;
u_actual_previous = 0;

for k = 1:n_steps
    index = k:k+N-1;
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

% Price-blind equal-volume benchmark: alternating operation supplies the
% same constant average flow and finishes at its starting level.
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
    figure('Name', 'Basic 1.1.1 Price-driven Binary MPC');
    tiledlayout(4,1);

    nexttile;
    plot(results.time, results.price_aud_per_mwh, 'k-', ...
        'LineWidth', 1.0);
    ylabel('RRP (AUD/MWh)');
    title('Historical VIC1 price');
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
