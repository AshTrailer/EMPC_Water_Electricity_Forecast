function test_results = test_basic_1_3_unit()
%TEST_BASIC_1_3_UNIT Deterministic short-horizon and one-shot MILP tests.

test_root = fileparts(mfilename('fullpath'));
basic_root = fileparts(test_root);
addpath(basic_root, fullfile(basic_root,'controller'), ...
    fullfile(basic_root,'interfaces'), fullfile(basic_root,'scenarios'), ...
    fullfile(basic_root,'simulation'));
config = basic_mpc_config();
tol = 1e-7;

assert(isequal(config.pump_flow_m3s, [0.050 0.030 0.020]));
assert(isequal(config.pump_power_kw, [43 27 19]));
assert(config.max_pumps == 3);
assert(~isfield(config,'terminal_min_m'));

states = [0 0 0; 1 0 0; 0 1 0; 0 0 1; ...
    1 1 0; 1 0 1; 0 1 1; 1 1 1];
mode = pump_state_to_mode(states);
flow = states*config.pump_flow_m3s(:);
power = states*config.pump_power_kw(:);
energy_kwh = power*config.dt_seconds/3600;
expected_flow = [0; .050; .030; .020; .080; .070; .050; .100];
expected_power = [0; 43; 27; 19; 70; 62; 46; 89];
expected_energy = [0; 3.583333333333333; 2.25; 1.583333333333333; ...
    5.833333333333333; 5.166666666666667; ...
    3.833333333333333; 7.416666666666667];
assert(isequal(mode, (0:7)'));
assert(max(abs(flow-expected_flow)) < tol);
assert(max(abs(power-expected_power)) < tol);
assert(max(abs(energy_kwh-expected_energy)) < tol);
pe100 = power(2:end)./(1000*flow(2:end))*100;
expected_pe100 = [86;90;95;87.5;88.5714285714286;92;89];
assert(max(abs(pe100-expected_pe100)) < tol);

% A state change [P1+P2] -> [P1+P3] contains two pump transitions.
assert(sum(abs([1 0 1]-[1 1 0])) == 2);

% Positive price: the same 50 L/s task costs less with P1 than P2+P3.
positive_price = 100;
p1_cost = positive_price*43*(config.dt_seconds/3600)/1000;
p23_cost = positive_price*(27+19)*(config.dt_seconds/3600)/1000;
assert(p1_cost < p23_cost);

% Short low-price/high-price case: pumping is shifted into the cheap half.
short_config = config;
short_config.horizon_steps = 24;
window.demand = 0.025*ones(24,1);
window.price = [10*ones(12,1); 200*ones(12,1)];
window.time = datetime(2026,2,1)+minutes(5)*(1:24)';
window.source = 'synthetic_low_then_high';
short_solution = constrained_tank_mpc(1.49, window, ...
    short_config, [0 0 0]);
assert(sum(short_solution.requested_flow_plan_m3s(1:12)) ...
    > sum(short_solution.requested_flow_plan_m3s(13:24)));
assert(all(short_solution.x_prediction >= config.level_min_m-tol));
assert(all(short_solution.x_prediction <= config.level_max_m+tol));
assert(short_solution.max_mass_balance_residual_m < tol);

request = mpc_to_decision_request(short_solution, window.time(1));
execution = mock_decision_optimizer(request, short_config);
actual_next = 1.49+config.dt_seconds/config.tank_area_m2 ...
    *(execution.actual_flow_m3s-window.demand(1));
assert(abs(actual_next-short_solution.x_prediction(1)) < tol);
assert(abs(execution.actual_flow_m3s ...
    - execution.pump_actual_state*config.pump_flow_m3s(:)) < tol);
assert(abs(execution.actual_power_kw ...
    - execution.pump_actual_state*config.pump_power_kw(:)) < tol);
expected_switch = abs(short_solution.pump_request_plan ...
    - [[0 0 0]; short_solution.pump_request_plan(1:end-1,:)]);
assert(isequal(short_solution.switch_plan, expected_switch));

% Negative prices legitimately reward high power if the upper level allows it.
negative_config = config;
negative_config.horizon_steps = 12;
negative_window.demand = 0.025*ones(12,1);
negative_window.price = -100*ones(12,1);
negative_window.time = datetime(2026,2,2)+minutes(5)*(1:12)';
negative_window.source = 'synthetic_negative_price';
negative_solution = constrained_tank_mpc(2.30, negative_window, ...
    negative_config, [0 0 0]);
assert(any(all(negative_solution.pump_request_plan == [1 1 1],2)));
assert(negative_solution.energy_cost_aud < 0);

% One complete 288-step MILP, before the 288-solve closed-loop test.
history = load_historical_price_data(config.historical_price_file, ...
    config.historical_region);
selected = select_interval_ending_history(history, ...
    config.historical_start_day, 288, config.dt_seconds);
full_window.demand = make_richmond_demand_series(config,288);
full_window.price = selected.price;
full_window.time = selected.time;
full_window.source = selected.source;
full_solution = constrained_tank_mpc(config.level_initial_m, ...
    full_window, config, [0 0 0]);
assert(size(full_solution.pump_request_plan,1) == 288);
assert(all(full_solution.x_prediction >= config.level_min_m-tol));
assert(all(full_solution.x_prediction <= config.level_max_m+tol));
assert(full_solution.max_mass_balance_residual_m < tol);

test_results.mode_states = states;
test_results.mode_flow_m3s = flow;
test_results.mode_power_kw = power;
test_results.mode_energy_kwh = energy_kwh;
test_results.mode_pe100 = [NaN; pe100];
test_results.short_low_high = short_solution;
test_results.negative = negative_solution;
test_results.full_horizon = full_solution;
fprintf(['UNIT_PASS modes=8 short_low_flow=%.3f short_high_flow=%.3f ', ...
    'negative_max_mode=%d full288_time=%.6f full288_cost=%.6f\n'], ...
    sum(short_solution.requested_flow_plan_m3s(1:12)), ...
    sum(short_solution.requested_flow_plan_m3s(13:24)), ...
    max(negative_solution.mode_plan), full_solution.solve_time_seconds, ...
    full_solution.objective);
end
