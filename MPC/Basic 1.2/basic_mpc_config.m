function config = basic_mpc_config()
%BASIC_MPC_CONFIG Basic 1.2 rolling binary-pump MPC parameters.

basic_root = fileparts(mfilename('fullpath'));

% Five-minute control intervals match the AEMO historical-price data.
config.dt_seconds = 300;
config.horizon_steps = 24*60/5;
config.default_simulation_steps = 24*60/5;
% The displayed day has zero negative-price intervals. Across the full
% 575-point input used by the 0-48 h figure, it also has the unique minimum
% negative-price count (one) among all eligible February start dates.
config.historical_start_day = datetime(2026,2,9);

% One tank and one fixed-flow pump.
config.tank_area_m2 = 1000;
config.level_min_m = 1.40;
config.level_max_m = 3.37;
config.level_initial_m = 2.30;
config.pump_flow_m3s = 0.050;
config.pump_power_kw = 46.0;
config.max_pumps = 1;

% Economic MPC setting. The switching cost is a tuning value in AUD per
% on/off transition. No additional terminal inventory target is imposed.
config.switch_cost_aud = 0.20;

% Richmond Pruned domestic demand pattern. The first value is for
% 00:00-01:00. Preserve the source values: their mean is 0.99625, not 1.
config.demand_multiplier_hourly = [ ...
    0.71, 0.48, 0.46, 0.40, 0.39, 0.41, ...
    0.52, 1.10, 1.61, 1.53, 1.40, 1.15, ...
    1.06, 1.04, 1.00, 0.92, 0.95, 1.16, ...
    1.34, 1.45, 1.32, 1.33, 1.11, 1.07];
config.demand_multiplier_5min = repelem( ...
    config.demand_multiplier_hourly, 12);
config.base_water_demand_m3s = 0.025;
config.water_demand_m3s = 0.025 .* config.demand_multiplier_5min;

% This CSV is copied from origin/main after its Git blob was verified.
config.historical_price_file = fullfile(basic_root, 'data', ...
    'PRICE_AND_DEMAND_202602_VIC1.csv');
config.historical_region = "VIC1";
end
