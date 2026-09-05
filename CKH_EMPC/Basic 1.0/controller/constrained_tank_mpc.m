function result = constrained_tank_mpc(x_current, decision_output, config, u_previous)
%CONSTRAINED_TANK_MPC 单水箱连续期望流量的约束 MPC。
% 输入 u 是泵站期望总流量的归一化比例，不代表具体水泵的开关状态。
% Decision 模块随后负责把这个连续要求转换成可执行的水泵组合。

if nargin < 4 || isempty(u_previous)
    u_previous = 0;
end
validateattributes(x_current, {'numeric'}, {'scalar', 'finite'});
validateattributes(u_previous, {'numeric'}, {'scalar', 'finite'});

if exist('quadprog', 'file') ~= 2
    error('constrained_tank_mpc:MissingSolver', ...
        '需要 quadprog。请安装或启用 Optimization Toolbox。');
end

N = config.horizon_steps;
mpc_input = decision_to_mpc_input(decision_output, N);
demand = mpc_input.demand;
level_ref = mpc_input.level_ref;

dt_over_area = config.dt_seconds / config.tank_area_m2;
lower_sum = tril(ones(N));
Phi = dt_over_area * config.max_requested_flow_m3s * lower_sum;
x_base = x_current*ones(N, 1) ...
    - dt_over_area*lower_sum*demand;

move_matrix = eye(N);
for row = 2:N
    move_matrix(row, row-1) = -1;
end
previous_vector = zeros(N, 1);
previous_vector(1) = u_previous;

Q = config.weight_level * eye(N);
R = config.weight_input * eye(N);
Rd = config.weight_move * eye(N);

H = 2*(Phi'*Q*Phi + R + move_matrix'*Rd*move_matrix);
H = (H + H')/2 + 1e-10*eye(N);
f = 2*(Phi'*Q*(x_base - level_ref) ...
    - move_matrix'*Rd*previous_vector);

A_level = [Phi; -Phi];
b_level = [config.level_max_m*ones(N, 1) - x_base; ...
    x_base - config.level_min_m*ones(N, 1)];
A_move = [move_matrix; -move_matrix];
b_move = [config.du_max*ones(N, 1) + previous_vector; ...
    config.du_max*ones(N, 1) - previous_vector];

lb = config.u_min * ones(N, 1);
ub = config.u_max * ones(N, 1);
options = optimoptions('quadprog', 'Display', 'off');
[u_plan, objective, exitflag, solver_output] = quadprog( ...
    H, f, [A_level; A_move], [b_level; b_move], ...
    [], [], lb, ub, [], options);

if exitflag <= 0
    error('constrained_tank_mpc:Infeasible', ...
        'MPC 求解失败：exitflag=%d，求解器信息=%s', ...
        exitflag, solver_output.message);
end

x_prediction = x_base + Phi*u_plan;

% 对外输出使用 request 命名，明确它只是 MPC 的连续要求值
result.u_request = u_plan(1);
result.u_request_plan = u_plan;
result.requested_flow_m3s = ...
    config.max_requested_flow_m3s * result.u_request;
result.requested_flow_plan_m3s = ...
    config.max_requested_flow_m3s * u_plan;
result.x_prediction = x_prediction;
result.objective = objective;
result.exitflag = exitflag;
result.feasible = true;
result.input_source = mpc_input.source;

% 兼容旧代码的字段；新代码应优先使用上面的 request 字段
result.u_now = result.u_request;
result.u_plan = result.u_request_plan;
end
