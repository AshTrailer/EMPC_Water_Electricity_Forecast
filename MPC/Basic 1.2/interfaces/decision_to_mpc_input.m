function mpc_input = decision_to_mpc_input(decision_output, horizon_steps)
%DECISION_TO_MPC_INPUT Validate price and water-demand forecast windows.

if ~isstruct(decision_output)
    error('decision_to_mpc_input:Type', ...
        'decision_output must be a struct.');
end
required = {'demand', 'price'};
for k = 1:numel(required)
    if ~isfield(decision_output, required{k})
        error('decision_to_mpc_input:MissingField', ...
            'decision_output.%s is required.', required{k});
    end
end

mpc_input.demand = expand_signal(decision_output.demand, ...
    horizon_steps, 'demand');
mpc_input.price = expand_signal(decision_output.price, ...
    horizon_steps, 'price');
if any(~isfinite(mpc_input.demand)) || any(mpc_input.demand < 0)
    error('decision_to_mpc_input:Demand', ...
        'Water demand must be finite and nonnegative.');
end
if any(~isfinite(mpc_input.price))
    error('decision_to_mpc_input:Price', ...
        'Electricity price must be finite.');
end

if isfield(decision_output, 'time')
    mpc_input.time = expand_signal(decision_output.time, ...
        horizon_steps, 'time');
else
    mpc_input.time = (0:horizon_steps-1)';
end
if isfield(decision_output, 'source')
    mpc_input.source = decision_output.source;
else
    mpc_input.source = 'unspecified';
end
end

function value = expand_signal(value, horizon_steps, field_name)
value = value(:);
if isscalar(value)
    value = repmat(value, horizon_steps, 1);
elseif numel(value) < horizon_steps
    error('decision_to_mpc_input:ShortSignal', ...
        '%s has %d samples; MPC requires %d.', ...
        field_name, numel(value), horizon_steps);
else
    value = value(1:horizon_steps);
end
end
