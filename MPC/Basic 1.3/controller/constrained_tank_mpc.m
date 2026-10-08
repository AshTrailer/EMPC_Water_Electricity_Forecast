function result = constrained_tank_mpc( ...
    x_current, decision_output, config, pump_previous)
%CONSTRAINED_TANK_MPC Solve the Basic 1.3 fixed-flow three-pump MILP.
% u(k,j) is binary. Water level is eliminated with the exact cumulative
% mass balance; it is not an independent control input. No terminal-level
% equality or flow-tracking penalty is imposed.

% Decision-vector order is z = [u(:,1);u(:,2);u(:,3);s(:,1);s(:,2);s(:,3)].

if nargin < 4 || isempty(pump_previous)
    pump_previous = zeros(1,3);
end
validateattributes(x_current, {'numeric'}, {'scalar', 'finite'});
validateattributes(pump_previous, {'numeric', 'logical'}, ...
    {'vector', 'numel', 3, 'finite'});
pump_previous = double(pump_previous(:)');
if any(pump_previous ~= 0 & pump_previous ~= 1)
    error('constrained_tank_mpc:PreviousState', ...
        'pump_previous must contain three binary states.');
end
if config.max_pumps ~= 3
    error('constrained_tank_mpc:MaxPumps', ...
        'Basic 1.3 requires max_pumps=3.');
end
validateattributes(config.pump_flow_m3s, {'numeric'}, ...
    {'vector', 'numel', 3, 'positive', 'finite'});
validateattributes(config.pump_power_kw, {'numeric'}, ...
    {'vector', 'numel', 3, 'positive', 'finite'});

N = config.horizon_steps;
mpc_input = decision_to_mpc_input(decision_output, N);
demand = mpc_input.demand;
price = mpc_input.price;
q = config.pump_flow_m3s(:)';
power = config.pump_power_kw(:)';
enabled = logical(config.pump_enabled(:)');
alpha = config.dt_seconds/config.tank_area_m2;

I = speye(N);
L = sparse(tril(ones(N)));
flow_map = kron(q, I);
level_map = alpha*L*flow_map;
x_base = x_current*ones(N,1)-alpha*L*demand;

% Hard tank bounds and the explicit simultaneous-pump limit.
A_level = [level_map, sparse(N,3*N); ...
    -level_map, sparse(N,3*N)];
b_level = [config.level_max_m-x_base; ...
    x_base-config.level_min_m];
A_count = [kron(ones(1,3), I), sparse(N,3*N)];
b_count = config.max_pumps*ones(N,1);

% s(j,k) >= abs(u(j,k)-u(j,k-1)), including the actual previous state.
D = spdiags([-ones(N,1), ones(N,1)], [-1,0], N, N);
D(1,1) = 1;
D3 = kron(speye(3), D);
previous_offset = zeros(3*N,1);
for j = 1:3
    previous_offset((j-1)*N+1) = pump_previous(j);
end
A_switch = [D3, -speye(3*N); -D3, -speye(3*N)];
b_switch = [previous_offset; -previous_offset];

A = [A_level; A_count; A_switch];
b = [b_level; b_count; b_switch];
energy_coefficient = kron(power(:), ...
    price*(config.dt_seconds/3600)/1000);
f = [energy_coefficient; ...
    config.switch_cost_aud*ones(3*N,1)];
lb = zeros(6*N,1);
ub = ones(6*N,1);
for j = 1:3
    if ~enabled(j)
        ub((j-1)*N+(1:N)) = 0;
    end
end
intcon = 1:3*N;

solve_timer = tic;
[z, objective, exitflag, output] = intlinprog( ...
    f, intcon, A, b, [], [], lb, ub, config.intlinprog_options);
solve_time_seconds = toc(solve_timer);
if isempty(z) || exitflag <= 0
    message = '';
    if isstruct(output) && isfield(output, 'message')
        message = output.message;
    end
    error('constrained_tank_mpc:Infeasible', ...
        'intlinprog failed (exitflag %d): %s', exitflag, message);
end

pump_plan = round(reshape(z(1:3*N), N, 3));
switch_plan = round(reshape(z(3*N+1:end), N, 3));
requested_flow_plan_m3s = pump_plan*q(:);
requested_power_plan_kw = pump_plan*power(:);
x_prediction = x_base+level_map*pump_plan(:);
mode_plan = pump_state_to_mode(pump_plan);
energy_cost_plan_aud = price.*requested_power_plan_kw ...
    *(config.dt_seconds/3600)/1000;

result.pump_request_plan = pump_plan;
result.pump_request_now = pump_plan(1,:);
result.mode_plan = mode_plan;
result.mode_now = mode_plan(1);
result.requested_flow_plan_m3s = requested_flow_plan_m3s;
result.requested_flow_m3s = requested_flow_plan_m3s(1);
result.requested_power_plan_kw = requested_power_plan_kw;
result.requested_power_kw = requested_power_plan_kw(1);
result.switch_plan = switch_plan;
result.x_prediction = x_prediction;
result.price_plan = price;
result.demand_plan = demand;
result.time_plan = mpc_input.time;
result.energy_cost_plan_aud = energy_cost_plan_aud;
result.energy_cost_aud = sum(energy_cost_plan_aud);
result.switching_cost_aud = config.switch_cost_aud*sum(switch_plan,'all');
result.objective = objective;
result.exitflag = exitflag;
result.feasible = true;
result.input_source = mpc_input.source;
result.solver = 'intlinprog_three_pump_milp';
result.solve_time_seconds = solve_time_seconds;
result.solver_output = output;
result.max_mass_balance_residual_m = max(abs(diff( ...
    [x_current; x_prediction])-alpha*( ...
    requested_flow_plan_m3s-demand)));
result.level_constraint_violations = nnz( ...
    x_prediction < config.level_min_m-1e-8 | ...
    x_prediction > config.level_max_m+1e-8);

% Compatibility aliases retained only for callers that use generic names.
result.u_request = result.pump_request_now;
result.u_request_plan = result.pump_request_plan;
result.u_now = result.pump_request_now;
result.u_plan = result.pump_request_plan;
end
