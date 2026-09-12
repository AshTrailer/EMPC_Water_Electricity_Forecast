function decision_output = make_mock_decision_data(start_time, n_steps, mode, config)
%MAKE_MOCK_DECISION_DATA Deterministic synthetic data for unit tests.

if nargin < 1 || isempty(start_time)
    start_time = datetime(2026,2,1,0,5,0);
end
if nargin < 2 || isempty(n_steps)
    n_steps = 576;
end
if nargin < 3 || isempty(mode)
    mode = 'periodic';
end
if nargin < 4 || isempty(config)
    config = basic_mpc_config();
end

k = (0:n_steps-1)';
decision_output.time = start_time+seconds(config.dt_seconds*k);
decision_output.demand = config.water_demand_m3s*ones(n_steps,1);
switch lower(mode)
    case 'fixed'
        decision_output.price = 50*ones(n_steps,1);
    case 'periodic'
        decision_output.price = 60+40*sin(2*pi*k/288-pi/2);
    otherwise
        error('make_mock_decision_data:Mode', ...
            'mode must be fixed or periodic.');
end
decision_output.source = ['synthetic_', lower(mode)];
decision_output.interface_revision = 2;
end
