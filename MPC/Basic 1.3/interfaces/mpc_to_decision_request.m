function request = mpc_to_decision_request(mpc_result, request_time)
%MPC_TO_DECISION_REQUEST Package the first three-pump MILP action.

required = {'pump_request_now', 'pump_request_plan', ...
    'mode_now', 'requested_flow_m3s', 'requested_power_kw'};
if ~isstruct(mpc_result) || ~all(isfield(mpc_result, required))
    error('mpc_to_decision_request:MissingField', ...
        'mpc_result is missing a Basic 1.3 request field.');
end
validateattributes(mpc_result.pump_request_now, {'numeric'}, ...
    {'row', 'numel', 3, 'finite'});

request.time = request_time;
request.pump_request_now = mpc_result.pump_request_now;
request.pump_request_plan = mpc_result.pump_request_plan;
request.mode_now = mpc_result.mode_now;
request.requested_flow_m3s = mpc_result.requested_flow_m3s;
request.requested_flow_plan_m3s = mpc_result.requested_flow_plan_m3s;
request.requested_power_kw = mpc_result.requested_power_kw;
request.requested_power_plan_kw = mpc_result.requested_power_plan_kw;
request.switch_plan = mpc_result.switch_plan;
request.interface_revision = 3;
end
