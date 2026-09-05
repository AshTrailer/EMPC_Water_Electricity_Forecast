function request = mpc_to_decision_request(mpc_result, request_time)
%MPC_TO_DECISION_REQUEST 把 MPC 的连续流量要求整理成 Decision 接口。
% Decision 模块只需要读取要求流量，再决定具体水泵组合和运行时间。

if ~isstruct(mpc_result) || ~isfield(mpc_result, 'u_request') ...
        || ~isfield(mpc_result, 'requested_flow_m3s')
    error('mpc_to_decision_request:MissingField', ...
        'mpc_result 必须包含 u_request 和 requested_flow_m3s。');
end

validateattributes(mpc_result.u_request, {'numeric'}, ...
    {'scalar', 'finite'});
validateattributes(mpc_result.requested_flow_m3s, {'numeric'}, ...
    {'scalar', 'finite', 'nonnegative'});

request.time = request_time;
request.u_request = mpc_result.u_request;
request.requested_flow_m3s = mpc_result.requested_flow_m3s;
request.requested_flow_plan_m3s = ...
    mpc_result.requested_flow_plan_m3s;
request.interface_revision = 1;
end
