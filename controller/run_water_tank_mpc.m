%% ============================================================
%  RUN_WATER_TANK_MPC  Water tank MPC demo (QP-based, quadprog)
%
%  Setup:
%     - Constant nominal outflow d = 0.025 m^3/s + 5% Gaussian noise
%       (noise applied by WaterTankSystem.disturbance, replacing the
%       old time-varying Gaussian profile)
%     - MPC keeps the level inside 40%..90% of the usable range
%       [x_min, x_max], reference = 65%
%     - Inflow capacity u_max = 0.06 m^3/s >> outflow, so the pump
%       can always refill the tank (inflow capability exceeds demand)
%     - Step = 5 min, 288 steps = 24 h
%
%  Outputs:
%     Fig: level vs band, inflow vs outflow, net flow (3 panels)
%     Console: level statistics and band violation count
% ============================================================
clear; close all; clc;

project_root = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project";
addpath(project_root);
addpath(fullfile(project_root, "controller"));

cfg = system_config();
% constant outflow + small noise (5% of nominal value)
cfg.disturbance.enabled   = true;
cfg.disturbance.std_ratio = 0.05;
cfg.disturbance.seed      = 42;

tank = WaterTankSystem(cfg);

n_steps = 288;
dt = tank.dt;
q_out_base = 0.025;   % m^3/s constant nominal demand

% ---- MPC settings ----
band_lo = 0.40;
band_hi = 0.90;
ref_frac = 0.65;
mpc_cfg.n_horizon = 24;                        % 24 steps = 2 h look-ahead
mpc_cfg.area      = tank.S;
mpc_cfg.dt        = dt;
mpc_cfg.x_ref     = tank.x_min + ref_frac * (tank.x_max - tank.x_min);
mpc_cfg.x_lo      = tank.x_min + band_lo  * (tank.x_max - tank.x_min);
mpc_cfg.x_hi      = tank.x_min + band_hi  * (tank.x_max - tank.x_min);
mpc_cfg.u_max     = 0.06;         % pump capacity, must exceed outflow
mpc_cfg.u_ref     = q_out_base;   % steady-state inflow = nominal outflow
mpc_cfg.q_level   = 1.0;          % Q_x weight on level tracking
mpc_cfg.r_flow    = 50.0;         % R_u weight on inflow magnitude
mpc_cfg.rho_slack = 1e3;          % soft-constraint penalty

% ---- simulation ----
x_hist = zeros(n_steps + 1, 1);
x_hist(1) = tank.x; 
u_hist = zeros(n_steps, 1);
d_hist = zeros(n_steps, 1);
t_hours = (0:n_steps-1)' * dt / 3600;

for k = 1:n_steps
   u = mpc_water_tank(tank.x, q_out_base, mpc_cfg);
   [d_actual, x_new] = tank.step(u, q_out_base);
   u_hist(k) = u;
   d_hist(k) = d_actual;
   x_hist(k+1) = x_new;
end

%% ---------- figure ----------
figure('Name', 'Water tank MPC (QP)', 'Position', [100 100 1200 800]);

subplot(3,1,1);
plot(t_hours, x_hist(1:end-1), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Level');
hold on;
yline(mpc_cfg.x_lo,  'r--', '40% band', 'LineWidth', 1);
yline(mpc_cfg.x_hi,  'r--', '90% band', 'LineWidth', 1);
yline(mpc_cfg.x_ref, 'g--', 'reference 65%', 'LineWidth', 1);
ylabel('Level (m)');
title('Water level under MPC (band 40%-90%)');
legend('Location', 'best');
grid on;

subplot(3,1,2);
plot(t_hours, u_hist * 1000, 'b-', 'LineWidth', 1, 'DisplayName', 'Inflow (MPC)');
hold on;
plot(t_hours, d_hist * 1000, 'r-', 'LineWidth', 1, 'DisplayName', 'Outflow (demand + noise)');
yline(mpc_cfg.u_max * 1000, 'k--', 'pump capacity', 'LineWidth', 1);
ylabel('Flow (L/s)');
title('Inflow vs outflow');
legend('Location', 'best');
grid on;

subplot(3,1,3);
plot(t_hours, (u_hist - d_hist) * 1000, 'k-', 'LineWidth', 1, 'DisplayName', 'Net flow');
hold on;
yline(0, 'k-', 'HandleVisibility', 'off');
xlabel('Time (h)');
ylabel('Net flow (L/s)');
title('Net inflow (u - d)');
legend('Location', 'best');
grid on;

%% ---------- console summary ----------
frac = (x_hist(1:end-1) - tank.x_min) / (tank.x_max - tank.x_min);
fprintf("\n========== Water tank MPC summary ==========\n");
fprintf("Level: min %.2f m, max %.2f m (band [%.2f, %.2f] m)\n", ...
   min(x_hist), max(x_hist), mpc_cfg.x_lo, mpc_cfg.x_hi);
fprintf("Band violations: %d / %d steps\n", ...
   sum(frac < band_lo | frac > band_hi), n_steps);
fprintf("Mean inflow %.4f m^3/s vs mean outflow %.4f m^3/s\n", mean(u_hist), mean(d_hist));
fprintf("Final level %.3f m\n", tank.x);