function mpc_input = decision_to_mpc_input(decision_output, horizon_steps)
%DECISION_TO_MPC_INPUT 将 Decision 的上游数据整理成 MPC 的统一输入。
% 当前模拟数据和未来真实 Decision 输出都必须在这里转换成相同字段。
% 本接口只整理预测窗口，不负责选择具体水泵组合。

if ~isstruct(decision_output)
    error('decision_to_mpc_input:Type', ...
        'decision_output 必须是结构体。');
end
if ~isfield(decision_output, 'demand')
    error('decision_to_mpc_input:MissingDemand', ...
        '必须提供 decision_output.demand。');
end

mpc_input.demand = expand_signal(decision_output.demand, ...
    horizon_steps, 'demand');
if any(~isfinite(mpc_input.demand)) || any(mpc_input.demand < 0)
    error('decision_to_mpc_input:Demand', ...
        '用水需求必须是有限的非负数。');
end

if isfield(decision_output, 'level_ref')
    mpc_input.level_ref = expand_signal(decision_output.level_ref, ...
        horizon_steps, 'level_ref');
else
    error('decision_to_mpc_input:MissingReference', ...
        '基础 MPC 必须提供 decision_output.level_ref。');
end

if isfield(decision_output, 'time')
    mpc_input.time = expand_signal(decision_output.time, ...
        horizon_steps, 'time');
else
    mpc_input.time = (0:horizon_steps-1)';
end

if isfield(decision_output, 'price')
    mpc_input.price = expand_signal(decision_output.price, ...
        horizon_steps, 'price');
else
    mpc_input.price = nan(horizon_steps, 1);
end

if isfield(decision_output, 'source')
    mpc_input.source = decision_output.source;
else
    mpc_input.source = '未说明来源';
end
end

function value = expand_signal(value, horizon_steps, field_name)
value = value(:);
if isscalar(value)
    value = repmat(value, horizon_steps, 1);
elseif numel(value) < horizon_steps
    error('decision_to_mpc_input:ShortSignal', ...
        '%s 只有 %d 个样本，但 MPC 需要 %d 个样本。', ...
        field_name, numel(value), horizon_steps);
else
    value = value(1:horizon_steps);
end
end
