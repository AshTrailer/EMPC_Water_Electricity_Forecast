function demand_m3s = make_richmond_demand_series(config, n_steps)
%MAKE_RICHMOND_DEMAND_SERIES Repeat the 288-point daily demand profile.

validateattributes(n_steps, {'numeric'}, ...
    {'scalar', 'integer', 'nonnegative'});
daily_demand = config.water_demand_m3s(:);
expected_daily_steps = 24*60*60/config.dt_seconds;
if numel(daily_demand) ~= expected_daily_steps
    error('make_richmond_demand_series:DailyLength', ...
        'Daily demand has %d samples; expected %d.', ...
        numel(daily_demand), expected_daily_steps);
end
if n_steps == 0
    demand_m3s = zeros(0,1);
    return;
end
repeat_count = ceil(n_steps/numel(daily_demand));
demand_m3s = repmat(daily_demand, repeat_count, 1);
demand_m3s = demand_m3s(1:n_steps);
end
