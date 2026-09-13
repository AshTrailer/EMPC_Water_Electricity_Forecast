function result = constrained_tank_mpc(x_current, decision_output, config, u_previous)
%CONSTRAINED_TANK_MPC Exact price-driven MPC for one binary fixed-flow pump.
% x(k+1) = x(k) + dt/area * (pump_flow*u(k) - demand(k)).
% The level is a hard constraint. Dynamic programming finds the global
% minimum over all feasible binary schedules without a slow generic MILP.

if nargin < 4 || isempty(u_previous)
    u_previous = 0;
end
validateattributes(x_current, {'numeric'}, {'scalar', 'finite'});
validateattributes(u_previous, {'numeric'}, ...
    {'scalar', 'integer', '>=', 0, '<=', 1});
if config.max_pumps ~= 1
    error('constrained_tank_mpc:Scope', ...
        'Basic 1.2 supports exactly one binary pump.');
end

N = config.horizon_steps;
mpc_input = decision_to_mpc_input(decision_output, N);
demand = mpc_input.demand;
price = mpc_input.price;
dt_over_area = config.dt_seconds/config.tank_area_m2;
energy_per_on_step_mwh = config.pump_power_kw ...
    * (config.dt_seconds/3600)/1000;
energy_cost = price*energy_per_on_step_mwh;
cumulative_demand = cumsum(demand);

% A state is (number of completed steps, number of ON commands, last
% command). Its water level is uniquely determined even for varying demand.
cost_previous = inf(N+1,2);
cost_previous(1,u_previous+1) = 0;
parent_last = -ones(N,N+1,2,'int8');

for k = 1:N
    cost_current = inf(N+1,2);
    for on_previous = 0:k-1
        for last = 0:1
            old_cost = cost_previous(on_previous+1,last+1);
            if ~isfinite(old_cost)
                continue;
            end
            for u = 0:1
                on_count = on_previous+u;
                x_next = x_current+dt_over_area ...
                    *(config.pump_flow_m3s*on_count-cumulative_demand(k));
                if x_next < config.level_min_m-1e-10 ...
                        || x_next > config.level_max_m+1e-10
                    continue;
                end
                candidate = old_cost+energy_cost(k)*u ...
                    + config.switch_cost_aud*abs(u-last);
                if candidate < cost_current(on_count+1,u+1)
                    cost_current(on_count+1,u+1) = candidate;
                    parent_last(k,on_count+1,u+1) = int8(last);
                end
            end
        end
    end
    cost_previous = cost_current;
end

best_cost = inf;
best_on_count = -1;
best_last = -1;
for on_count = 0:N
    for last = 0:1
        candidate = cost_previous(on_count+1,last+1);
        if candidate < best_cost
            best_cost = candidate;
            best_on_count = on_count;
            best_last = last;
        end
    end
end
if ~isfinite(best_cost)
    error('constrained_tank_mpc:Infeasible', ...
        'No binary pump schedule satisfies the hard level bounds.');
end

u_plan = zeros(N,1);
on_count = best_on_count;
last = best_last;
for k = N:-1:1
    u_plan(k) = last;
    previous_last = double(parent_last(k,on_count+1,last+1));
    on_count = on_count-last;
    last = previous_last;
end

lower_sum = tril(ones(N));
Phi = dt_over_area*config.pump_flow_m3s*lower_sum;
x_base = x_current*ones(N,1)-dt_over_area*lower_sum*demand;
x_prediction = x_base+Phi*u_plan;
switch_plan = abs(u_plan-[u_previous; u_plan(1:end-1)]);

result.u_request = u_plan(1);
result.u_request_plan = u_plan;
result.requested_flow_m3s = config.pump_flow_m3s*result.u_request;
result.requested_flow_plan_m3s = config.pump_flow_m3s*u_plan;
result.switch_plan = switch_plan;
result.x_prediction = x_prediction;
result.price_plan = price;
result.demand_plan = demand;
result.time_plan = mpc_input.time;
result.energy_cost_plan_aud = energy_cost.*u_plan;
result.objective = best_cost;
result.energy_cost_aud = sum(result.energy_cost_plan_aud);
result.switching_cost_aud = config.switch_cost_aud*sum(switch_plan);
result.exitflag = 1;
result.feasible = true;
result.input_source = mpc_input.source;
result.solver = 'exact_binary_dynamic_programming';

% Compatibility aliases retained from Basic 1.0.
result.u_now = result.u_request;
result.u_plan = result.u_request_plan;
end
