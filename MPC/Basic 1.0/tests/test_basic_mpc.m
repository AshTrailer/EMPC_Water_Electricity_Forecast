function test_results = test_basic_mpc()
%TEST_BASIC_MPC 对基础 MPC、双向接口和闭环约束执行确定性测试。

test_root = fileparts(mfilename('fullpath'));
basic_root = fileparts(test_root);
addpath(basic_root);
addpath(fullfile(basic_root, 'controller'));
addpath(fullfile(basic_root, 'interfaces'));
addpath(fullfile(basic_root, 'scenarios'));
addpath(fullfile(basic_root, 'simulation'));

config = basic_mpc_config();
tolerance = 1e-7;

fixed_results = simulate_basic_mpc(config, 'fixed', 48, false);
assert(all(fixed_results.level >= config.level_min_m-tolerance));
assert(all(fixed_results.level <= config.level_max_m+tolerance));
assert(all(fixed_results.u_request >= config.u_min-tolerance));
assert(all(fixed_results.u_request <= config.u_max+tolerance));
assert(all(fixed_results.u_actual >= config.u_min-tolerance));
assert(all(fixed_results.u_actual <= config.u_max+tolerance));
assert(all(abs(diff([0; fixed_results.u_request])) ...
    <= config.du_max+tolerance));
assert(all(abs(fixed_results.requested_flow_m3s ...
    - config.max_requested_flow_m3s*fixed_results.u_request) ...
    <= tolerance));
assert(all(abs(fixed_results.actual_flow_m3s ...
    - config.max_requested_flow_m3s*fixed_results.u_actual) ...
    <= tolerance));
assert(all(abs(fixed_results.decision_tracking_error_m3s) ...
    <= tolerance));
assert(all(fixed_results.exitflag > 0));

periodic_results = simulate_basic_mpc(config, 'periodic', 72, false);
assert(all(periodic_results.level >= config.level_min_m-tolerance));
assert(all(periodic_results.level <= config.level_max_m+tolerance));
assert(all(periodic_results.exitflag > 0));

mock = make_mock_decision_data(datetime(2026, 2, 1), ...
    config.horizon_steps, 'fixed');
adapted = decision_to_mpc_input(mock, config.horizon_steps);
assert(numel(adapted.demand) == config.horizon_steps);
assert(isfield(adapted, 'price'));

solution = constrained_tank_mpc(config.level_initial_m, mock, config, 0);
request = mpc_to_decision_request(solution, mock.time(1));
decision_result = mock_decision_optimizer(request, config);
assert(abs(request.requested_flow_m3s ...
    - solution.requested_flow_m3s) <= tolerance);
assert(abs(decision_result.actual_flow_m3s ...
    - request.requested_flow_m3s) <= tolerance);
assert(decision_result.feasible);

test_results.fixed = fixed_results;
test_results.periodic = periodic_results;
fprintf('基础 MPC 全部测试通过。\n');
end
