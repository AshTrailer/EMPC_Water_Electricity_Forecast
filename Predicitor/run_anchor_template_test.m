%% ============================================================
%  RUN_ANCHOR_TEMPLATE_TEST  Give the champion a better template
%
%  run_full_ensemble_test.m showed Anchor-mix is the best single model at
%  every lead. Its regression is
%
%     y(k+h) = c_h + a_h*y(k) + b_h*T + sum_j phi_hj*r + sum_j psi_hj*Dy
%
%  with T the rolling 28-day template and r = y - T. The template is an INPUT
%  to fit_anchor_mix and predict_anchor_mix, so a better template can be
%  swapped in without touching those modules. This script does exactly that
%  and nothing else, so the comparison is a clean A/B.
%
%     A  anchor-mix, T = rolling 28-day template          (current champion)
%     B  anchor-mix, T = multi-window 7/28/56/112 template
%
%  PROTOCOL identical to run_full_ensemble_test.m.
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(project_root, "MPC", "First_Version_MPC"));
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));
addpath(fullfile(predictor_root, "PriceClamp"));
addpath(fullfile(predictor_root, "Anchor_AR_predictor"));
addpath(fullfile(predictor_root, "Multi_Window_predictor"));

n_slots = 288;  p = 4;  lam = 0.98;  delta = 100;  win_days = 28;
clamp_days = 30;  n_days = 120;  refit_days = 14;  mw_windows = [7 28 56 112];

train_end   = datetime(2026,2,1,0,0,0);
test_start  = datetime(2026,2,1,0,5,0);
test_end    = train_end + days(n_days);
aemo = load_aemo_data(fullfile(project_root, "AEMO_Data"));
t_all = aemo.time;  y_all = aemo.price;
tm = (t_all >= datetime(2025,9,1,0,5,0)) & (t_all <= train_end);
xm = (t_all >= test_start)  & (t_all <= test_end);
t_train = t_all(tm);  y_train = y_all(tm);
t_test  = t_all(xm);  y_test  = y_all(xm);
n_train = numel(y_train);  n_test = numel(y_test);
assert(n_train == 153*n_slots && n_test == n_days*n_slots, 'window mismatch');
t_seq = [t_train; t_test];  y_seq = [y_train; y_test];
n_seq = n_train + n_test;   slot_seq = get_slot_index(t_seq);
i_start = n_train + 1;
fprintf("warm-up %d days | targets %s .. %s (%d days)\n", ...
   n_train/n_slots, t_test(1), t_test(end), n_days);

% ---- clamp ---------------------------------------------------------------
y_win0 = reshape(y_train(end - clamp_days*n_slots + 1:end), n_slots, clamp_days)';
cs = init_price_clamp(y_win0);
q_by_day = zeros(n_days,2); q_by_day(1,:) = cs.q;
for d = 1:n_days-1
   cs = update_price_clamp(cs, y_test((d-1)*n_slots + (1:n_slots))');
   q_by_day(d+1,:) = cs.q;
end
q1_seq = repelem(q_by_day(:,1), n_slots);
q2_seq = repelem(q_by_day(:,2), n_slots);
yc_seq = clamp_price(y_test, [q1_seq, q2_seq]);
q1_all = zeros(n_seq,1);  q2_all = zeros(n_seq,1);
for gd = 1:ceil(n_seq/n_slots)
   lo = max(1, (gd - clamp_days - 1)*n_slots + 1);
   hi = min(n_seq, (gd-1)*n_slots);
   win = y_seq(lo:hi);
   if isempty(win), win = y_seq(1); end
   thr = prctile(win, [1 99]);
   idx_day = (gd-1)*n_slots + (1:n_slots);
   idx_day = idx_day(idx_day <= n_seq);
   q1_all(idx_day) = thr(1);  q2_all(idx_day) = thr(2);
end
q1_all(i_start:end) = q1_seq;  q2_all(i_start:end) = q2_seq;
yc_all = clamp_price(y_seq, [q1_all, q2_all]);
dc_all = [0; diff(yc_all)];

names = ["Anchor-mix, T28 template","Anchor-mix, multi-window template"];
n_models = numel(names);
N2 = n_slots*n_slots;  N3 = N2*n_days;
E4 = zeros(n_slots, n_slots, n_days, n_models, 'single');

% ---- state ---------------------------------------------------------------
T_sum = zeros(n_slots,1); T_cnt = zeros(n_slots,1); T_win = zeros(n_slots,win_days);
T_snap = zeros(n_slots, n_days+1);        % 28-day template snapshot per region position
T_snap_mw = zeros(n_slots, n_days+1);     % multi-window template snapshot
r_seq = nan(n_seq,1);  r_mw_seq = nan(n_seq,1);
d_seq = zeros(n_seq,1);
day_col = min(max(floor(((1:n_seq)' - n_train - 1)/n_slots) + 2, 1), n_days+1);
C_a = zeros(n_slots,2*p+3);  C_a_sum = zeros(n_slots,2*p+3);  C_a_n = 0;
C_b = zeros(n_slots,2*p+3);  C_b_sum = zeros(n_slots,2*p+3);  C_b_n = 0;
hv = (1:n_slots)';
hist_a = zeros(p,1);  hist_b = zeros(p,1);
st_mw  = init_multi_window(n_slots, mw_windows);

% ================= warm-up =================
for idx = 1:n_train
   s = slot_seq(idx);  yv = y_seq(idx);
   if T_cnt(s) == 0
      T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
      r_seq(idx) = NaN;
   else
      r_seq(idx) = yv - T_sum(s)/T_cnt(s);
      if idx > 1, d_seq(idx) = yv - y_seq(idx-1); end
      col = mod(T_cnt(s), win_days)+1;
      T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
      T_cnt(s) = min(T_cnt(s)+1, win_days);
   end
   t_mw_pre = multi_window_template(st_mw);
   r_mw_seq(idx) = yv - t_mw_pre(s);
   hist_a = [r_seq(idx); hist_a(1:end-1)];
   hist_b = [r_mw_seq(idx); hist_b(1:end-1)];
   st_mw = update_multi_window(st_mw, s, yv);
end
fprintf("warm-up streamed %d points\n", n_train);

% ================= origin loop =================
for idx = i_start:n_seq
   s = slot_seq(idx);
   u = target_slots(s, n_slots, n_slots);
   tj = idx + hv;  jtest_all = tj - n_train;
   valid = (jtest_all >= 1) & (jtest_all <= n_test);
   hh = hv(valid);  jtest = jtest_all(valid);
   d_tgt = floor((jtest-1)/n_slots) + 1;
   q1 = q1_seq(jtest);  q2 = q2_seq(jtest);  y_c = yc_seq(jtest);
   lin = u(valid) + n_slots*(hh-1) + N2*(d_tgt-1);

   yv = y_seq(idx);
   if T_cnt(s) == 0
      T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
      r_seq(idx) = NaN;
   else
      r_seq(idx) = yv - T_sum(s)/T_cnt(s);
      d_seq(idx) = yv - y_seq(idx-1);
      col = mod(T_cnt(s), win_days)+1;
      T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
      T_cnt(s) = min(T_cnt(s)+1, win_days);
   end
   t_mw_pre = multi_window_template(st_mw);
   r_mw_seq(idx) = yv - t_mw_pre(s);
   hist_a = [r_seq(idx); hist_a(1:end-1)];
   hist_b = [r_mw_seq(idx); hist_b(1:end-1)];
   st_mw = update_multi_window(st_mw, s, yv);

   if s == 1 && idx > i_start
      T_snap(:, day_col(idx)) = T_sum ./ max(T_cnt,1);
      T_snap_mw(:, day_col(idx)) = multi_window_template(st_mw);
      C_a = fit_anchor_mix(yc_all, dc_all, r_seq,    T_snap,    day_col, ...
                           idx, refit_days*n_slots, p);
      C_b = fit_anchor_mix(yc_all, dc_all, r_mw_seq, T_snap_mw, day_col, ...
                           idx, refit_days*n_slots, p);
      C_a_sum = C_a_sum + C_a;  C_a_n = C_a_n + 1;
      C_b_sum = C_b_sum + C_b;  C_b_n = C_b_n + 1;
   end

   % t_vec is already indexed by the target slots u, do not index it again
   t_vec = T_sum(u) ./ max(T_cnt(u),1);
   t_mw  = multi_window_template(st_mw);
   cf = yv;
   y_a = predict_anchor_mix(C_a, cf, t_vec,   hist_a, d_seq(idx:-1:idx-p+1));
   y_b = predict_anchor_mix(C_b, cf, t_mw(u), hist_b, d_seq(idx:-1:idx-p+1));

   F = [y_a, y_b];
   if ~isempty(hh)
      for c = 1:2
         fc = clamp_price(F(valid,c), [q1, q2]);
         E4(lin + (c-1)*N3) = y_c - fc;
      end
   end
end
fprintf("atlas built: %s\n", mat2str(size(E4)));

%% ---------- report ----------
h_show = [1 6 12 36 72 144 288];
h_lab  = {'5min','30min','1h','3h','6h','12h','24h'};
R = @(x) sqrt(mean(x(:).^2));
fprintf("\n================ A/B: template inside the champion ================\n");
fprintf("data %s .. %s (%d days) | clamped | ingest-first | unit $/MWh\n", ...
   datestr(t_test(1),'yyyy-mm-dd'), datestr(t_test(end),'yyyy-mm-dd'), n_days);
fprintf("%-36s", "model");
for k = 1:numel(h_show), fprintf("%11s", h_lab{k}); end
fprintf("%12s\n", "whole atlas");
Rall = zeros(1,n_models);
for m = 1:n_models
   fprintf("%-36s", names(m));
   for k = 1:numel(h_show)
      fprintf("%11.2f", R(double(squeeze(E4(:,h_show(k),:,m)))));
   end
   Rall(m) = R(double(E4(:,:,:,m)));
   fprintf("%12.2f\n", Rall(m));
end
fprintf("%-36s", "gain of B over A");
for k = 1:numel(h_show)
   a = R(double(squeeze(E4(:,h_show(k),:,1))));
   b = R(double(squeeze(E4(:,h_show(k),:,2))));
   fprintf("%10.1f%%", 100*(1-b/a));
end
fprintf("%11.1f%%\n", 100*(1-Rall(2)/Rall(1)));

% daily win rate
dA = sqrt(squeeze(mean(E4(:,:,:,1).^2, 1)))';   % n_days x 288
dB = sqrt(squeeze(mean(E4(:,:,:,2).^2, 1)))';
rA = sqrt(mean(dA.^2,2));  rB = sqrt(mean(dB.^2,2));
fprintf("\nB wins %d of %d days | median daily RMSE  A %.2f  B %.2f\n", ...
   sum(rB < rA), n_days, median(rA), median(rB));

% the two-model convex blend, fitted causally per lead block
blk = 48;  comb_win = 28;  sub_slots = 1:6:n_slots;
Ec = zeros(n_slots, n_slots, n_days, 'single');
for ls = 0:n_slots/blk-1
   leads = ls*blk + (1:blk);
   for d = comb_win+1:n_days
      past = double(E4(sub_slots, leads, d-comb_win:d-1, :));
      X = reshape(past, [], 2);
      Sx = (X' * X) / size(X,1);
      w = Sx \ ones(2,1);  w = w / sum(w);
      blk2 = squeeze(double(E4(:, leads, d, :)));
      Ec(:, leads, d) = single(reshape(reshape(blk2, [], 2) * w, n_slots, numel(leads)));
   end
end
fprintf("\ncausal 2-model blend of A and B:\n");
fprintf("%-36s", "blend (A,B) causal");
for k = 1:numel(h_show)
   fprintf("%11.2f", mean(sqrt(mean(Ec(:,h_show(k),:).^2, 3))));
end
fprintf("%12.2f\n", R(Ec));

fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
if ~exist(fig_dir, "dir"), mkdir(fig_dir); end
save(fullfile(fig_dir, "atlas_anchor_ab.mat"), "E4", "names", "Rall", "-v7.3");
fprintf("\nwritten to %s\n", fullfile(fig_dir, "atlas_anchor_ab.mat"));
fprintf("### SCRIPT COMPLETED ###\n");
