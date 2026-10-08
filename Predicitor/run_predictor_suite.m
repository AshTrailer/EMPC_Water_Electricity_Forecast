%% ============================================================
%  RUN_PREDICTOR_SUITE  Unified short/long-term price predictor evaluation
%
%  One entry point, one protocol, one (lead x slot) error atlas per model.
%
%  PROTOCOL
%    Data          AEMO_Data/PRICE_AND_DEMAND_*_VIC1.csv, 5-min RRP, NEM time
%    Warm-up       2026-01-01 00:05 .. 2026-01-30 24:00 (online, no forecast)
%    Origins       2026-01-31 00:05 .. end of test window (one per 5 min)
%    Targets       2026-02-01 00:05 .. train_end + n_days
%    Information   INGEST FIRST: y(t) is inside the state before the forecast
%                  is issued, so lead h means h steps after the newest
%                  observation. Model 4 keeps the older forecast-first
%                  convention for reference (see Fig. 5).
%    Price clamp   rolling 30-day global Q1/Q99, recomputed once per day,
%                  applied to every forecast and every scored actual
%    Scoring       e = clamped target - clamped forecast, accumulated per
%                  (target slot s, lead h, target day d): one sample per cell
%                  per day, so cells are directly comparable across models
%
%  MODELS
%    1 Persistence (same slot, yesterday)      6 Carry-forward
%    2 Rolling template T                      7 T + DMS(4), refit daily
%    3 Theta-y tracker                         8 Carry-forward + DMS(4)
%    4 T + AR(4) iterated, forecast-first      9 Anchor-mix DMS(4)   <- new
%    5 T + AR(4) iterated, ingest-first
%
%  This script draws figures and prints tables. It never writes a file:
%  export is the caller's job (see Weekly/<date>/predictor/export_figures.m).
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(project_root, "MPC", "First_Version_MPC"));
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));
addpath(fullfile(predictor_root, "PriceClamp"));
addpath(fullfile(predictor_root, "Template_AR_predictor"));
addpath(fullfile(predictor_root, "ThetaY_Tracker"));
addpath(fullfile(predictor_root, "Anchor_AR_predictor"));

n_slots = 288;  p = 4;  lam = 0.98;  delta = 100;  win_days = 28;
clamp_days = 30;  n_days = 120;  refit_days = 14;

train_start = datetime(2026,1,1,0,5,0);
train_end   = datetime(2026,2,1,0,0,0);
test_start  = datetime(2026,2,1,0,5,0);
test_end    = train_end + days(n_days);
aemo = load_aemo_data(fullfile(project_root, "AEMO_Data"));
t_all = aemo.time;  y_all = aemo.price;

tm = (t_all >= train_start) & (t_all <= train_end);
xm = (t_all >= test_start)  & (t_all <= test_end);
t_train = t_all(tm);  y_train = y_all(tm);
t_test  = t_all(xm);  y_test  = y_all(xm);
n_train = numel(y_train);  n_test = numel(y_test);
assert(n_train == 31*n_slots && n_test == n_days*n_slots, 'window mismatch');
t_seq = [t_train; t_test];  y_seq = [y_train; y_test];
n_seq = n_train + n_test;   slot_seq = get_slot_index(t_seq);
i_start = n_train - n_slots + 1;
fprintf("origins %s .. %s | targets %s .. %s (%d days)\n", ...
   t_seq(i_start), t_seq(n_seq), t_test(1), t_test(end), n_days);

% ---- causal clamp thresholds, one pair per test day -----------------------
y_win0 = reshape(y_train(n_slots+1:end), n_slots, clamp_days)';
cs = init_price_clamp(y_win0);
q_by_day = zeros(n_days,2); q_by_day(1,:) = cs.q;
for d = 1:n_days-1
   cs = update_price_clamp(cs, y_test((d-1)*n_slots + (1:n_slots))');
   q_by_day(d+1,:) = cs.q;
end
q1_seq = repelem(q_by_day(:,1), n_slots);
q2_seq = repelem(q_by_day(:,2), n_slots);
yc_seq = clamp_price(y_test, [q1_seq, q2_seq]);   % elementwise, per point

% Clamped series over the WHOLE stream, needed by the anchor-mix fit whose
% rows and targets live in one index space. Test-day thresholds are the same
% q_by_day used for scoring; training-day thresholds come from a rolling
% 30-day window inside the training month.
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
% overwrite the scored region with the sanctioned per-day thresholds
i_test0 = n_train + 1;
q1_all(i_test0:end) = q1_seq;  q2_all(i_test0:end) = q2_seq;
yc_all = clamp_price(y_seq, [q1_all, q2_all]);
dc_all = [0; diff(yc_all)];

names = ["Persistence(yest)","Rolling template","Theta-y tracker", ...
   "T+AR4","Carry-forward","T+DMS4 refit","CF+DMS4 refit","Anchor-mix refit"];
n_models = numel(names);
N2 = n_slots*n_slots;  N3 = N2*n_days;
E4 = zeros(n_slots, n_slots, n_days, n_models, 'single');

% ---- state ---------------------------------------------------------------
T_sum = zeros(n_slots,1); T_cnt = zeros(n_slots,1); T_win = zeros(n_slots,win_days);
T_snap = zeros(n_slots, n_days+1);      % col 1 = template at end of warm-up
phi = zeros(p,1); Pphi = delta*eye(p); hist = zeros(p,1); nhist = 0;
y_prev = zeros(n_slots,1);
has_prev = false(n_slots,1);
th_trk = init_theta_tracker(n_slots, lam, delta);
r_seq = nan(n_seq,1);  d_seq = zeros(n_seq,1);
% column of T_snap that applies to each stream position (1 = warm-up, 2.. = test days)
day_col = min(max(floor(((1:n_seq)' - n_train - 1)/n_slots) + 2, 1), n_days+1);
C_t = zeros(n_slots,p+1);  C_c = zeros(n_slots,p+1);  C_a = zeros(n_slots,2*p+3);
C_a_sum = zeros(n_slots,2*p+3);  C_a_n = 0;
hv = (1:n_slots)';
rhat_prev = zeros(n_slots,1);  have_prev = false;

% ================= warm-up: stream the training month, no forecasting =====
% The template needs 28 days of the same slot and the AR/RLS states need to
% converge before the first scored origin, so 01-01 .. 01-30 is streamed here.
for idx = 1:i_start-1
   s = slot_seq(idx);
   yv = y_seq(idx);
   if T_cnt(s) == 0
      T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
   else
      r = yv - T_sum(s)/T_cnt(s);
      if idx > 1
         d_seq(idx) = yv - y_seq(idx-1);
      end
      if nhist >= p
         [phi, Pphi] = rls_vector_step(r, hist, phi, Pphi, lam);
      end
      r_seq(idx) = r;
      hist = [r; hist(1:end-1)];  nhist = min(nhist+1, p);
      col = mod(T_cnt(s), win_days)+1;
      T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
      T_cnt(s) = min(T_cnt(s)+1, win_days);
   end
   th_trk = update_theta_tracker(th_trk, s, yv);
   y_prev(s) = yv;  has_prev(s) = true;
end
T_snap(:,1) = T_sum ./ max(T_cnt,1);
fprintf("warm-up streamed: %d points, template depth max %d\n", ...
   i_start-1, max(T_cnt));

for idx = i_start:n_seq
   s = slot_seq(idx);
   u = target_slots(s, n_slots, n_slots);       % true target slots

   tj = idx + hv;  jtest_all = tj - n_train;
   valid = (jtest_all >= 1) & (jtest_all <= n_test);
   hh = hv(valid);  jtest = jtest_all(valid);
   d_tgt = floor((jtest-1)/n_slots) + 1;
   q1 = q1_seq(jtest);  q2 = q2_seq(jtest);  y_c = yc_seq(jtest);
   lin = u(valid) + n_slots*(hh-1) + N2*(d_tgt-1);

   % ================= ingest y(idx) =================
   yv = y_seq(idx);
   yp_fc = y_prev;                              % yesterday's values, all slots
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
      col = mod(T_cnt(s), win_days)+1;
      T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
      T_cnt(s) = min(T_cnt(s)+1, win_days);
   end
   th_trk = update_theta_tracker(th_trk, s, yv);
   y_prev(s) = yv;  has_prev(s) = true;

   if s == 1 && idx > i_start && nhist >= p
      T_snap(:, day_col(idx)) = T_sum ./ max(T_cnt,1);
      C_t = refit_dms(r_seq,              idx, refit_days*n_slots, p);
      C_c = refit_dms(d_seq,              idx, refit_days*n_slots, p);
      C_a = fit_anchor_mix(yc_all, dc_all, r_seq, T_snap, day_col, ...
                           idx, refit_days*n_slots, p);
      C_a_sum = C_a_sum + C_a;  C_a_n = C_a_n + 1;
   end

   % ================= forecast, ingest-first =================
   t_vec = T_sum(u) ./ max(T_cnt(u),1);
   rhat = zeros(n_slots,1);
   if nhist >= p
      buf = hist;
      for k = 1:n_slots
         v = phi'*buf;  rhat(k) = v;  buf = [v; buf(1:end-1)];
      end
   end
   cf = yv;
   y_anchor = predict_anchor_mix(C_a, cf, t_vec, hist, d_seq(idx:-1:idx-p+1));

   F = [ predict_theta_tracker(th_trk, s, n_slots), ...        % 3 theta-y
         t_vec, ...                                            % 2 template
         t_vec + rhat, ...                                     % 5 T+AR4 ingest-first
         repmat(cf, n_slots, 1), ...                            % 6 carry-forward
         t_vec + C_t*[1; hist], ...                             % 7 T+DMS4
         cf + C_c*[1; d_seq(idx:-1:idx-p+1)], ...               % 8 CF+DMS4
         y_anchor ];                                            % 9 anchor-mix
   rhat_prev = rhat;  have_prev = true;

   if ~isempty(hh)
      map = [3 2 4 5 6 7 8];        % F column -> model index
      for c = 1:size(F,2)
         fc = clamp_price(F(valid,c), [q1, q2]);
         E4(lin + (map(c)-1)*N3) = y_c - fc;
      end
      E4(lin) = y_c - clamp_price(yp_fc(u(valid)), [q1, q2]);   % model 1
   end
end
fprintf("atlas built: %s\n", mat2str(size(E4)));
fprintf("anchor-mix: a_h (weight on the current price) at h = 1,12,72,288 : %.3f %.3f %.3f %.3f\n", ...
   C_a_show(C_a,1), C_a_show(C_a,12), C_a_show(C_a,72), C_a_show(C_a,288));

%% ---------- TABLES (numbers that do not deserve a figure) ----------
h_show = [1 6 12 36 72 144 288];
h_lab  = {'5min','30min','1h','3h','6h','12h','24h'};
h_steps = [1 6 12 36 72 144 288];
win_txt = sprintf("%s .. %s (%d days)", ...
   datestr(t_test(1),'yyyy-mm-dd'), datestr(t_test(end),'yyyy-mm-dd'), n_days);

Rpool = zeros(n_models, numel(h_show));
Rslot = zeros(n_models, numel(h_show));
for m = 1:n_models
   for k = 1:numel(h_show)
      x = double(squeeze(E4(:,h_show(k),:,m)));      % 288 slots x n_days
      Rpool(m,k) = sqrt(mean(x(:).^2));              % pooled over slots and days
      Rslot(m,k) = median(sqrt(mean(x.^2,2)));       % median of the 288 slot RMSEs
   end
end

fprintf("\n================ TABLE 1  RMSE by forecast lead ================\n");
fprintf("data %s | clamped prices | ingest-first | unit $/MWh\n", win_txt);
fprintf("each cell: pooled RMSE over all 288 slots x %d days (median over slots in brackets)\n", n_days);
fprintf("%-22s", "model");
for k = 1:numel(h_show), fprintf("%16s", h_lab{k}); end
fprintf("\n");
for m = 1:n_models
   fprintf("%-22s", names(m));
   for k = 1:numel(h_show)
      fprintf("%9.1f [%5.1f]", Rpool(m,k), Rslot(m,k));
   end
   fprintf("\n");
end
fprintf("%-22s", "clamped signal std");
fprintf("%16.1f", std(yc_seq));
fprintf("   <- an RMSE near this value carries no information\n");

fprintf("\n================ TABLE 2  best model per lead ================\n");
for k = 1:numel(h_show)
   [v, bm] = min(Rpool(:,k));
   fprintf("  lead %-6s : %-20s %.1f $/MWh   (runner-up %s %.1f)\n", ...
      h_lab{k}, names(bm), v, names(setdiff(1:n_models,bm)), ...
      min(Rpool(setdiff(1:n_models,bm),k)));
end

fprintf("\n================ TABLE 3  anchor-mix coefficients ================\n");
Cmean = C_a_sum / max(C_a_n,1);
fprintf("model: y(t+h) = c_h + a_h*y(t) + b_h*T(s(t+h)) + sum phi*r + sum psi*dy   (mean of %d daily refits)\n", C_a_n);
fprintf("%-10s %10s %10s %10s %10s %10s\n","lead","c_h","a_h","b_h","a_h+b_h","sum|phi|");
for h = [1 6 12 36 72 144 288]
   fprintf("%-10s %10.2f %10.3f %10.3f %10.3f %10.3f\n", sprintf("h=%d",h), ...
      Cmean(h,1), Cmean(h,2), Cmean(h,3), Cmean(h,2)+Cmean(h,3), ...
      sum(abs(Cmean(h,4:3+p))));
end

%% ---------- FIGURE SET D & G : rolling 5-min forecast only ----------
% D: one day, one subplot per model, the rolling 5-min-ahead forecast vs the
%    actual of the same day.  Every target point has its own forecast, issued
%    one step earlier.
% G: the same 5-min-ahead forecast pooled over all test days, per target slot:
%    Q05..Q95 band across days, median and mean.
h_5 = 1;
x_h = (1:n_slots)'/12;

% ---- D : single day ----
std_day = zeros(n_days,1);
for d = 1:n_days
   std_day(d) = std(yc_seq((d-1)*n_slots + (1:n_slots)'));
end
[~, d_rep] = min(abs(std_day - median(std_day)));
d_rep_date = datestr(t_test((d_rep-1)*n_slots+1), 'yyyy-mm-dd (ddd)');
y_act = yc_seq((d_rep-1)*n_slots + (1:n_slots)');
fprintf("\nsingle-day view uses %s (daily std %.1f, median over the window %.1f)\n", ...
   d_rep_date, std_day(d_rep), median(std_day));

F = cell(n_models,1);  yl = [inf -inf];
for m = 1:n_models
   e = double(E4(:,h_5,d_rep,m));
   F{m} = y_act - e;
   yl(1) = min(yl(1), min(F{m}));  yl(2) = max(yl(2), max(F{m}));
end
yl(1) = min(yl(1), min(y_act));  yl(2) = max(yl(2), max(y_act));
pad = 0.06*range(yl);  yl = [yl(1)-pad, yl(2)+pad];

figure('Name','D single day, rolling 5-min','Position',[40 40 1320 820]);
tl = tiledlayout(4,2,'TileSpacing','compact','Padding','compact');
for m = 1:n_models
   nexttile; hold on;
   plot(x_h, y_act, 'k-', 'LineWidth', 1.8);
   plot(x_h, F{m}, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.1);
   hold off; grid on; xlim([0 24]); xticks(0:6:24); ylim(yl);
   ylabel('price ($/MWh)'); xlabel('target slot (hour of day)');
   title(names(m), 'FontSize', 9);
   text(0.5, 0.94, sprintf('day RMSE %.1f', sqrt(mean((y_act - F{m}).^2))), ...
      'Units','normalized','HorizontalAlignment','center','FontSize',8,'Color',[0.7 0 0]);
   if m == 1
      legend({'actual (clamped)','rolling 5-min forecast'}, 'Location','northwest','FontSize',7);
   end
end
title(tl, sprintf(['D  SINGLE DAY = %s   |   ROLLING 5-MIN FORECAST (each target forecast 1 step earlier)\n' ...
   'data %s | clamped | unit $/MWh'], d_rep_date, win_txt), 'FontSize', 10);

% ---- G : across days, per target slot ----
Q = cell(n_models,1);  yl = [inf -inf];
for m = 1:n_models
   x = double(squeeze(E4(:,h_5,:,m)));
   Q{m} = [quantile(x,0.05,2), median(x,2), mean(x,2), quantile(x,0.95,2)];
   yl(1) = min(yl(1), min(Q{m}(:,1)));  yl(2) = max(yl(2), max(Q{m}(:,4)));
end
pad = 0.06*range(yl);  yl = [yl(1)-pad, yl(2)+pad];

figure('Name','G rolling 5-min, across days','Position',[20 20 1320 820]);
tl = tiledlayout(4,2,'TileSpacing','compact','Padding','compact');
for m = 1:n_models
   nexttile; hold on;
   fill([x_h; flipud(x_h)], [Q{m}(:,1); flipud(Q{m}(:,4))], [0.55 0.72 0.95], ...
      'FaceAlpha',0.4,'EdgeColor','none');
   plot(x_h, Q{m}(:,2), 'b-', 'LineWidth', 1.3);
   plot(x_h, Q{m}(:,3), 'r-', 'LineWidth', 1.0);
   plot(x_h, sqrt(mean(x.^2,2)), 'k-', 'LineWidth', 1.1);
   hold off; grid on; xlim([0 24]); xticks(0:6:24); ylim(yl);
   ylabel('error ($/MWh)'); xlabel('target slot (hour of day)');
   title(names(m), 'FontSize', 9);
   text(0.5, 0.94, sprintf('RMSE %.1f  |  med %.1f', Rpool(m,1), median(Q{m}(:,2))), ...
      'Units','normalized','HorizontalAlignment','center','FontSize',8,'Color',[0 0 0.6]);
   if m == 1
      legend({'Q05..Q95 across days = bounds','median error','mean error','RMSE'}, 'Location','northwest','FontSize',6);
   end
end
title(tl, sprintf(['G  ROLLING 5-MIN FORECAST, error per target slot over %d days\n' ...
   'data %s | clamped rolling 30-day global Q1/Q99 | unit $/MWh'], n_days, win_txt), 'FontSize', 10);

%% ---------- FIGURE SET H : fixed origin, no rolling, 288-step forecast ----------
% ONE origin (the 24:00 point just before the single-day view day).  Each model
% issues one 288-step forecast from that single instant; x is the horizon.
org_abs = n_train + (d_rep-1)*n_slots;
R_ray = ray_errors(E4, org_abs, n_train, n_slots, n_days, n_models);
h_ax = (1:n_slots)'/12;
yl = [min([y_act; reshape(R_ray + y_act, [], 1)]) max([y_act; reshape(R_ray + y_act, [], 1)])];
pad = 0.06*range(yl);  yl = [yl(1)-pad, yl(2)+pad];

figure('Name','H fixed origin, 288-step','Position',[60 60 1320 820]);
tl = tiledlayout(4,2,'TileSpacing','compact','Padding','compact');
for m = 1:n_models
   nexttile; hold on;
   plot(h_ax, y_act, 'k-', 'LineWidth', 1.8);
   plot(h_ax, y_act - R_ray(:,m), '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.1);
   hold off; grid on; xlim([0 24]); xticks(0:6:24); ylim(yl);
   ylabel('price ($/MWh)'); xlabel('horizon (hour after the origin)');
   title(names(m), 'FontSize', 9);
   text(0.5, 0.94, sprintf('horizon RMSE %.1f', sqrt(mean(R_ray(:,m).^2))), ...
      'Units','normalized','HorizontalAlignment','center','FontSize',8,'Color',[0.7 0 0]);
   if m == 1
      legend({'actual of the following 24 h','one 288-step forecast from the origin'}, ...
         'Location','northwest','FontSize',7);
   end
end
title(tl, sprintf(['H  FIXED ORIGIN, NO ROLLING: one forecast issued at %s, horizon 24 h\n' ...
   'data %s | clamped | unit $/MWh'], ...
   datestr(t_seq(org_abs),'yyyy-mm-dd HH:MM'), win_txt), 'FontSize', 10);

%% ---------- FIGURE SET I : many fixed origins, aggregated by horizon ----------
% Origins at the same clock time on every test day (24:00), so every origin has
% the same information content but a different day's difficulty.  Each curve is
% therefore a distribution of long-horizon skill, not a single lucky case.
org_list = n_train + (0:n_days-1)'*n_slots;
Rl = nan(n_slots, n_days, n_models);
for d = 1:n_days
   Rl(:,d,:) = ray_errors(E4, org_list(d), n_train, n_slots, n_days, n_models);
end
fprintf("\n[I] long-horizon distribution over %d fixed origins (same clock time)\n", n_days);
fprintf("%-22s", "model");
for hh = [1 6 12 36 72 144 288], fprintf("%10s", sprintf("h=%d",hh)); end
fprintf("\n");
for m = 1:n_models
   Rm_ = squeeze(Rl(:,:,m));
   fprintf("%-22s", names(m));
   for hh = [1 6 12 36 72 144 288]
      v = Rm_(hh,:);  v = v(isfinite(v));
      fprintf("%10.1f", sqrt(mean(v.^2)));
   end
   fprintf("\n");
end

figure('Name','I long-horizon, many origins','Position',[90 90 1320 820]);
tl = tiledlayout(4,2,'TileSpacing','compact','Padding','compact');
for m = 1:n_models
   nexttile; hold on;
   Rm_ = squeeze(Rl(:,:,m));
   q05 = quantile(Rm_,0.05,2);  q95 = quantile(Rm_,0.95,2);
   fill([h_ax; flipud(h_ax)], [q05; flipud(q95)], [0.55 0.72 0.95], ...
      'FaceAlpha',0.4,'EdgeColor','none');
   plot(h_ax, median(Rm_,2), 'b-', 'LineWidth', 1.3);
   plot(h_ax, mean(Rm_,2), 'r-', 'LineWidth', 1.0);
   plot(h_ax, sqrt(mean(Rm_.^2,2)), 'k-', 'LineWidth', 1.1);
   hold off; grid on; xlim([0 24]); xticks(0:6:24);
   ylabel('error ($/MWh)'); xlabel('horizon (hour after the origin)');
   title(names(m), 'FontSize', 9);
   text(0.5, 0.94, sprintf('RMSE@24h %.1f', sqrt(mean(Rm_(n_slots,:).^2))), ...
      'Units','normalized','HorizontalAlignment','center','FontSize',8,'Color',[0 0 0.6]);
   if m == 1
      legend({'Q05..Q95 across origins = bounds','median error','mean error','RMSE'}, 'Location','northwest','FontSize',6);
   end
end
title(tl, sprintf(['I  FIXED-ORIGIN LONG-HORIZON SKILL, aggregated over %d origins (24:00 each day)\n' ...
   'no rolling: each origin issues one 288-step forecast | clamped | unit $/MWh'], n_days), 'FontSize', 10);

%% ---------- I table: RMSE vs band width, per lead ----------
fprintf("\n[I] per-lead RMSE and cross-origin band width Q05..Q95 ($/MWh)\n");
fprintf("%-22s", "model");
for hh = [1 6 12 36 72 144 288], fprintf("%12s", sprintf("h=%d",hh)); end
fprintf("\n");
for m = 1:n_models
   Rm_ = squeeze(Rl(:,:,m));
   fprintf("%-22s", names(m) + " RMSE");
   for hh = [1 6 12 36 72 144 288]
      v = Rm_(hh,:);  v = v(isfinite(v));
      fprintf("%12.1f", sqrt(mean(v.^2)));
   end
   fprintf("\n%-22s", names(m) + " width");
   for hh = [1 6 12 36 72 144 288]
      v = Rm_(hh,:);  v = v(isfinite(v));
      fprintf("%12.1f", quantile(v,0.95) - quantile(v,0.05));
   end
   fprintf("\n");
end

%% ---------- FIGURE SET J : 288x288 RMSE heatmap, colour clipped at 60 ----------
% The per-(target slot, lead) surface: rows are the time of day, columns the
% forecast lead.  Colour is clipped at 60 $/MWh because above that every model
% is uninformative (clamped signal std is about 49).
hm = [2 4 5 6 7 8];
Rhm = cell(n_models,1);
for m = hm
   E = double(E4(:,:,:,m));
   Rhm{m} = sqrt(sum(E.^2,3)/n_days);
   clear E
end
figure('Name','J RMSE 288x288 heatmap','Position',[120 120 1340 660]);
tl = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
colormap(turbo);
for m = hm
   nexttile;
   imagesc(Rhm{m}, [0 60]);
   set(gca,'XTick',[1 72 144 216 288],'XTickLabel',{'0','6','12','18','24'});
   set(gca,'YTick',[1 72 144 216 288],'YTickLabel',{'0','6','12','18','24'});
   xlabel('lead (hour)'); ylabel('target slot (hour of day)');
   title(names(m),'FontSize',9);
end
cb = colorbar;  cb.Layout.Tile = 'east';
cb.Label.String = 'RMSE ($/MWh, clamped, colour clipped at 60)';
title(tl, sprintf('J  RMSE(target slot, lead), 288x288 surface, %d days', n_days), 'FontSize', 10);
%% ---------- local helpers ----------
function R = ray_errors(E4, origin_abs, n_train, n_slots, n_days, n_models)
   % RAY_ERRORS  Errors along one origin: h = 1..288, target = origin_abs + h.
   % Walks the (slot, lead, day, model) atlas instead of storing full forecasts.
   N3 = n_slots*n_slots*n_days;
   R = nan(n_slots, n_models);
   s0 = mod(origin_abs - 1, n_slots) + 1;
   for h = 1:n_slots
      jt = origin_abs + h - n_train;
      if jt < 1 || jt > n_days*n_slots
         continue
      end
      d = floor((jt-1)/n_slots) + 1;
      s = mod(s0 + h - 1, n_slots) + 1;
      base = s + n_slots*(h-1) + n_slots*n_slots*(d-1);
      for m = 1:n_models
         R(h,m) = double(E4(base + (m-1)*N3));
      end
   end
end

function C = refit_dms(series, last, L, pmax)
   % Direct multi-step OLS: series(k+h) ~ 1 + series(k..k-pmax+1)
   n_h = 288;
   k_lo = max(pmax+2, last - L + 1);
   k = (k_lo:last)';
   B = ones(numel(k), pmax+1);
   for j = 0:pmax-1
      B(:, 2+j) = series(k - j);
   end
   C = zeros(n_h, pmax+1);
   for h = 1:n_h
      m = k <= (last - h);
      X = B(m,:);  tgt = series(k(m) + h);
      good = all(isfinite(X),2) & isfinite(tgt);
      X = X(good,:);  tgt = tgt(good);
      if size(X,1) >= 50
         C(h,:) = (X \ tgt)';
      end
   end
end

function v = C_a_show(C, h)
   v = C(h,2);
end
