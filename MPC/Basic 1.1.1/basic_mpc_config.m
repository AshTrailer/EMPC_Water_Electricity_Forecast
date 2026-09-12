function config = basic_mpc_config()
%BASIC_MPC_CONFIG Basic 1.1.1 price-driven binary pump MPC parameters.

basic_root = fileparts(mfilename('fullpath'));

% Five-minute control intervals match the AEMO historical-price data.
config.dt_seconds = 300;
config.horizon_steps = 24*60/5;
config.default_simulation_steps = 24*60/5;

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

% Basic validation scenario: constant water demand, independent of AEMO's
% electrical TOTALDEMAND column.
config.water_demand_m3s = 0.025;

% This CSV is copied from origin/main after its Git blob was verified.
config.historical_price_file = fullfile(basic_root, 'data', ...
    'PRICE_AND_DEMAND_202602_VIC1.csv');
config.historical_region = "VIC1";
end
