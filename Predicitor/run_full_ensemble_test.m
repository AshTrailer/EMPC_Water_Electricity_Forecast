%% ============================================================
%  RUN_FULL_ENSEMBLE_TEST  All predictors side by side, then combinations
%
%  Part 1 builds one (slot x lead x day) error atlas per model, with the
%  protocol of run_predictor_suite.m, for every predictor that exists in the
%  Predicitor folder plus the two new ones.
%
%  Part 2 asks whether they can be stacked. Every combination tested here is
%  CONVEX, weights summing to one, which is the only case where the combined
%  error can be formed from the per-model error atlas alone:
%
%     f_c = sum_m w_m f_m   and   sum_m w_m = 1
%     =>  e_c = y - f_c = sum_m w_m (y - f_m) = sum_m w_m e_m
%
%  Combination weights are always fitted on a trailing window that ends
%  before the day being scored, so nothing looks ahead.
%
%  PROTOCOL
%    Data          AEMO_Data/PRICE_AND_DEMAND_*_VIC1.csv, 5-min RRP, NEM time
%    Warm-up       153 days immediately before the scored window
%    Targets       ATLAS_WINDOW, 60 days by default, 120 for the old atlas
%    Lead axis     ATLAS_LEAD_AXIS, 376 columns by default, 288 for the old
%    Price clamp   rolling 30-day global Q1/Q99, recomputed once per day
%    Scoring       one error sample per (target slot, lead, target day)
%
%  NOTATION
%    Local names follow section 2 of
%    Weekly/2026-10-13/HANDOVER_预测器整理与全跨度比较_20261013.md.
%       n_s    slots per day, 288
%       n_T    template window in days
%       n_q    clamp quantile window in days
%       n_d    scored days
%       n_fit  window of the daily direct multi-step refit, in days
%       n_lvl  window of the level recursion fit, in days
%       n_w    window of the combination weight fit, in days
%       W      multi-window set, {7 28 56 112}
%       T_tgt  T(u(k,h)), the template at the target slot
%       r_hat  residual forecast
%       y_now  y(k), the newest observation, also the anchor of M8
%       D_r / D_dy / D_anchor   direct multi-step coefficient matrices, row h
%       E4     the saved atlas, written E(s,h,d,m) in section 2
%       R      R(s,h,m), RMS over days, the object every claim is made about
%       Rall   Rbar(m), RMS over the whole of R, a run fingerprint only
%
%  MODEL ORDER comes from model_registry(), never from a written-out index.
% ============================================================
clear; close all; clc;

% M8 fits an unregularised least squares whose two anchors and lag columns are
% collinear, so it reports rank deficiency on every lead of every daily refit.
% That is a known property of the model, written up in the M8 section, and it
% would otherwise bury the run's own output under tens of thousands of lines.
warning('off', 'MATLAB:rankDeficientMatrix');

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

n_s = 288;  p = 4;  lam = 0.98;  delta = 100;  n_T = 28;
n_q = 30;  n_fit = 14;  W = [7 28 56 112];
n_lvl = 56;  n_w = 28;

% ---- run configuration ----------------------------------------------------
% Both the scored window and the lead axis are switchable so that the 120-day
% 288-column atlas stays reproducible and can be used as a regression check on
% any change made in this file. The defaults are the 60-day window on the full
% lead axis.
%    ATLAS_LEAD_AXIS   "376" (default) or "288"
%    ATLAS_WINDOW      "60d" (default) or "120d"
%    MODEL_EXCLUDE     comma-separated registry keys to leave out of the atlas
%    ATLAS_OUT         file name under AEMO_Data/level_multiwindow_figs
cfg_axis = string(getenv("ATLAS_LEAD_AXIS"));
if strlength(cfg_axis) == 0, cfg_axis = "376"; end
cfg_window = string(getenv("ATLAS_WINDOW"));
if strlength(cfg_window) == 0, cfg_window = "60d"; end

if cfg_axis == "376"
   % Columns 1 to 11 are 5 to 55 minutes at 5-minute cadence, which is the
   % whole forward horizon of a P5MIN run. Everything past that is 30-minute
   % cadence, so the axis stops being every step. h_all carries the step
   % numbers and the column number is a separate quantity.
   [lead_min, h_all] = official_lead_axis();
else
   assert(cfg_axis == "288", 'unknown ATLAS_LEAD_AXIS "%s"', cfg_axis);
   h_all = (1:n_s)';  lead_min = 5*h_all;
end
n_h = numel(h_all);
n_step_max = max(h_all);

if cfg_window == "60d"
   n_d = 60;
   train_start = datetime(2026,3,11,0,5,0);
   train_end   = datetime(2026,8,11,0,0,0);
else
   assert(cfg_window == "120d", 'unknown ATLAS_WINDOW "%s"', cfg_window);
   n_d = 120;
   train_start = datetime(2025,9,1,0,5,0);
   train_end   = datetime(2026,2,1,0,0,0);
end
test_start = train_end + minutes(5);
test_end   = train_end + days(n_d);

% M13 to M16 settings, sections 3 and 2.8 of the handover report
kf_harm = 3;  kf_ar = 4;             % harmonic pairs and residual AR order
alpha_e = 0.15;  min_w_e = 0.01;     % EWMA forgetting and truncation
w_smooth = 12;                       % smoothing window, 12 points = 1 hour

% Atlas output name. A verification run points ATLAS_OUT somewhere else so the
% incumbent atlas stays on disk to be compared against.
atlas_name = string(getenv("ATLAS_OUT"));
if strlength(atlas_name) == 0
   if cfg_window == "60d", atlas_name = "atlas_60d.mat";
   else, atlas_name = "atlas_full.mat"; end
end
aemo = load_aemo_data(fullfile(project_root, "AEMO_Data"));
t_all = aemo.time;  y_all = aemo.price;

tm = (t_all >= train_start) & (t_all <= train_end);
xm = (t_all >= test_start)  & (t_all <= test_end);
t_train = t_all(tm);  y_train = y_all(tm);
t_test  = t_all(xm);  y_test  = y_all(xm);
n_train = numel(y_train);  n_test = numel(y_test);
assert(n_train == 153*n_s, 'warm-up is not 153 whole days: %d', n_train);
assert(n_test == n_d*n_s, 'test window mismatch: %d', n_test);
t_seq = [t_train; t_test];  y_seq = [y_train; y_test];
n_seq = n_train + n_test;   slot_seq = get_slot_index(t_seq);
i_start = n_train + 1;
fprintf("warm-up %s .. %s (%d days) | targets %s .. %s (%d days)\n", ...
   t_seq(1), t_seq(n_train), n_train/n_s, t_test(1), t_test(end), n_d);

% ---- causal clamp thresholds, one pair per test day -----------------------
y_win0 = reshape(y_train(end - n_q*n_s + 1:end), n_s, n_q)';
cs = init_price_clamp(y_win0);
q_by_day = zeros(n_d,2); q_by_day(1,:) = cs.q;
for d = 1:n_d-1
   cs = update_price_clamp(cs, y_test((d-1)*n_s + (1:n_s))');
   q_by_day(d+1,:) = cs.q;
end
q1_seq = repelem(q_by_day(:,1), n_s);
q2_seq = repelem(q_by_day(:,2), n_s);
yc_seq = clamp_price(y_test, [q1_seq, q2_seq]);

% whole-stream clamp, needed by the anchor-mix fit whose rows and targets
% live in one index space
q1_all = zeros(n_seq,1);  q2_all = zeros(n_seq,1);
for gd = 1:ceil(n_seq/n_s)
   lo = max(1, (gd - n_q - 1)*n_s + 1);
   hi = min(n_seq, (gd-1)*n_s);
   win = y_seq(lo:hi);
   if isempty(win), win = y_seq(1); end
   thr = prctile(win, [1 99]);
   idx_day = (gd-1)*n_s + (1:n_s);
   idx_day = idx_day(idx_day <= n_seq);
   q1_all(idx_day) = thr(1);  q2_all(idx_day) = thr(2);
end
i_test0 = n_train + 1;
q1_all(i_test0:end) = q1_seq;  q2_all(i_test0:end) = q2_seq;
yc_all = clamp_price(y_seq, [q1_all, q2_all]);
dc_all = [0; diff(yc_all)];

% Model order and labels come from the registry, which is the single source of
% truth for atlas columns. Never index the atlas with a written-out number.
% Models are dropped by KEY, never by column number, and a key that the
% registry does not carry is an error rather than a silent no-op.
reg = model_registry();
keys = string({reg.key})';
n_reg = numel(keys);
cfg_exclude = string(getenv("MODEL_EXCLUDE"));
if strlength(cfg_exclude) == 0
   % The three 1-hour smoothers: past their own window they emit a constant, so
   % on a 183-hour axis they occupy a column without being a forecast. ar_adapt
   % is dropped for a different reason: its column is bit-identical to T28_ARn,
   % which is the same predictor under the name it should have had.
   cfg_exclude = "ma,ma_comp,med,ar_adapt";
end
drop = strtrim(split(cfg_exclude, ","));
drop = drop(strlength(drop) > 0);
missing = drop(~ismember(drop, keys));
assert(isempty(missing), 'run_full_ensemble_test:exclude', ...
   'MODEL_EXCLUDE names keys the registry does not carry: %s', strjoin(missing, ", "));
keep = ~ismember(keys, drop);
reg = reg(keep);  keys = keys(keep);
names = string({reg.name});
n_models = numel(reg);
fprintf("atlas columns, %d of %d: %s\n", n_models, n_reg, strjoin(names, " | "));
fprintf("excluded from the atlas: %s\n", strjoin(drop, ", "));
% Resolve a list of registry keys to column numbers of THIS atlas. Everything
% downstream that names models goes through this, so an exclusion cannot make a
% rule address a neighbouring column.
pick_cols = @(ks) arrayfun(@(k) col_of(keys, k), ks);
N2 = n_s*n_h;  N3 = N2*n_d;
E4 = zeros(n_s, n_h, n_d, n_models, 'single');

% ---- state ---------------------------------------------------------------
T_sum = zeros(n_s,1); T_cnt = zeros(n_s,1); T_win = zeros(n_s,n_T);
T_snap = zeros(n_s, n_d+1);
phi = zeros(p,1); Pphi = delta*eye(p); hist = zeros(p,1); nhist = 0;
y_prev = zeros(n_s,1);
st_theta = init_theta_tracker(n_s, lam, delta);
r_seq = nan(n_seq,1); d_seq = zeros(n_seq,1);
day_col = min(max(floor(((1:n_seq)' - n_train - 1)/n_s) + 2, 1), n_d+1);
D_r = zeros(n_h,p+1); D_dy = zeros(n_h,p+1); D_anchor = zeros(n_h,2*p+3);
D_anchor_sum = zeros(n_h,2*p+3); D_anchor_n = 0;
st_lvl  = init_level_offset(n_s, n_T, n_lvl);
st_lvl2 = init_level_offset(n_s, n_T, n_lvl, true);
st_mw   = init_multi_window(n_s, W);

% ---- state of M13 to M16 --------------------------------------------------
% The Kalman model is trained once on the warm-up and its filter is warmed
% there, so xi_kf/Pk_kf enter the test window already at the right state. The
% basis table is origin independent and is built once.
kf_model = build_harmonic_ss_model(y_train, t_train, kf_harm, kf_ar);
kf_G = kalman_basis_table(kf_model, n_step_max);
xi_kf = kf_model.x0;  Pk_kf = kf_model.P0;

st_ewma  = init_ewma_template(n_s, alpha_e, min_w_e);
st_ma    = init_smoothing(w_smooth, "mean");
st_med   = init_smoothing(w_smooth, "median");
st_class = init_day_class(n_s, n_T);

% target-day class, 1 = weekday and 2 = weekend, by NEM time. The calendar is
% extended past the end of the scoring window rather than clamped to the last
% sample, because the longest lead reaches well beyond it and clamping would
% read the class of a day that has not happened yet.
t_ext = [t_seq; t_seq(end) + minutes(5*(1:n_step_max))'];
cls_ext = 1 + double(isweekend(t_ext));

% ---- state of M19, one RLS state per candidate AR order -------------------
% The order sweep says the best order falls with the lead, so the order is
% chosen per lead. Choosing it once on the whole test window would be fitting
% on the test set, so the choice is made causally: each day picks, for every
% lead, the order with the smallest squared error over the trailing window of
% complete days. The candidate forecast for lead h is the iterated AR(p)
% forecast started from the newest p residuals, which the whole 288-vector
% form gives in one filter call per candidate.
P_set = [1 2 3 4 5 6 8];
n_cand = numel(P_set);
p_max = max(P_set);
r_hist = zeros(p_max, 1);  r_hist_n = 0;
phi_c = zeros(p_max, n_cand);
P_c = cell(1, n_cand);
for c = 1:n_cand, P_c{c} = delta*eye(P_set(c)); end
% Squared error accumulated by (target slot, lead, target day, order). The order
% belongs to a cell, not to a lead: a cell is a forecast issued at one time of
% day for one lead, and the best order depends on both. Accumulating by slot
% alone chooses an order for a cell the fit never saw.
ss_sl = zeros(n_s, n_h, n_d, n_cand, 'single');
ar_sel = ones(n_s, n_h);              % chosen candidate per (slot, lead) cell
ar_sel_hist = zeros(n_s, n_h, n_cand);% how often each order was chosen
W_last = [];                          % the accumulated criterion at the last pick
fprintf("M19 candidate AR orders %s\n", mat2str(P_set));

% Two identities are measured, not assumed, because every statement made about
% the order selection downstream depends on them:
%   1. the p = 4 candidate IS M4, so "T28 + AR(4)" really is a member of the
%      family the selection searches over;
%   2. the M19 column and the M20 column are the same forecast, so the atlas
%      may hold exactly one of them without losing anything.
m4_col = find(keys == "T28_AR4", 1);
c4 = find(P_set == 4, 1);
i19 = find(keys == "ar_adapt", 1);
i20 = find(keys == "T28_ARn", 1);
gap_m4 = 0;        % on the scored, clamped values: this one is asserted
gap_m4_raw = 0;    % on the raw recursions: measured and reported, not asserted
n_blow = 0;        % origins where the p=4 recursion runs away
i_blow = 0;
gap_dup = 0;

% ================= warm-up =================
for idx = 1:n_train
   s = slot_seq(idx);  yv = y_seq(idx);
   if T_cnt(s) == 0
      T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
   else
      r = yv - T_sum(s)/T_cnt(s);
      if idx > 1, d_seq(idx) = yv - y_seq(idx-1); end
      if nhist >= p
         [phi, Pphi] = rls_vector_step(r, hist, phi, Pphi, lam);
      end
      r_seq(idx) = r;
      hist = [r; hist(1:end-1)];  nhist = min(nhist+1, p);
      % Candidate fits take the regressor as it stood before this residual was
      % pushed in, the same way the main phi update above does. Updating r_hist
      % first regresses r(k) on a vector whose first entry is r(k) itself, which
      % drives every candidate to phi = [1; 0; ...] and makes all of them emit
      % the same forecast, so the selection ties and min returns the first index.
      for c = 1:n_cand
         pc = P_set(c);
         if r_hist_n >= pc
            [phi_c(1:pc,c), P_c{c}] = rls_vector_step(r, r_hist(1:pc), ...
               phi_c(1:pc,c), P_c{c}, lam);
         end
      end
      r_hist = [r; r_hist(1:end-1)];  r_hist_n = min(r_hist_n+1, p_max);
      col = mod(T_cnt(s), n_T)+1;
      T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
      T_cnt(s) = min(T_cnt(s)+1, n_T);
   end
   st_theta = update_theta_tracker(st_theta, s, yv);
   st_lvl  = update_level_offset(st_lvl, s, yv);
   st_lvl2 = update_level_offset(st_lvl2, s, yv);
   st_mw   = update_multi_window(st_mw, s, yv);
   y_prev(s) = yv;
   % the Kalman filter is deliberately absent here: build_harmonic_ss_model
   % already streamed this same warm-up, so xi_kf/Pk_kf are past it
   st_ewma  = update_ewma_template(st_ewma, s, yv);
   st_ma    = update_smoothing(st_ma, yv);
   st_med   = update_smoothing(st_med, yv);
   st_class = update_day_class(st_class, s, yv, cls_ext(idx) == 2);
end
fprintf("warm-up streamed %d points | level refits %d c %.2f b1 %.3f\n", ...
   n_train, st_lvl.n_refit, st_lvl.c, st_lvl.b1);

% ================= origin loop =================
for idx = i_start:n_seq
   s = slot_seq(idx);
   u = mod(s - 1 + h_all, n_s) + 1;
   % One column per lead, always. On the 288-column axis n_h and n_s are both
   % 288, so anything that confuses the two is invisible there and only shows up
   % here. The regression run cannot catch that class of mistake.
   assert(numel(u) == n_h, 'run_full_ensemble_test:axis', ...
      'the target slot vector is %d long but the lead axis has %d columns', numel(u), n_h);

   tj = idx + h_all;  jtest_all = tj - n_train;
   valid = (jtest_all >= 1) & (jtest_all <= n_test);
   % hv are the COLUMN numbers of the leads that land inside the scoring
   % window. That is not the same as h_all once the axis skips steps: h_all
   % holds step numbers, hv holds positions on the axis, and the atlas is
   % indexed by position.
   hv = find(valid);
   h_used = h_all(hv);
   jtest = jtest_all(hv);
   d_tgt = floor((jtest-1)/n_s) + 1;
   q1 = q1_seq(jtest);  q2 = q2_seq(jtest);  y_c = yc_seq(jtest);
   lin = u(hv) + n_s*(hv-1) + N2*(d_tgt-1);

   % ---- ingest y(idx) ----
   yv = y_seq(idx);
   yp_fc = y_prev;
   if T_cnt(s) == 0
      T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
   else
      r = yv - T_sum(s)/T_cnt(s);
      d_seq(idx) = yv - y_seq(idx-1);
      if nhist >= p
         [phi, Pphi] = rls_vector_step(r, hist, phi, Pphi, lam);
      end
      r_seq(idx) = r;
      hist = [r; hist(1:end-1)];  nhist = min(nhist+1, p);
      % Candidate fits take the regressor as it stood before this residual was
      % pushed in, the same way the main phi update above does. Updating r_hist
      % first regresses r(k) on a vector whose first entry is r(k) itself, which
      % drives every candidate to phi = [1; 0; ...] and makes all of them emit
      % the same forecast, so the selection ties and min returns the first index.
      for c = 1:n_cand
         pc = P_set(c);
         if r_hist_n >= pc
            [phi_c(1:pc,c), P_c{c}] = rls_vector_step(r, r_hist(1:pc), ...
               phi_c(1:pc,c), P_c{c}, lam);
         end
      end
      r_hist = [r; r_hist(1:end-1)];  r_hist_n = min(r_hist_n+1, p_max);
      col = mod(T_cnt(s), n_T)+1;
      T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
      T_cnt(s) = min(T_cnt(s)+1, n_T);
   end
   st_theta = update_theta_tracker(st_theta, s, yv);
   st_lvl  = update_level_offset(st_lvl, s, yv);
   st_lvl2 = update_level_offset(st_lvl2, s, yv);
   st_mw   = update_multi_window(st_mw, s, yv);
   [xi_kf, Pk_kf] = kalman_filter_step(xi_kf, Pk_kf, yv, s, kf_model);
   st_ewma  = update_ewma_template(st_ewma, s, yv);
   st_ma    = update_smoothing(st_ma, yv);
   st_med   = update_smoothing(st_med, yv);
   st_class = update_day_class(st_class, s, yv, cls_ext(idx) == 2);
   y_prev(s) = yv;

   if s == 1 && idx > i_start && nhist >= p
      T_snap(:, day_col(idx)) = T_sum ./ max(T_cnt,1);      D_r = refit_dms(r_seq, idx, n_fit*n_s, p, h_all);
      D_dy = refit_dms(d_seq, idx, n_fit*n_s, p, h_all);
      D_anchor = fit_anchor_mix(yc_all, dc_all, r_seq, T_snap, day_col, ...
                           idx, n_fit*n_s, p, false, 0, h_all);
      D_anchor_sum = D_anchor_sum + D_anchor;  D_anchor_n = D_anchor_n + 1;

      % M19: re-choose the AR order per (slot, lead) cell from complete trailing
      % days only. Every cell of target day d comes from an origin inside days
      % d-1 and d, so day d is complete once the first origin of day d+1 starts.
      d_now = day_col(idx) - 1;
      hi_sel = d_now;
      lo_sel = max(1, d_now - n_T + 1);
      if hi_sel >= lo_sel && (hi_sel - lo_sel + 1) >= 7
         W_ss = squeeze(sum(ss_sl(:, :, lo_sel:hi_sel, :), 3)); % n_s x n_h x n_cand
         [~, ar_sel] = min(W_ss, [], 3);
         W_last = W_ss;                    % kept so the selection can be audited
         for c = 1:n_cand
            ar_sel_hist(:, :, c) = ar_sel_hist(:, :, c) + (ar_sel == c);
         end
      end
   end

   % ---- forecast, ingest-first ----
   T_tgt = T_sum(u) ./ max(T_cnt(u),1);
   % The AR recursion advances one 5-minute step at a time, so it has to run to
   % the longest lead on the axis and the wanted leads are picked out afterwards.
   % Running only n_h steps would silently return the wrong lead once the axis
   % skips steps past the first hour.
   r_hat = zeros(n_h, 1);
   if nhist >= p
      buf = hist;
      r_full = zeros(n_step_max, 1);
      for k = 1:n_step_max
         v = phi'*buf;  r_full(k) = v;  buf = [v; buf(1:end-1)];
      end
      r_hat = r_full(h_all);
   end
   y_now = yv;
   y_hat_anchor = predict_anchor_mix(D_anchor, y_now, T_tgt, hist, d_seq(idx:-1:idx-p+1));
   [y_hat_lvl, ~]   = predict_level_offset(st_lvl, s, h_all, mean(T_tgt));
   [y_hat_mw, T_mw] = predict_multi_window(st_mw, s, h_all);
   [~, off_lvl]     = predict_level_offset(st_lvl, s, h_all, mean(T_mw));
   [~, off_run]     = predict_level_offset(st_lvl2, s, h_all, mean(T_mw));
   y_hat_kf   = kalman_predict_atlas(xi_kf, kf_G, u, h_all);
   y_hat_ewma = predict_ewma_template(st_ewma, s, h_all);
   y_hat_ma   = predict_smoothing(st_ma, h_all, false);
   y_hat_mac  = predict_smoothing(st_ma, h_all, true);
   y_hat_med  = predict_smoothing(st_med, h_all, false);
   y_hat_cls  = predict_day_class(st_class, s, cls_ext(idx + h_all), h_all);

   % M19: one iterated AR(p) forecast per candidate order, then pick per cell.
   % Column i of R_cand is lead h_all(i), so the order used for a lead is the
   % one selected for the cell (u(i), i) that lead actually lands on.
   R_cand = zeros(n_step_max, n_cand);
   for c = 1:n_cand
      pc = P_set(c);
      if r_hist_n >= pc
         a_c = [1; -phi_c(1:pc, c)];
         R_cand(:, c) = filter(1, a_c, zeros(n_step_max,1), filtic(1, a_c, r_hist(1:pc)));
      end
   end
   cell_c = ar_sel(sub2ind([n_s, n_h], u, (1:n_h)'));
   r_hat_adapt = R_cand(sub2ind([n_step_max, n_cand], h_all, cell_c));
   y_hat_adapt = T_tgt + r_hat_adapt;

   % One case per registry key, in atlas column order. A registry entry with no
   % rule falls through to the error instead of silently scoring zeros.
   F = zeros(n_h, n_models);
   for m = 1:n_models
      switch reg(m).key
         case "persistence",   F(:,m) = yp_fc(u);
         case "T28",           F(:,m) = T_tgt;
         case "theta_y",       F(:,m) = predict_theta_tracker(st_theta, s, h_all);
         case "T28_AR4",       F(:,m) = T_tgt + r_hat;
         case "carry_forward", F(:,m) = repmat(y_now, n_h, 1);
         case "T28_DMS4",      F(:,m) = T_tgt + D_r*[1; hist];
         case "CF_DMS4",       F(:,m) = y_now + D_dy*[1; d_seq(idx:-1:idx-p+1)];
         case "anchor_mix",    F(:,m) = y_hat_anchor;
         case "T28_level",     F(:,m) = y_hat_lvl;
         case "MW",            F(:,m) = y_hat_mw;
         case "MW_level",      F(:,m) = y_hat_mw + off_lvl;
         case "MW_run",        F(:,m) = y_hat_mw + off_run;
         case "kalman_harm",   F(:,m) = y_hat_kf;
         case "T_ewma",        F(:,m) = y_hat_ewma;
         case "ma",            F(:,m) = y_hat_ma;
         case "ma_comp",       F(:,m) = y_hat_mac;
         case "med",           F(:,m) = y_hat_med;
         case "T_class",       F(:,m) = y_hat_cls;
         case "ar_adapt",      F(:,m) = y_hat_adapt;
         case "T28_ARn",       F(:,m) = y_hat_adapt;
         otherwise
            error("run_full_ensemble_test:no_rule", ...
               "model_registry lists ""%s"" but this script has no forecast rule for it", ...
               reg(m).key);
      end
   end

   if ~isempty(m4_col)
      % Two recursions are being compared: M4 advances the AR by an explicit loop
      % and the candidate does the same thing with one filter() call. They agree
      % to the last bits while the RLS residual model is stable. Once it is not,
      % both run away and they then round differently, so the raw outputs can
      % differ by hundreds of orders of magnitude. Nothing downstream sees that,
      % because the forecast is clamped before it is scored and both saturate on
      % the same threshold. So the RAW gap is measured and reported, and the gap
      % on the SCORED clamped values is what is asserted.
      % R_cand is indexed by STEP, not by column, so the lead axis picks the rows.
      gap_m4_raw = max(gap_m4_raw, max(abs((T_tgt + R_cand(h_all,c4)) - F(:,m4_col))));
      if ~isempty(hv)
         gap_m4 = max(gap_m4, max(abs( ...
            clamp_price(T_tgt(hv) + R_cand(h_all(hv),c4), [q1, q2]) - ...
            clamp_price(F(hv,m4_col), [q1, q2]))));
      end
      if max(abs(R_cand(:,c4))) > 1e6
         n_blow = n_blow + 1;
         if i_blow == 0, i_blow = idx; end
      end
   end
   if ~isempty(i19) && ~isempty(i20)
      gap_dup = max(gap_dup, max(abs(F(:,i19) - F(:,i20))));
   end

   if ~isempty(hv)
      for m = 1:size(F,2)
         E4(lin + (m-1)*N3) = y_c - clamp_price(F(hv,m), [q1, q2]);
      end
      % M19 bookkeeping: every candidate's squared error at (slot, lead, day)
      base_ss = u(hv) + n_s*(hv-1) + N2*(d_tgt-1);
      for c = 1:n_cand
         e2 = (y_c - clamp_price(T_tgt(hv) + R_cand(hv,c), [q1, q2])).^2;
         idx_ss = base_ss + N3*(c-1);
         ss_sl(idx_ss) = ss_sl(idx_ss) + single(e2);
      end
   end
end
fprintf("atlas built: %s (%.0f MB)\n", mat2str(size(E4)), numel(E4)*4/1048576);

% ---- identity checks ------------------------------------------------------
fprintf("\nidentity checks over every origin of the window\n");
if ~isempty(m4_col)
   fprintf("  p=%d candidate against %s, scored clamped values: %.3g $/MWh\n", ...
      P_set(c4), names(m4_col), gap_m4);
   fprintf("  p=%d candidate against %s, raw recursions      : %.3g $/MWh\n", ...
      P_set(c4), names(m4_col), gap_m4_raw);
   fprintf("  origins where the p=%d recursion passes 1e6    : %d of %d", ...
      P_set(c4), n_blow, n_seq - i_start + 1);
   if i_blow > 0, fprintf(", first at stream index %d", i_blow); end
   fprintf("\n");
   assert(gap_m4 < 1e-9, 'run_full_ensemble_test:identity_m4', ...
      'the p=%d candidate and %s differ by %.3g on the scored values, so the selection does not search over M4', ...
      P_set(c4), names(m4_col), gap_m4);
end
if ~isempty(i19) && ~isempty(i20)
   fprintf("  %s against %s: %.3g $/MWh\n", names(i19), names(i20), gap_dup);
   assert(gap_dup < 1e-9, 'run_full_ensemble_test:identity_dup', ...
      '%s and %s differ by %.3g, so excluding one of them would lose information', ...
      names(i19), names(i20), gap_dup);
end

% Every entry has to be finite. A clamped forecast cannot be infinite, because
% min(max(x, q1), q2) is finite for any finite threshold, but NaN slips through
% min and max untouched and would poison a whole cell silently.
nf = sum(~isfinite(E4(:)));
fprintf("atlas entries that are not finite: %d of %d\n", nf, numel(E4));
assert(nf == 0, 'run_full_ensemble_test:nonfinite', ...
   '%d of %d atlas entries are not finite', nf, numel(E4));

% ---- probe leads, shared by the M19 audit and PART 1 -----------------------
% Everything below names a lead in MINUTES and resolves it to a column here, so
% nothing downstream carries a hard-coded column number.
probe_min = [5 30 60 180 360 720 1440];
probe_lab = {'5min','30min','1h','3h','6h','12h','24h'};
if n_h > 288
   probe_min = [probe_min 4380 10980];
   probe_lab = [probe_lab {'3d','7.6d'}];
end
h_show = zeros(1, numel(probe_min));
for j = 1:numel(probe_min)
   k = find(lead_min == probe_min(j), 1);
   assert(~isempty(k), 'run_full_ensemble_test:probe', ...
      'no column at lead %g minutes on this axis', probe_min(j));
   h_show(j) = k;
end
h_lab = probe_lab;

% ---- M19 diagnostic: which order the causal rule kept, by lead ----
fprintf("\nM19 order chosen per cell, share of the 288 slots over the selection days:\n");
fprintf("  lead  ");
for c = 1:n_cand, fprintf("%8s", "p=" + string(P_set(c))); end
fprintf("\n");
for k = h_show
   row = squeeze(sum(ar_sel_hist(:, k, :), 1));
   row = row / max(sum(row), 1);
   fprintf("  %4s  ", h_lab{find(h_show == k, 1)});
   for c = 1:n_cand, fprintf("%7.1f%%", 100*row(c)); end
   fprintf("\n");
end
fprintf("cells per order over all %d cells of the last selection:\n", n_s*n_h);
for c = 1:n_cand
   fprintf("  p=%-3d %6d cells (%.1f%%)\n", P_set(c), sum(ar_sel(:) == c), ...
      100*sum(ar_sel(:) == c)/(n_s*n_h));
end

% If the candidates are indistinguishable the choice is not a choice, so the
% spread of the criterion across candidates is reported rather than assumed.
if ~isempty(W_last)
   Wd = double(W_last);
   spread = (max(Wd, [], 3) - min(Wd, [], 3)) ./ max(min(Wd, [], 3), eps);
   fprintf("\nM19 audit of the last selection, candidate set %s\n", mat2str(P_set));
   fprintf("  cells where every candidate is identical to the last bit: %d of %d\n", ...
      sum(spread(:) == 0), n_s*n_h);
   fprintf("  relative gap between best and worst candidate: median %.5g, 90th %.5g\n", ...
      median(spread(:)), prctile(spread(:), 90));
   fprintf("  cells where the best beats the second best by under 1 percent: %d\n", ...
      sum(spread(:) < 0.01));
end
clear ss_sl

%% ---------- PART 1: individual models ----------
win_txt = sprintf("%s .. %s (%d days)", datestr(t_test(1),'yyyy-mm-dd'), ...
   datestr(t_test(end),'yyyy-mm-dd'), n_d);
gR = @(x) sqrt(mean(x(:).^2));

fprintf("\n================ PART 1  individual models ================\n");
fprintf("data %s | clamped | ingest-first | unit $/MWh\n", win_txt);

% R(slot, lead, model) is the object every statement below is made about: the
% RMS over the scored days at one time of day and one lead. A single number
% taken over the whole of R is printed at the end as a run fingerprint only.
R = zeros(n_s, n_h, n_models);
for m = 1:n_models
   R(:, :, m) = sqrt(mean(double(E4(:, :, :, m)).^2, 3));
end
Rall = zeros(n_models,1);

for k = 1:numel(h_show)
   fprintf("\n--- lead %s (%g min): R over the 288 times of day ---\n", ...
      h_lab{k}, lead_min(h_show(k)));
   fprintf("%-24s %9s %9s %9s %9s\n", "model", "min", "median", "max", "max/min");
   v = squeeze(R(:, h_show(k), :));
   for m = 1:n_models
      col = v(:, m);
      fprintf("%-24s %9.2f %9.2f %9.2f %9.2f\n", names(m), ...
         min(col), median(col), max(col), max(col)/min(col));
   end
   [~, wi] = min(v, [], 2);
   fprintf("  winner by time of day:");
   for m = 1:n_models
      n = sum(wi == m);
      if n > 0, fprintf("  %s %d", names(m), n); end
   end
   fprintf("\n");
end

fprintf("\n--- cells won out of the %d (time of day, lead) cells of R ---\n", n_s*n_h);
[~, wcell] = min(R, [], 3);
win_cells = zeros(n_models,1);
for m = 1:n_models
   win_cells(m) = sum(sum(wcell == m));
end
[~, ord_w] = sort(win_cells, "descend");
for m = ord_w'
   fprintf("  %-24s %6d cells %6.1f%%\n", names(m), win_cells(m), ...
      100*win_cells(m)/(n_s*n_h));
end

fprintf("\nfingerprint only, NOT a ranking basis, RMS over the whole of R:\n");
for m = 1:n_models
   Rall(m) = gR(double(E4(:,:,:,m)));
   fprintf("  %-24s %8.2f\n", names(m), Rall(m));
end
fprintf("clamped signal std %.2f $/MWh\n", std(yc_seq));

% save the atlas straight away so a failure in the combination part below
% does not throw away ten minutes of streaming
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
if ~exist(fig_dir, "dir"), mkdir(fig_dir); end
if ~isempty(W_last), M19_W = single(W_last); else, M19_W = single([]); end
save(fullfile(fig_dir, atlas_name), "E4", "names", "keys", "R", "Rall", ...
   "win_cells", "ar_sel", "ar_sel_hist", "P_set", "M19_W", ...
   "lead_min", "h_all", "n_h", "n_d", "n_w", "cfg_axis", "cfg_window", ...
   "t_test", "-v7.3");
fprintf("\natlas saved to %s\n", fullfile(fig_dir, atlas_name));

%% ---------- PART 2: convex combinations ----------
% Any convex combination can be scored straight from the error atlas:
%   f_c = sum_m w_m f_m with sum_m w_m = 1  =>  e_c = sum_m w_m e_m
% Weights are always fitted on a trailing window that ends before the scored
% day. Fitting per individual lead would need one 12x12 covariance solve per
% (lead, day), so weights are fitted per lead block instead.
% Lead groups for the per-group weight fits. The 376-column axis is not a
% multiple of the old 4-hour block, and a fixed number of columns would put
% very different lead ranges in one group in any case, so the groups are lead
% bands that double in width. The 288-column axis keeps the old 4-hour blocks
% so that the two atlases stay comparable block for block.
if n_h == 376
   band_edges = [5 55; 60 240; 270 720; 750 1440; 1470 2880; 2910 5760; 5790 10980];
   lead_sets = cell(1, size(band_edges,1));
   for b = 1:size(band_edges,1)
      lead_sets{b} = find(lead_min >= band_edges(b,1) & lead_min <= band_edges(b,2));
      assert(~isempty(lead_sets{b}), 'run_full_ensemble_test:band', ...
         'lead band %d from %g to %g minutes is empty', ...
         b, band_edges(b,1), band_edges(b,2));
   end
   n_blk = numel(lead_sets);
   band_label = "lead bands";
   fprintf("\n================ PART 2  combinations ================\n");
   fprintf("weight window %d days, %d lead bands:\n", n_w, n_blk);
   for b = 1:n_blk
      fprintf("  band %d  %6g to %7g min  %6.2f to %7.2f h  %3d columns\n", ...
         b, lead_min(lead_sets{b}(1)), lead_min(lead_sets{b}(end)), ...
         lead_min(lead_sets{b}(1))/60, lead_min(lead_sets{b}(end))/60, ...
         numel(lead_sets{b}));
   end
else
   blk = 48;  n_blk = n_s / blk;
   lead_sets = arrayfun(@(b) (b*blk + 1):((b+1)*blk), 0:n_blk-1, 'UniformOutput', false);
   band_label = "4h blocks";
   fprintf("\n================ PART 2  combinations ================\n");
   fprintf("weight window %d days, lead blocks of %d (%d blocks)\n", n_w, blk, n_blk);
end

comb_name = {};  comb_all = [];  comb_surf = {};
% Every rule is scored on the same days. A causal rule cannot fill the first
% n_w days, so averaging over the raw 120-day array counts those zeros and
% understates it by sqrt(92/120) = 0.8756, while a rule that fills every day is
% not diluted. Both the scalar and the surface are restricted to d_score.
d_score = (n_w+1):n_d;
surf_of = @(Ec) sqrt(mean(Ec(:, :, d_score).^2, 3));
combR = @(Ec) sqrt(mean(reshape(double(Ec(:, :, d_score)), [], 1).^2));

% ---- 1. fixed equal weights over chosen subsets ----
% Model sets are named by KEY through col_of, never by a number and never
% through model_index: model_index resolves against the WHOLE registry, while
% the atlas holds only the columns that survived MODEL_EXCLUDE, so its numbers
% would address the wrong columns the moment anything is excluded.
subsets = { "ALL",       1:n_models; ...
            "CHAMPS2 (anchor, MWrun)",          pick_cols(["anchor_mix" "MW_run"]); ...
            "CHAMPS3 (anchor, MWrun, T28+DMS4)", pick_cols(["anchor_mix" "MW_run" "T28_DMS4"]); ...
            "GOOD5 (AR4,DMS4,anchor,MW,MWrun)", pick_cols(["T28_AR4" "T28_DMS4" "anchor_mix" "MW" "MW_run"]); ...
            "SHORTLONG (AR4,MWrun)",            pick_cols(["T28_AR4" "MW_run"]); ...
            "TEMPLATES (T28,MW,MWrun)",         pick_cols(["T28" "MW" "MW_run"]) };
for si = 1:size(subsets,1)
   sub = subsets{si,2};
   Ec = zeros(n_s, n_h, n_d, 'single');
   for m = sub
      Ec = Ec + single(double(E4(:,:,:,m)) / numel(sub));
   end
   comb_name{end+1} = "equal " + subsets{si,1};
   comb_all(end+1) = combR(Ec);  comb_surf{end+1} = surf_of(Ec);
   clear Ec
end

% ---- 2. causal best-k equal, chosen per lead from the trailing window ----
% Mrr(lead, day, model) = RMSE over the 288 slots of that day
Mrr = zeros(n_h, n_d, n_models);
for m = 1:n_models
   Mrr(:,:,m) = squeeze(sqrt(mean(double(E4(:,:,:,m)).^2, 1)));   % lead x day
end
for kbest = [3 5]
   Ec = zeros(n_s, n_h, n_d, 'single');
   for h = 1:n_h
      tr = squeeze(Mrr(h, :, :));                                 % day x model
      trs = filter(ones(n_w,1)/n_w, 1, tr, [], 1);      % trailing mean
      for d = n_w+1:n_d
         % trs(d, :) averages days d-n_w+1 .. d and includes the day being
         % scored, so the choice is taken at d-1.
         [~, ord] = sort(trs(d-1,:));
         sel = ord(1:kbest);
         Ec(:,h,d) = single(sum(double(E4(:,h,d,sel)), 4) / kbest);
      end
   end
   comb_name{end+1} = sprintf("causal best-%d equal", kbest);
   comb_all(end+1) = combR(Ec);  comb_surf{end+1} = surf_of(Ec);
   clear Ec
end
clear Mrr

% ---- 3. causal optimal weights, whole atlas and per lead block ----
% Bates-Granger: w proportional to the inverse of the error covariance. The
% covariance is fitted on a subsample of the cells in the lead set but the
% resulting weights are APPLIED TO EVERY LEAD in that set; writing only the
% fitted cells leaves the rest at zero and reports a pooled RMSE that no
% predictor ever achieved. Shrinkage pulls the covariance toward its diagonal.
% This block must reproduce run_ensemble_combos.m block 3 digit for digit.
sub_slots = 1:6:n_s;
for shrink = [0.0 0.3]
   for spec = 1:2
      if spec == 1
         lead_groups = {1:n_h};
         label = "optimal weights, whole atlas";
      else
         lead_groups = lead_sets;
         label = "optimal weights, " + band_label;
      end
      if shrink > 0
         label = label + sprintf(" (shrink %.1f)", shrink);
      end
      Ec = zeros(n_s, n_h, n_d, 'single');
      for ls = 1:numel(lead_groups)
         leads_out = lead_groups{ls};
         leads_fit = leads_out(1:6:end);          % subsample within this lead set
         for d = n_w+1:n_d
            past = double(E4(sub_slots, leads_fit, d-n_w:d-1, :));
            X = reshape(past, [], n_models);
            S = (X' * X) / size(X,1);
            S = (1-shrink)*S + shrink*(trace(S)/n_models)*eye(n_models);
            w = S \ ones(n_models,1);  w = w / sum(w);
            blk4 = squeeze(double(E4(:, leads_out, d, :)));       % slot x lead x model
            Ec(:, leads_out, d) = single(reshape(reshape(blk4, [], n_models) * w, ...
               n_s, numel(leads_out)));
         end
      end
      comb_name{end+1} = label;
      comb_all(end+1) = combR(Ec);  comb_surf{end+1} = surf_of(Ec);
      clear Ec past X
   end
end

% ---- 4. causal two-model blends of the two best structures ----
pairs = { pick_cols(["anchor_mix" "MW_run"]),  "anchor + MWrun"; ...
          pick_cols(["anchor_mix" "T28_AR4"]), "anchor + AR4" };
for pi = 1:size(pairs,1)
   pair = pairs{pi,1};
   Ec = zeros(n_s, n_h, n_d, 'single');
   for ls = 1:n_blk
      leads = lead_sets{ls};
      for d = n_w+1:n_d
         past = double(E4(sub_slots, leads, d-n_w:d-1, pair));
         X = reshape(past, [], 2);
         S = (X' * X) / size(X,1);
         w = S \ ones(2,1);  w = w / sum(w);
         blk2 = squeeze(double(E4(:, leads, d, pair)));
         Ec(:, leads, d) = single(reshape(reshape(blk2, [], 2) * w, n_s, numel(leads)));
      end
   end
   comb_name{end+1} = "causal 2-model blend (" + pairs{pi,2} + ")";
   comb_all(end+1) = combR(Ec);  comb_surf{end+1} = surf_of(Ec);
   clear Ec blk2
end
clear past X

% ---- report ----
fprintf("\n%-42s %11s", "combination", "whole atlas");
for k = 1:numel(h_show), fprintf("%11s", h_lab{k}); end
fprintf("\n");
for c = 1:numel(comb_name)
   fprintf("%-42s %11.2f", comb_name{c}, comb_all(c));
   for k = 1:numel(h_show)
      fprintf("%11.2f", mean(comb_surf{c}(:, h_show(k))));
   end
   fprintf("\n");
end
% ---- report ----
% Every rule is compared cell by cell against every other rule and every single
% model, over the same days. A cell is one (time of day, lead) pair. The scalars
% are run fingerprints, not rankings.
Rd = sqrt(mean(double(E4(:, :, d_score, :)).^2, 3));       % slot x lead x model
Sall = zeros(n_s, n_h, n_models + numel(comb_name));
Sall(:, :, 1:n_models) = Rd;
for c = 1:numel(comb_name), Sall(:, :, n_models + c) = comb_surf{c}; end
lbl = [names(:); string(comb_name(:))];
[~, wc] = min(Sall, [], 3);
wins = zeros(numel(lbl),1);
for i = 1:numel(lbl), wins(i) = sum(sum(wc == i)); end
[~, ow] = sort(wins, "descend");

fprintf("\n--- cells won out of %d, days %d to %d ---\n", n_s*n_h, ...
   d_score(1), d_score(end));
for i = ow'
   if wins(i) > 0
      fprintf("  %-46s %6d cells %6.2f%%\n", lbl(i), wins(i), ...
         100*wins(i)/(n_s*n_h));
   end
end

fprintf("\n--- cells won inside one lead, over the 288 times of day ---\n");
fprintf("%-46s", "candidate");
for k = 1:numel(h_show), fprintf("%10s", h_lab{k}); end
fprintf("\n");
for i = ow'
   if wins(i) == 0, continue; end
   fprintf("%-46s", lbl(i));
   for k = 1:numel(h_show)
      fprintf("%10d", sum(wc(:, h_show(k)) == i));
   end
   fprintf("\n");
end

fprintf("\nfingerprints over days %d to %d, NOT a ranking basis:\n", ...
   d_score(1), d_score(end));
for c = 1:numel(comb_name)
   fprintf("  %-46s %8.3f\n", comb_name{c}, comb_all(c));
end
fprintf("  %-46s %8.3f\n", "best single model", min(sqrt(mean( ...
   reshape(double(E4(:, :, d_score, :)), [], n_models).^2, 1))));

fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
save(fullfile(fig_dir, atlas_name), "E4", "names", "keys", "R", "Rall", ...
   "win_cells", "ar_sel", "ar_sel_hist", "P_set", "M19_W", ...
   "lead_min", "h_all", "n_h", "n_d", "n_w", "cfg_axis", "cfg_window", ...
   "t_test", "comb_name", "comb_all", "comb_surf", "d_score", "-v7.3");
fprintf("\natlas and combinations written to %s\n", fullfile(fig_dir, atlas_name));
fprintf("### SCRIPT COMPLETED ###\n");

%% ---------- local helpers ----------
function c = col_of(keys, k)
   % Column of one registry key within THIS atlas, which may hold fewer columns
   % than the registry. Fails loudly rather than addressing a neighbouring model.
   c = find(keys == string(k), 1);
   assert(~isempty(c), 'run_full_ensemble_test:col_of', ...
      '"%s" is not a column of this atlas, but a combination rule names it', k);
end
