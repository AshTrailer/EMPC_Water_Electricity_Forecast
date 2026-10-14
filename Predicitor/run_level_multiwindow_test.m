%% ============================================================
%  RUN_LEVEL_MULTIWINDOW_TEST  Two candidate fixes for long-horizon skill
%
%  Question: the rolling per-slot template T(s) is a 28-day average, so its
%  daily level is stale and the forecast converges to it as the lead grows.
%  Two cheap fixes are tested here on the same 120-day protocol:
%
%     T + level offset   T(s) shifted by (Lhat(D) - Lbar), where Lhat is a
%                        first-order recursion on completed daily means
%     multi-window T     arithmetic mean of the 7, 28, 56 and 112 day templates
%     multi-window + L   both together
%
%  PROTOCOL (identical to run_predictor_suite.m)
%    Data          AEMO_Data/PRICE_AND_DEMAND_*_VIC1.csv, 5-min RRP, NEM time
%    Warm-up       everything before 2026-02-01, streamed online
%    Origins       one per 5 min from 2026-02-01 00:05
%    Targets       2026-02-01 00:05 .. 2026-06-01 00:00 (120 days)
%    Price clamp   rolling 30-day global Q1/Q99, recomputed once per day
%    Scoring       one error sample per (target slot, lead, target day)
%
%  Seven models share the atlas, so any two of them can be compared cell by
%  cell. Models 4 to 6 are the new ones.
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(project_root, "MPC", "First_Version_MPC"));
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));
addpath(fullfile(predictor_root, "PriceClamp"));
addpath(fullfile(predictor_root, "Level_Offset_predictor"));
addpath(fullfile(predictor_root, "Multi_Window_predictor"));

n_slots = 288;  p = 4;  lam = 0.98;  delta = 100;  win_days = 28;
clamp_days = 30;  n_days = 120;  mw_windows = [7 28 56 112];  level_fit_days = 56;

train_start = datetime(2025,9,1,0,5,0);
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
assert(n_train == 153*n_slots, 'warm-up is not 153 whole days: %d', n_train);
assert(n_test == n_days*n_slots, 'test window mismatch: %d', n_test);
t_seq = [t_train; t_test];  y_seq = [y_train; y_test];
n_seq = n_train + n_test;   slot_seq = get_slot_index(t_seq);
i_start = n_train + 1;
fprintf("warm-up %s .. %s (%d days) | targets %s .. %s (%d days)\n", ...
   t_seq(1), t_seq(n_train), n_train/n_slots, t_test(1), t_test(end), n_days);

% ---- causal clamp thresholds, one pair per test day -----------------------
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
fprintf("clamp Q1 range %.2f .. %.2f | Q99 range %.2f .. %.2f\n", ...
   min(q_by_day(:,1)), max(q_by_day(:,1)), min(q_by_day(:,2)), max(q_by_day(:,2)));

names = ["Persistence(yest)","Template T28","T28 + AR4","T28 + level offset", ...
   "Multi-window T","MW + level offset","Multi-window T (56/28)","MW + level (run state)"];
n_models = numel(names);
N2 = n_slots*n_slots;  N3 = N2*n_days;
E4 = zeros(n_slots, n_slots, n_days, n_models, 'single');

% ---- state ---------------------------------------------------------------
T_sum = zeros(n_slots,1); T_cnt = zeros(n_slots,1); T_win = zeros(n_slots,win_days);
phi = zeros(p,1); Pphi = delta*eye(p); hist = zeros(p,1); nhist = 0;
y_prev = zeros(n_slots,1);
r_seq = nan(n_seq,1);
st_lvl = init_level_offset(n_slots, win_days, level_fit_days);
st_lvl2 = init_level_offset(n_slots, win_days, level_fit_days, true);
st_mw  = init_multi_window(n_slots, mw_windows);
st_mw2 = init_multi_window(n_slots, [28 56]);
hv = (1:n_slots)';
c_trace = zeros(n_days,1);  b_trace = zeros(n_days,1);  n_trace = 0;

% ================= warm-up: stream the training window, no forecasting =====
for idx = 1:n_train
   s = slot_seq(idx);
   yv = y_seq(idx);
   if T_cnt(s) == 0
      T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
   else
      r = yv - T_sum(s)/T_cnt(s);
      if nhist >= p
         [phi, Pphi] = rls_vector_step(r, hist, phi, Pphi, lam);
      end
      r_seq(idx) = r;
      hist = [r; hist(1:end-1)];  nhist = min(nhist+1, p);
      col = mod(T_cnt(s), win_days)+1;
      T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
      T_cnt(s) = min(T_cnt(s)+1, win_days);
   end
   st_lvl = update_level_offset(st_lvl, s, yv);
   st_lvl2 = update_level_offset(st_lvl2, s, yv);
   st_mw  = update_multi_window(st_mw, s, yv);
   st_mw2 = update_multi_window(st_mw2, s, yv);
   y_prev(s) = yv;
end
fprintf("warm-up streamed: %d points, level refits %d, c %.2f b1 %.3f\n", ...
   n_train, st_lvl.n_refit, st_lvl.c, st_lvl.b1);

for idx = i_start:n_seq
   s = slot_seq(idx);
   u = target_slots(s, n_slots, n_slots);

   tj = idx + hv;  jtest_all = tj - n_train;
   valid = (jtest_all >= 1) & (jtest_all <= n_test);
   hh = hv(valid);  jtest = jtest_all(valid);
   d_tgt = floor((jtest-1)/n_slots) + 1;
   q1 = q1_seq(jtest);  q2 = q2_seq(jtest);  y_c = yc_seq(jtest);
   lin = u(valid) + n_slots*(hh-1) + N2*(d_tgt-1);

   % ================= ingest y(idx) =================
   yv = y_seq(idx);
   yp_fc = y_prev;
   if T_cnt(s) == 0
      T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
   else
      r = yv - T_sum(s)/T_cnt(s);
      if nhist >= p
         [phi, Pphi] = rls_vector_step(r, hist, phi, Pphi, lam);
      end
      r_seq(idx) = r;
      hist = [r; hist(1:end-1)];  nhist = min(nhist+1, p);
      col = mod(T_cnt(s), win_days)+1;
      T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
      T_cnt(s) = min(T_cnt(s)+1, win_days);
   end
   prev_refit = st_lvl.n_refit;
   st_lvl = update_level_offset(st_lvl, s, yv);
   st_lvl2 = update_level_offset(st_lvl2, s, yv);
   st_mw  = update_multi_window(st_mw, s, yv);
   st_mw2 = update_multi_window(st_mw2, s, yv);
   if st_lvl.n_refit > prev_refit
      n_trace = n_trace + 1;
      c_trace(n_trace) = st_lvl.c;  b_trace(n_trace) = st_lvl.b1;
   end
   y_prev(s) = yv;

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

   [y_lvl, ~, Lcur, Lnxt] = predict_level_offset(st_lvl, s, n_slots, mean(t_vec));
   [y_mw, t_mw]           = predict_multi_window(st_mw, s, n_slots);
   [~, off]               = predict_level_offset(st_lvl, s, n_slots, mean(t_mw));
   y_mw_lvl = y_mw + off;
   [~, off2]              = predict_level_offset(st_lvl2, s, n_slots, mean(t_mw));
   y_mw_lvl2 = y_mw + off2;
   [y_mw2, ~]             = predict_multi_window(st_mw2, s, n_slots);

   F = [ t_vec, ...                       % 2 template T28
         t_vec + rhat, ...                % 3 T28 + AR4 iterated
         y_lvl, ...                       % 4 T28 + level offset
         y_mw, ...                        % 5 multi-window T
         y_mw_lvl, ...                    % 6 multi-window + level offset
         y_mw2, ...                       % 7 multi-window without the long tails
         y_mw_lvl2 ];                     % 8 multi-window + level offset, running state

   if ~isempty(hh)
      map = [2 3 4 5 6 7 8];
      for c = 1:size(F,2)
         fc = clamp_price(F(valid,c), [q1, q2]);
         E4(lin + (map(c)-1)*N3) = y_c - fc;
      end
      E4(lin) = y_c - clamp_price(yp_fc(u(valid)), [q1, q2]);   % model 1
   end
end
fprintf("atlas built: %s\n", mat2str(size(E4)));

%% ---------- TABLE 1: RMSE by lead ----------
h_show = [1 6 12 36 72 144 288];
h_lab  = {'5min','30min','1h','3h','6h','12h','24h'};
win_txt = sprintf("%s .. %s (%d days)", datestr(t_test(1),'yyyy-mm-dd'), ...
   datestr(t_test(end),'yyyy-mm-dd'), n_days);

Rpool = zeros(n_models, numel(h_show));
Rslot = zeros(n_models, numel(h_show));
for m = 1:n_models
   for k = 1:numel(h_show)
      x = double(squeeze(E4(:,h_show(k),:,m)));
      Rpool(m,k) = sqrt(mean(x(:).^2));
      Rslot(m,k) = median(sqrt(mean(x.^2,2)));
   end
end

fprintf("\n================ TABLE 1  RMSE by forecast lead ================\n");
fprintf("data %s | clamped | ingest-first | unit $/MWh\n", win_txt);
fprintf("each cell: pooled RMSE over all 288 slots x %d days [median over slots]\n", n_days);
fprintf("%-26s", "model");
for k = 1:numel(h_show), fprintf("%16s", h_lab{k}); end
fprintf("\n");
for m = 1:n_models
   fprintf("%-26s", names(m));
   for k = 1:numel(h_show)
      fprintf("%9.2f [%5.1f]", Rpool(m,k), Rslot(m,k));
   end
   fprintf("\n");
end
fprintf("%-26s", "clamped signal std");
fprintf("%16.2f", std(yc_seq));
fprintf("   <- an RMSE near this value carries no information\n");

fprintf("\nrelative to Template T28, pooled RMSE, positive is better:\n");
fprintf("%-26s", "model");
for k = 1:numel(h_show), fprintf("%16s", h_lab{k}); end
fprintf("\n");
for m = 1:n_models
   fprintf("%-26s", names(m));
   for k = 1:numel(h_show)
      fprintf("%15.1f%%", 100*(1 - Rpool(m,k)/Rpool(2,k)));
   end
   fprintf("\n");
end

%% ---------- TABLE 2: 2-hour block profile at long lead ----------
fprintf("\n================ TABLE 2  RMSE by time of day, lead 288 (24 h) ================\n");
E24 = double(squeeze(E4(:,n_slots,:,:)));
fprintf("%-12s", "hours");
for m = 1:n_models, fprintf("%12s", "m"+m); end
fprintf("%12s\n", "oracle-ish");
for b = 0:11
   sl = b*24 + (1:24);
   fprintf("%02d-%02d      ", b*2, b*2+2);
   for m = 1:n_models
      x = squeeze(E24(sl,:,m));
      fprintf("%12.1f", sqrt(mean(x(:).^2)));
   end
   fprintf("\n");
end
fprintf("\nmodel index: ");
for m = 1:n_models, fprintf("\n  m%d = %s", m, names(m)); end
fprintf("\n");

%% ---------- TABLE 3: level coefficients over time ----------
fprintf("\n================ TABLE 3  level recursion L(d) = c + b1*L(d-1) ================\n");
fprintf("refitted %d times (once per day)\n", n_trace);
fprintf("  c   mean %8.3f  std %8.3f  min %8.3f  max %8.3f\n", ...
   mean(c_trace(1:n_trace)), std(c_trace(1:n_trace)), min(c_trace(1:n_trace)), max(c_trace(1:n_trace)));
fprintf("  b1  mean %8.3f  std %8.3f  min %8.3f  max %8.3f\n", ...
   mean(b_trace(1:n_trace)), std(b_trace(1:n_trace)), min(b_trace(1:n_trace)), max(b_trace(1:n_trace)));
fprintf("  b1 is a shrinkage factor: 1 = trust yesterday fully, 0 = ignore it\n");
fprintf("  Lhat_24h = c + b1*(c + b1*L(d-1)) = %.2f + %.3f * L(d-1)\n", ...
   mean(c_trace(1:n_trace))*(1+mean(b_trace(1:n_trace))), mean(b_trace(1:n_trace))^2);

%% ---------- TABLE 4: win rate against T28 per day ----------
fprintf("\n================ TABLE 4  daily win rate against Template T28 ================\n");
fprintf("%-26s %10s %12s\n", "model", "wins/days", "median dRMSE");
dT = sqrt(squeeze(mean(E4(:,:,:,2).^2, 1)))';      % n_days x 288
for m = 1:n_models
   dM = sqrt(squeeze(mean(E4(:,:,:,m).^2, 1)))';
   wins = sum(sqrt(mean(dM.^2,2)) < sqrt(mean(dT.^2,2)));
   fprintf("%-26s %6d/%-3d %12.2f\n", names(m), wins, n_days, ...
      median(sqrt(mean(dM.^2,2))) - median(sqrt(mean(dT.^2,2))));
end

%% ---------- FIGURE: lead profile ----------
fh1 = figure('Name','Lead profile, new vs baseline','Position',[60 60 1180 520]);
tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
hx = (1:n_slots)'/12;
fig_models = [2 3 4 5 6 8];
for m = fig_models
   Rm = sqrt(mean(double(E4(:,:,:,m)).^2, 3));   % 288 slots x 288 leads, RMSE per cell
   Rl = mean(Rm, 1);                             % mean over slots of that RMSE
   nexttile(1); hold on; plot(hx, Rl, 'LineWidth', 1.3);
   nexttile(2); hold on; plot(hx, median(Rm,1), 'LineWidth', 1.3);
end
nexttile(1); grid on; xlim([0 24]); xticks(0:3:24);
xlabel('lead (hour)'); ylabel('RMSE ($/MWh)');
title('pooled RMSE vs lead', 'FontSize', 10);
legend(names(fig_models), 'Location', 'northwest', 'FontSize', 7);
nexttile(2); grid on; xlim([0 24]); xticks(0:3:24);
xlabel('lead (hour)'); ylabel('median over slots ($/MWh)');
title('median over slots', 'FontSize', 10);
title(tl, sprintf('Lead profile, %s, clamped, ingest-first', win_txt), 'FontSize', 11);

%% ---------- FIGURE: error heatmaps ----------
fh2 = figure('Name','RMSE surface, 288x288','Position',[100 100 1340 620]);
tl = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
colormap(turbo);
show = [2 3 5 6 8 4];
for m = show
   nexttile;
   imagesc(sqrt(sum(double(E4(:,:,:,m)).^2,3)/n_days), [0 60]);
   set(gca,'XTick',[1 72 144 216 288],'XTickLabel',{'0','6','12','18','24'});
   set(gca,'YTick',[1 72 144 216 288],'YTickLabel',{'0','6','12','18','24'});
   xlabel('lead (hour)'); ylabel('target slot (hour of day)');
   title(names(m), 'FontSize', 9);
end
cb = colorbar; cb.Layout.Tile = 'east';
cb.Label.String = 'RMSE ($/MWh, colour clipped at 60)';
title(tl, sprintf('RMSE(target slot, lead), 288x288, %d days', n_days), 'FontSize', 10);

%% ---------- export ----------
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
if ~exist(fig_dir, "dir")
   mkdir(fig_dir);
end
exportgraphics(fh1, fullfile(fig_dir, "lead_profile.png"), "Resolution", 130);
exportgraphics(fh2, fullfile(fig_dir, "rmse_surface.png"), "Resolution", 130);
save(fullfile(fig_dir, "atlas.mat"), "E4", "names", "Rpool", "Rslot", "c_trace", "b_trace", "n_trace", "-v7.3");
fprintf("\nfigures and atlas written to %s\n", fig_dir);
fprintf("### SCRIPT COMPLETED ###\n");
