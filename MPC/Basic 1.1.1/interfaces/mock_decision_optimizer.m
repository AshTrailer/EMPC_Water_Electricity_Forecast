function decision_result = mock_decision_optimizer(request, config)
%MOCK_DECISION_OPTIMIZER Ideal executor for one binary fixed-flow pump.

if ~isstruct(request) || ~isfield(request, 'u_request') ...
        || ~isfield(request, 'requested_flow_m3s')
    error('mock_decision_optimizer:MissingField', ...
        'request must contain u_request and requested_flow_m3s.');
end
u_actual = round(request.u_request);
if abs(u_actual-request.u_request) > 1e-8 || ...
        ~(u_actual == 0 || u_actual == 1)
    error('mock_decision_optimizer:NonBinary', ...
        'Basic 1.1.1 accepts only binary pump commands.');
end
actual_flow_m3s = config.pump_flow_m3s*u_actual;

decision_result.time = request.time;
decision_result.u_actual = u_actual;
decision_result.pump_status = u_actual;
decision_result.actual_flow_m3s = actual_flow_m3s;
decision_result.requested_flow_m3s = request.requested_flow_m3s;
decision_result.tracking_error_m3s = ...
    actual_flow_m3s-request.requested_flow_m3s;
decision_result.power_kw = config.pump_power_kw*u_actual;
decision_result.feasible = true;
decision_result.mode = 'ideal_binary_executor';
end
