function decision_result = mock_decision_optimizer(request, config)
%MOCK_DECISION_OPTIMIZER 临时的理想 Decision 执行器。
% 当前假设 Decision 能完全实现 MPC 要求的连续总流量。
% 组员的真实模块完成后，只替换本函数，不修改 MPC 核心算法。

if ~isstruct(request) || ~isfield(request, 'u_request') ...
        || ~isfield(request, 'requested_flow_m3s')
    error('mock_decision_optimizer:MissingField', ...
        'request 必须包含 u_request 和 requested_flow_m3s。');
end

u_actual = min(max(request.u_request, config.u_min), config.u_max);
actual_flow_m3s = config.max_requested_flow_m3s * u_actual;

decision_result.time = request.time;
decision_result.u_actual = u_actual;
decision_result.actual_flow_m3s = actual_flow_m3s;
decision_result.requested_flow_m3s = request.requested_flow_m3s;
decision_result.tracking_error_m3s = ...
    actual_flow_m3s - request.requested_flow_m3s;
decision_result.feasible = true;
decision_result.mode = '理想连续执行器';

% 下面的字段预留给组员的真实 Decision 模块
decision_result.pump_status = [];
decision_result.power_kw = NaN;
decision_result.run_time_hours = NaN;
end
