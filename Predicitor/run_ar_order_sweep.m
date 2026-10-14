%% ============================================================
%  RUN_AR_ORDER_SWEEP  AR order p = 1 .. 48 under the unified protocol
%
%  Model: M4, the rolling template T28 plus an iterated AR(p) on the residual.
%
%     r(k)     = y(k) - T_{k-1}(s(k))
%     r_hat(s) = phi' [ r_hat(s-1); ...; r_hat(s-p) ]     s = 1..n_s
%     y_hat(h) = T(u(k,h)) + r_hat(h)
%
%  The recursion is started from the newest p residuals, so with the backward
%  initial outputs v_0 = r(k), v_-1 = r(k-1), ... it is exactly an AR(p) filter
%  and one filter call replaces a 288-iteration loop. The two forms were checked
%  against each other on random coefficients, agreement 2.8e-17 at p = 4.
%
%  PROTOCOL is the one of run_full_ensemble_test.m. p = 4 must therefore
%  reproduce the T28 + AR4 column of the saved atlas, and the script asserts it.
%
%  Only the (slot, lead) sum of squares is accumulated, not a 4-D atlas: the
%  sweep needs the RMSE surface per order, not the individual errors.
%
%  Output: AEMO_Data/level_multiwindow_figs/ar_sweep.mat
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(project_root, "MPC", "First_Version_MPC"));
addpath(predictor_root);
addpath(fullfile(predictor_root, "Shared"));
addpath(fullfile(predictor_root, "PriceClamp"));

n_s = 288;  lam = 0.98;  delta = 100;  n_T = 28;
n_q = 30;  n_d = 120;
p_list = 1:48;

train_start = datetime(2025,9,1,0,5,0);
train_end   = datetime(2026,2,1,0,0,0);
test_start  = datetime(2026,2,1,0,5,0);
test_end    = train_end + days(n_d);
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

% ---- causal clamp thresholds, one pair per test day, as in the atlas --------
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
fprintf("warm-up %d days | targets %d days | clamped | ingest-first\n", n_train/n_s, n_d);

h_all = (1:n_s)';
n_p = numel(p_list);
Rp_all = zeros(n_p,1);          % whole-atlas pooled RMSE per order
Rp_lead = zeros(n_p, n_s);      % per-lead RMSE, pooled over slots
Rp_slot = zeros(n_p, n_s);      % per-slot RMSE, pooled over leads
ss_by_p = cell(n_p,1);          % keep the surfaces for the cross-check

for pi = 1:n_p
   p = p_list(pi);
   t0 = tic;

   T_sum = zeros(n_s,1); T_cnt = zeros(n_s,1); T_win = zeros(n_s,n_T);
   phi = zeros(p,1); Pphi = delta*eye(p); hist = zeros(p,1); nhist = 0;
   ss = zeros(n_s, n_s);

   % ---- warm-up ----
   for idx = 1:n_train
      s = slot_seq(idx);  yv = y_seq(idx);
      if T_cnt(s) == 0
         T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
      else
         r = yv - T_sum(s)/T_cnt(s);
         if nhist >= p
            [phi, Pphi] = rls_vector_step(r, hist, phi, Pphi, lam);
         end
         hist = [r; hist(1:end-1)];  nhist = min(nhist+1, p);
         col = mod(T_cnt(s), n_T)+1;
         T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
         T_cnt(s) = min(T_cnt(s)+1, n_T);
      end
   end

   % ---- origin loop ----
   for idx = i_start:n_seq
      s = slot_seq(idx);
      u = target_slots(s, n_s, n_s);
      jtest_all = idx + h_all - n_train;
      valid = (jtest_all >= 1) & (jtest_all <= n_test);
      h_used = h_all(valid);  jtest = jtest_all(valid);
      d_tgt = floor((jtest-1)/n_s) + 1;
      q1 = q1_seq(jtest);  q2 = q2_seq(jtest);  y_c = yc_seq(jtest);

      % ingest y(idx)
      yv = y_seq(idx);
      if T_cnt(s) == 0
         T_sum(s) = yv;  T_win(s,1) = yv;  T_cnt(s) = 1;
      else
         r = yv - T_sum(s)/T_cnt(s);
         if nhist >= p
            [phi, Pphi] = rls_vector_step(r, hist, phi, Pphi, lam);
         end
         hist = [r; hist(1:end-1)];  nhist = min(nhist+1, p);
         col = mod(T_cnt(s), n_T)+1;
         T_sum(s) = T_sum(s) - T_win(s,col) + yv;  T_win(s,col) = yv;
         T_cnt(s) = min(T_cnt(s)+1, n_T);
      end

      % forecast
      T_tgt = T_sum(u) ./ max(T_cnt(u),1);
      if nhist >= p
         a_filt = [1; -phi(:)];
         zi = filtic(1, a_filt, hist);
         r_hat = filter(1, a_filt, zeros(n_s,1), zi);
      else
         r_hat = zeros(n_s,1);
      end

      if ~isempty(h_used)
         e = y_c - clamp_price(T_tgt(valid) + r_hat(valid), [q1, q2]);
         lin = u(valid) + n_s*(h_used-1);
         ss(lin) = ss(lin) + e.^2;
      end
   end

   R = sqrt(ss / n_d);
   Rp_lead(pi,:) = mean(R, 1);
   Rp_slot(pi,:) = mean(R, 2)';
   Rp_all(pi) = sqrt(mean(ss(:)) / n_d);
   ss_by_p{pi} = R;
   fprintf("p = %2d  whole atlas %7.3f  |  1h %7.3f  6h %7.3f  24h %7.3f  |  %.0f s\n", ...
      p, Rp_all(pi), Rp_lead(pi,12), Rp_lead(pi,72), Rp_lead(pi,288), toc(t0));
end
fprintf("clamped signal std %.2f $/MWh\n", std(yc_seq));

%% ---------- cross-check against the saved atlas ----------
atlas_path = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs", "atlas_full.mat");
reg = model_registry();
i_ref = model_index("T28_AR4");
fprintf("\ncross-check: p = 4 must reproduce atlas column %d (%s)\n", ...
   i_ref, reg(i_ref).name);
M = matfile(atlas_path);
E_ref = double(M.E4(:,:,:,i_ref));
R_ref = sqrt(mean(E_ref.^2, 3));
i4 = find(p_list == 4, 1);
d_max = max(abs(ss_by_p{i4} - R_ref), [], 'all');
fprintf("  max |sweep surface - atlas surface| = %.3e $/MWh\n", d_max);
fprintf("  whole atlas  sweep %.3f  atlas %.3f\n", Rp_all(i4), sqrt(mean(E_ref(:).^2)));
assert(d_max < 1e-2, ...
   'the sweep protocol no longer matches the atlas: %.3e $/MWh apart', d_max);
fprintf("  PROTOCOL MATCHES\n");

%% ---------- report ----------
[best_all, ib] = min(Rp_all);
h_show = [1 6 12 36 72 144 288];
h_lab  = {'5min','30min','1h','3h','6h','12h','24h'};
fprintf("\n%-6s %11s", "p", "whole atlas");
for k = 1:numel(h_show), fprintf("%10s", h_lab{k}); end
fprintf("\n");
for pi = 1:n_p
   fprintf("%-6d %11.3f", p_list(pi), Rp_all(pi));
   for k = 1:numel(h_show), fprintf("%10.3f", Rp_lead(pi,h_show(k))); end
   fprintf("\n");
end
fprintf("\nbest whole atlas: p = %d at %.3f $/MWh\n", p_list(ib), best_all);
for k = 1:numel(h_show)
   [v, ii] = min(Rp_lead(:,h_show(k)));
   fprintf("  best at lead %-6s p = %2d  %.3f\n", h_lab{k}, p_list(ii), v);
end

fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
if ~exist(fig_dir, "dir"), mkdir(fig_dir); end
save(fullfile(fig_dir, "ar_sweep.mat"), "p_list", "Rp_all", "Rp_lead", "Rp_slot", ...
   "ss_by_p", "q_by_day", "-v7.3");
fprintf("\nsweep written to %s\n", fullfile(fig_dir, "ar_sweep.mat"));
fprintf("### SCRIPT COMPLETED ###\n");
