function decision_output = make_mock_decision_data(start_time, n_steps, mode)
%MAKE_MOCK_DECISION_DATA 生成固定或周期性的上游模拟数据。
% 这些数据模拟 Decision 提供给 MPC 的预测窗口，不包含水泵组合优化。

if nargin < 1 || isempty(start_time)
    start_time = datetime(2026, 2, 1, 0, 0, 0);
end
if nargin < 2 || isempty(n_steps)
    n_steps = 72;                                                          
end
if nargin < 3 || isempty(mode)
    mode = 'periodic';
end

k = (0:n_steps-1)';
decision_output.time = start_time + hours(k);

switch lower(mode)
    case 'fixed'
        decision_output.demand = 0.025 * ones(n_steps, 1);
        decision_output.level_ref = 2.30 * ones(n_steps, 1);
    case 'periodic'
        daily_phase = 2*pi*k/24;
        decision_output.demand = 0.025 ...
            + 0.010*sin(daily_phase - pi/2);
        decision_output.level_ref = 2.30 ...
            + 0.15*sin(daily_phase);
    otherwise
        error('make_mock_decision_data:Mode', ...
            'mode 必须是 ''fixed'' 或 ''periodic''。');
end

% 电价字段仅为未来经济目标预留，基础 MPC 暂时不使用
decision_output.price = nan(n_steps, 1);
decision_output.source = ['mock_', lower(mode)];
decision_output.interface_revision = 1;
end
