%% ============================================================
%  SMOKE_AXIS_REFACTOR  Call every function the 376-column refactor touched
%
%  checkcode does not catch an arguments block that disagrees with the function
%  signature; MATLAB only reports that when the function is entered. This script
%  therefore CALLS every touched function once with the new argument forms, on
%  synthetic data, so a mismatch costs five seconds instead of twenty minutes
%  inside a long atlas run.
%
%  Run: matlab -batch "run('...\smoke_axis_refactor.m')"
% ============================================================
clear; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(project_root, "MPC", "First_Version_MPC"));
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));
addpath(fullfile(predictor_root, "PriceClamp"));
addpath(fullfile(predictor_root, "Template_AR_predictor"));
addpath(fullfile(predictor_root, "ThetaY_Tracker"));
addpath(fullfile(predictor_root, "Anchor_AR_predictor"));
addpath(fullfile(predictor_root, "Level_Offset_predictor"));
addpath(fullfile(predictor_root, "Multi_Window_predictor"));
addpath(fullfile(predictor_root, "Kalman_predictor"));
addpath(fullfile(predictor_root, "EWMA_Template_predictor"));
addpath(fullfile(predictor_root, "Smoothing_predictor"));
addpath(fullfile(predictor_root, "Day_Class_predictor"));

n_s = 288;
[lead_min, h_all, band] = official_lead_axis();
n_h = numel(h_all);
n_step_max = max(h_all);
assert(n_h == 376 && n_step_max == 2196);
fprintf("axis %d columns, longest lead %d steps (%g h)\n", n_h, n_step_max, lead_min(end)/60);

n_day = 60;
rng(7);
price = 40 + 12*sin(2*pi*(1:n_day*n_s)'/n_s) + 3*randn(n_day*n_s, 1);
tt = datetime(2026,3,11,0,5,0) + minutes(5*(0:n_day*n_s-1)');

% ---- target_slots, scalar and vector -------------------------------------
u1 = target_slots(100, n_s, n_s);
u2 = target_slots(100, h_all, n_s);
assert(numel(u1) == 288 && numel(u2) == n_h);
assert(isequal(u1(1:11), u2(1:11)), 'target_slots: the vector form must match the scalar form on shared steps');
fprintf("target_slots  scalar 288, vector 376, first 11 identical\n");

% ---- every predictor that takes a horizon --------------------------------
st_lvl = init_level_offset(n_s, 28, 56);
[y, off] = predict_level_offset(st_lvl, 100, h_all, 40);
assert(numel(y) == n_h && numel(off) == n_h);

st_mw = init_multi_window(n_s, [7 28 56 112]);
[y2, t_mw] = predict_multi_window(st_mw, 100, h_all);
assert(numel(y2) == n_h && numel(t_mw) == n_s);

st_th = init_theta_tracker(n_s, 0.98, 100);
y3 = predict_theta_tracker(st_th, 100, h_all);
assert(numel(y3) == n_h);

st_ew = init_ewma_template(n_s, 0.15, 0.01);
y4 = predict_ewma_template(st_ew, 100, h_all);
assert(numel(y4) == n_h);

st_cl = init_day_class(n_s, 28);
y5 = predict_day_class(st_cl, 100, ones(n_h,1), h_all);
assert(numel(y5) == n_h);

st_sm = init_smoothing(12, "mean");
st_sm.S = 40;  st_sm.slope = 0.01;  st_sm.delay = 5.5;
y6 = predict_smoothing(st_sm, h_all, false);
y7 = predict_smoothing(st_sm, h_all, true);
assert(numel(y6) == n_h && numel(y7) == n_h);
fprintf("level_offset, multi_window, theta_y, ewma, day_class, smoothing: all %d long\n", n_h);

% ---- the Kalman basis table out to the longest lead ----------------------
mdl = build_harmonic_ss_model(price, tt, 3, 4);
G = kalman_basis_table(mdl, n_step_max);
assert(isequal(size(G), [n_s*n_step_max, mdl.nx]));
assert(all(isfinite(G(:))), 'kalman_basis_table: A^h produced a non-finite entry');
fprintf("kalman_basis_table %d x %d, all finite (A^%d stays bounded)\n", ...
   size(G,1), size(G,2), n_step_max);
xh = mdl.x0;
y8 = kalman_predict_atlas(xh, G, u2, h_all);
assert(numel(y8) == n_h && all(isfinite(y8)));

% ---- the direct multi-step refit at every lead ---------------------------
D = refit_dms(price, numel(price), 14*n_s, 4, h_all);
assert(isequal(size(D), [n_h, 5]));
% a long lead has far fewer usable rows than a short one but must still fit
assert(all(isfinite(D(:,1))), 'refit_dms: some lead produced no fit at all');
fprintf("refit_dms %d x 5, intercepts finite from lead %g to %g\n", ...
   size(D,1), lead_min(1), lead_min(end));

% ---- anchor-mix fit and predict at every lead ----------------------------
T_hist = repmat(price(1:n_s), 1, n_day+1);
d_col = repelem((1:n_day)', n_s);
dy_full = [0; diff(price)];
r_full = price - repmat(price(1:n_s), n_day, 1);
Da = fit_anchor_mix(price, dy_full, r_full, T_hist, d_col, numel(price), ...
   14*n_s, 4, false, 0, h_all);
assert(isequal(size(Da), [n_h, 11]));
% target template for every lead: the target slot of lead h, wrapped daily
T_tgt = T_hist(mod((0:n_h-1)', n_s) + 1, 1);
ya = predict_anchor_mix(Da, price(end), T_tgt, r_full(end-3:end), dy_full(end-3:end));
assert(numel(ya) == n_h);
fprintf("fit_anchor_mix %d x 11, predict %d long\n", size(Da,1), numel(ya));

% ---- the official composite axis and index -------------------------------
cfg = official_composite_load(fullfile(project_root, "AEMO_Data"));
[v, sr, ag, tgt, nm] = official_composite(datetime(2026,9,1,12,0,0), lead_min, cfg);
assert(numel(v) == n_h && numel(sr) == n_h && numel(ag) == n_h);
assert(all(sr(1:11) == 1), 'official_composite: the first eleven columns must be P5MIN');
assert(all(isfinite(tgt)));
fprintf("official_composite at 2026-09-01 12:00: %d values, %d P5MIN, %d PREDISPATCH, %d PD7DAY, %d absent\n", ...
   sum(isfinite(v)), sum(sr==1), sum(sr==2), sum(sr==3), sum(sr==0));

% ---- the origin loop's own indexing, on the 376 axis ---------------------
% On the 288-column axis n_h and n_s are both 288, so a mix-up between the two
% is invisible there. That is exactly what the regression run cannot catch, so
% the indexing shape is asserted here instead.
s0 = 137;
u0 = mod(s0 - 1 + h_all, n_s) + 1;
assert(numel(u0) == n_h, ...
   'the target slot vector is %d long but the axis has %d columns', numel(u0), n_h);
assert(all(u0 >= 1 & u0 <= n_s), 'a target slot fell outside 1..%d', n_s);
A_sel = ones(n_s, n_h);
cell_c = A_sel(sub2ind([n_s, n_h], u0, (1:n_h)'));
assert(numel(cell_c) == n_h);
Rc = rand(n_step_max, 3);
vc = Rc(sub2ind([n_step_max, 3], h_all, mod(cell_c, 3) + 1));
assert(numel(vc) == n_h && all(isfinite(vc)));
% and the same shape the atlas is written through
lin = u0 + n_s*(1:n_h)' + n_s*n_h*(3 - 1);
assert(numel(unique(lin)) == n_h && max(lin) <= n_s*n_h*60);
fprintf("origin-loop indexing: %d columns, atlas linear index fits\n", n_h);

fprintf("\n### SMOKE TEST PASSED ###\n");
