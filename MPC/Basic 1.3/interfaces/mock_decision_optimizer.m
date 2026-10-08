function decision_result = mock_decision_optimizer(request, config)
%MOCK_DECISION_OPTIMIZER Ideal executor for three fixed-flow pumps.

required = {'pump_request_now', 'requested_flow_m3s', ...
    'requested_power_kw'};
if ~isstruct(request) || ~all(isfield(request, required))
    error('mock_decision_optimizer:MissingField', ...
        'request is missing a Basic 1.3 field.');
end
pump_actual_state = round(request.pump_request_now(:)');
if any(abs(pump_actual_state-request.pump_request_now(:)') > 1e-8) ...
        || any(pump_actual_state ~= 0 & pump_actual_state ~= 1)
    error('mock_decision_optimizer:NonBinary', ...
        'Basic 1.3 accepts three binary pump commands.');
end
actual_flow_m3s = pump_actual_state*config.pump_flow_m3s(:);
actual_power_kw = pump_actual_state*config.pump_power_kw(:);

decision_result.time = request.time;
decision_result.pump_actual_state = pump_actual_state;
decision_result.actual_flow_m3s = actual_flow_m3s;
decision_result.actual_power_kw = actual_power_kw;
decision_result.actual_mode = pump_state_to_mode(pump_actual_state);
decision_result.requested_flow_m3s = request.requested_flow_m3s;
decision_result.requested_power_kw = request.requested_power_kw;
decision_result.tracking_error_m3s = ...
    actual_flow_m3s-request.requested_flow_m3s;
decision_result.power_tracking_error_kw = ...
    actual_power_kw-request.requested_power_kw;
decision_result.feasible = true;
decision_result.executor = 'ideal_three_pump_executor';

% Compatibility aliases for generic simulation consumers.
decision_result.u_actual = pump_actual_state;
decision_result.pump_status = pump_actual_state;
decision_result.power_kw = actual_power_kw;
decision_result.mode = decision_result.actual_mode;
end
