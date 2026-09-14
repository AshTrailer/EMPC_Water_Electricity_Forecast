function test_results = test_basic_mpc()
%TEST_BASIC_MPC Deterministic Basic 1.1.1 controller and history checks.

test_root = fileparts(mfilename('fullpath'));
basic_root = fileparts(test_root);
addpath(basic_root);
addpath(fullfile(basic_root, 'controller'));
addpath(fullfile(basic_root, 'interfaces'));
addpath(fullfile(basic_root, 'scenarios'));
addpath(fullfile(basic_root, 'simulation'));

config = basic_mpc_config();
tolerance = 1e-7;

% A controlled price step proves that pumping moves to the cheap period.
unit_config = config;
unit_config.horizon_steps = 24;
unit_window.demand = unit_config.water_demand_m3s*ones(24,1);
unit_window.price = [10*ones(12,1); 200*ones(12,1)];
unit_window.time = datetime(2026,2,1)+minutes(5)*(1:24)';
unit_window.source = 'synthetic_price_step';
unit_initial_level = 1.49;
unit_solution = constrained_tank_mpc( ...
    unit_initial_level, unit_window, unit_config, 0);
assert(all(unit_solution.u_plan == 0 | unit_solution.u_plan == 1));
assert(sum(unit_solution.u_plan(1:12)) > ...
    sum(unit_solution.u_plan(13:24)), ...
    'Pump operation did not move to the cheap-price period.');
assert(sum(unit_solution.u_plan(1:12)) == 6 ...
    && sum(unit_solution.u_plan(13:24)) == 0, ...
    'Exact binary optimum for the controlled price step is incorrect.');
unit_energy_mwh = unit_config.pump_power_kw ...
    * (unit_config.dt_seconds/3600)/1000;
unit_expected_objective = 6*10*unit_energy_mwh ...
    + 2*unit_config.switch_cost_aud;
assert(abs(unit_solution.objective-unit_expected_objective) <= tolerance);
assert(all(unit_solution.x_prediction >= config.level_min_m-tolerance));
assert(all(unit_solution.x_prediction <= config.level_max_m+tolerance));

history = load_historical_price_data(config.historical_price_file, ...
    config.historical_region);
assert(numel(history.price) >= config.horizon_steps);
assert(all(seconds(diff(history.time)) == config.dt_seconds));
assert(all(isfinite(history.price)));

% Twelve historical hours are sufficient for a closed-loop integration
% check while every optimization still sees a full 24-hour price horizon.
historical_results = simulate_basic_mpc(config, 'historical', 144, false);
assert(all(historical_results.u_actual == 0 ...
    | historical_results.u_actual == 1));
assert(all(historical_results.level >= config.level_min_m-tolerance));
assert(all(historical_results.level <= config.level_max_m+tolerance));
assert(historical_results.constraint_violations == 0);
assert(all(historical_results.exitflag > 0));
assert(max(abs(historical_results.decision_tracking_error_m3s)) ...
    <= tolerance);
assert(max(abs(historical_results.predicted_next_level_error_m)) ...
    <= tolerance, 'Predicted x(k+1) is not aligned with actual x(k+1).');
assert(all(historical_results.level_time(2:end) ...
    == historical_results.time), ...
    'Level and interval-end price timestamps are misaligned.');
expected_energy_cost = sum(historical_results.price_aud_per_mwh/1000 ...
    * config.pump_power_kw*(config.dt_seconds/3600) ...
    .* historical_results.u_actual);
assert(abs(expected_energy_cost ...
    - historical_results.total_energy_cost_aud) <= tolerance);
assert(historical_results.average_price_when_on ...
    < historical_results.baseline.average_price_when_on, ...
    'Historical run did not concentrate pumping at lower prices.');

test_results.synthetic = unit_solution;
test_results.history = history;
test_results.historical = historical_results;
fprintf(['Basic 1.1.1 tests passed: binary price optimization, hard ', ...
    'level bounds, five-minute timing and historical CSV.\n']);
end
