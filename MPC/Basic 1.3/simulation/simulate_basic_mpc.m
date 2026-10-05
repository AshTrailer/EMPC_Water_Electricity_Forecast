function results = simulate_basic_mpc( ...
    config, scenario_mode, n_steps, make_plot, operating_day)
%SIMULATE_BASIC_MPC Run Basic 1.3 closed-loop rolling three-pump MILP.
% Historical prices are perfect-forecast controller inputs. This validates
% controller timing and feasibility, not a price predictor.

if nargin < 1 || isempty(config), config = basic_mpc_config(); end
if nargin < 2 || isempty(scenario_mode), scenario_mode = 'historical'; end
if nargin < 3 || isempty(n_steps), n_steps = config.default_simulation_steps; end
if nargin < 4 || isempty(make_plot), make_plot = true; end
if nargin < 5 || isempty(operating_day)
    operating_day = config.historical_start_day;
end
validateattributes(n_steps, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});

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
pump_request = zeros(n_steps,3);
pump_actual = zeros(n_steps,3);
mode_request = zeros(n_steps,1);
mode_actual = zeros(n_steps,1);
requested_flow_m3s = zeros(n_steps,1);
actual_flow_m3s = zeros(n_steps,1);
requested_power_kw = zeros(n_steps,1);
actual_power_kw = zeros(n_steps,1);
tracking_error_m3s = zeros(n_steps,1);
power_tracking_error_kw = zeros(n_steps,1);
predicted_next_level_error_m = zeros(n_steps,1);
energy_cost_aud = zeros(n_steps,1);
switch_event = zeros(n_steps,3);
exitflag = zeros(n_steps,1);
solve_time_seconds = zeros(n_steps,1);
plan_level_violations = zeros(n_steps,1);
plan_mass_balance_residual_m = zeros(n_steps,1);
optimization_horizon_steps = zeros(n_steps,1);
window_start_index = zeros(n_steps,1);
window_end_index = zeros(n_steps,1);
window_start_time = NaT(n_steps,1);
window_end_time = NaT(n_steps,1);
optimization_first_price = zeros(n_steps,1);
optimization_first_demand = zeros(n_steps,1);
optimization_first_action = zeros(n_steps,3);
solver_message = strings(n_steps,1);
level(1) = config.level_initial_m;
pump_actual_previous = zeros(1,3);

for k = 1:n_steps
    index = k:k+N-1;
    window.demand = all_data.demand(index);
    window.price = all_data.price(index);
    window.time = all_data.time(index);
    window.source = all_data.source;

    solution = constrained_tank_mpc(level(k), window, ...
        config, pump_actual_previous);
    request = mpc_to_decision_request(solution, all_data.time(k));
    execution = mock_decision_optimizer(request, config);

    pump_request(k,:) = solution.pump_request_now;
    pump_actual(k,:) = execution.pump_actual_state;
    mode_request(k) = solution.mode_now;
    mode_actual(k) = execution.actual_mode;
    requested_flow_m3s(k) = solution.requested_flow_m3s;
    actual_flow_m3s(k) = execution.actual_flow_m3s;
    requested_power_kw(k) = solution.requested_power_kw;
    actual_power_kw(k) = execution.actual_power_kw;
    tracking_error_m3s(k) = execution.tracking_error_m3s;
    power_tracking_error_kw(k) = execution.power_tracking_error_kw;
    exitflag(k) = solution.exitflag;
    solve_time_seconds(k) = solution.solve_time_seconds;
    plan_level_violations(k) = solution.level_constraint_violations;
    plan_mass_balance_residual_m(k) = ...
        solution.max_mass_balance_residual_m;
    optimization_horizon_steps(k) = size(solution.pump_request_plan,1);
    window_start_index(k) = index(1);
    window_end_index(k) = index(end);
    window_start_time(k) = window.time(1);
    window_end_time(k) = window.time(end);
    optimization_first_price(k) = solution.price_plan(1);
    optimization_first_demand(k) = solution.demand_plan(1);
    optimization_first_action(k,:) = solution.pump_request_plan(1,:);
    if isfield(solution.solver_output, 'message')
        solver_message(k) = string(solution.solver_output.message);
    end

    % The actual executor output, not the requested plan, advances the tank.
    level(k+1) = level(k)+config.dt_seconds/config.tank_area_m2 ...
        *(actual_flow_m3s(k)-all_data.demand(k));
    predicted_next_level_error_m(k) = ...
        level(k+1)-solution.x_prediction(1);
    energy_cost_aud(k) = all_data.price(k)*actual_power_kw(k) ...
        *(config.dt_seconds/3600)/1000;
    switch_event(k,:) = abs(pump_actual(k,:)-pump_actual_previous);
    pump_actual_previous = pump_actual(k,:);
end

results.time = all_data.time(1:n_steps);
results.level_time = [results.time(1)-seconds(config.dt_seconds); results.time];
results.level = level;
results.pump_request = pump_request;
results.pump_actual = pump_actual;
results.mode_request = mode_request;
results.mode_actual = mode_actual;
results.requested_flow_m3s = requested_flow_m3s;
results.actual_flow_m3s = actual_flow_m3s;
results.requested_power_kw = requested_power_kw;
results.actual_power_kw = actual_power_kw;
results.decision_tracking_error_m3s = tracking_error_m3s;
results.power_tracking_error_kw = power_tracking_error_kw;
results.predicted_next_level_error_m = predicted_next_level_error_m;
results.demand = all_data.demand(1:n_steps);
results.price_aud_per_mwh = all_data.price(1:n_steps);
results.energy_cost_aud = energy_cost_aud;
results.switch_event = switch_event;
results.cumulative_total_cost_aud = cumsum(energy_cost_aud ...
    + config.switch_cost_aud*sum(switch_event,2));
results.total_energy_cost_aud = sum(energy_cost_aud);
results.total_switching_cost_aud = ...
    config.switch_cost_aud*sum(switch_event,'all');
results.total_cost_aud = results.total_energy_cost_aud ...
    + results.total_switching_cost_aud;
results.switch_count_by_pump = sum(switch_event,1);
results.switch_count = sum(switch_event,'all');
results.pump_run_hours = sum(pump_actual,1)*config.dt_seconds/3600;
results.total_pumped_volume_m3 = sum(actual_flow_m3s)*config.dt_seconds;
results.final_level_m = level(end);
results.constraint_violations = nnz(level < config.level_min_m-1e-8 ...
    | level > config.level_max_m+1e-8);
results.exitflag = exitflag;
results.solve_time_seconds = solve_time_seconds;
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
results.optimization.exitflag = exitflag;
results.optimization.solver_message = solver_message;
results.optimization.solve_time_seconds = solve_time_seconds;
results.optimization.plan_level_violations = plan_level_violations;
results.optimization.plan_mass_balance_residual_m = ...
    plan_mass_balance_residual_m;
results.optimization.last_window_indices = ...
    window_start_index(end):window_end_index(end);

% Compatibility aliases are matrices in Basic 1.3, not scalar commands.
results.u_request = pump_request;
results.u_actual = pump_actual;
results.pump = pump_actual;

if make_plot
    plot_basic_mpc_results(results);
end
end
