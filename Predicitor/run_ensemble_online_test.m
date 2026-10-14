%% ============================================================
%  RUN_ENSEMBLE_ONLINE_TEST  Drive the combination layer day by day
%
%  The ensemble engine in Predicitor/Ensemble_predictor is what the controller
%  will call. This script runs it the way the controller would, in time order,
%  and checks three things:
%
%    1. it reproduces the offline combination numbers of run_ensemble_combos.m,
%       which are computed straight from the error atlas. The reference is read
%       from combos.mat, never written into this file, so the two scripts are
%       genuinely compared rather than one being copied into the other
%    2. the four-segment rolling-forward check of section 6.4: the ensemble has
%       to beat the best single model in every segment, not only on average
%    3. the 5 to 95 percent error band built from the trailing window covers
%       close to 90 percent of the next day's errors
%
%  Weights at day d are fitted on days d-n_w .. d-1 only. The block for day d-1
%  is complete before the first control step of day d, so nothing looks ahead.
%
%  Output: AEMO_Data/level_multiwindow_figs/ensemble_online.mat
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(predictor_root, "Shared"));
addpath(fullfile(predictor_root, "Ensemble_predictor"));

n_s = 288;  n_w = 28;  B = 48;
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
atlas_name = string(getenv("ATLAS_OUT"));
if strlength(atlas_name) == 0
   atlas_name = "atlas_v3.mat";
end
atlas_path = fullfile(fig_dir, atlas_name);
fprintf("loading %s\n", atlas_path);
S = load(atlas_path);
E4 = S.E4;  clear S
sz = size(E4);
n_d = sz(3);  n_m = sz(4);
reg = model_registry();
assert(n_m == numel(reg), 'atlas has %d models, the registry has %d', n_m, numel(reg));
names = string({reg.name});
fprintf("atlas %s | %d models | %d days\n", mat2str(sz), n_m, n_d);

% rules under test. The first column names the rule in this script, the second
% the name run_ensemble_combos.m gives the same rule, the third the settings.
rules = { "equal, all models",              "equal ALL",                            0, 0.0; ...
          "selective equal, K = 3",         "causal best-3 equal",                  3, 0.0; ...
          "selective equal, K = 5",         "causal best-5 equal",                  5, 0.0; ...
          "optimal weights, eps = 0.0",     "optimal weights, 4h blocks",           0, 0.0; ...
          "optimal weights, eps = 0.3",     "optimal weights, 4h blocks (shrink 0.3)", 0, 0.3 };
n_r = size(rules,1);
first_day = n_w + 1;

E_cmb = zeros(n_s, n_s, n_d, n_r, 'single');
st = init_ensemble(n_m, n_s, n_w, 'K_sel', 0, 'eps', 0.3, 'B', B);

fprintf("streaming %d days, weights fitted on %d trailing days, blocks of %d\n", ...
   n_d, n_w, B);
for d = 1:n_d
   E_day = single(E4(:, :, d, :));

   if d >= first_day
      Fd = reshape(double(E_day), [], n_m)';              % n_m x (slot*lead)
      w_eq = ones(n_m,1)/n_m;

      % rule one, equal weights over every model
      E_cmb(:, :, d, 1) = single(reshape(predict_ensemble(Fd, w_eq), n_s, n_s));

      % rule two, selective equal weight, chosen per lead. Row h of Wk holds the
      % model weights for lead h, and predict_ensemble wants one row per point,
      % where the points are ordered slot + n_s*(lead-1), so stack it n_s times.
      st_e = st;  st_e.eps = 0;
      for kk = [3 5]
         st_e.K_sel = kk;
         [Wk, ~] = combine_ensemble(st_e, (1:n_s)', "sel");
         if isempty(Wk), continue; end
         % Row h of Wk holds the model weights for lead h. predict_ensemble
         % wants one row per point, and the points are ordered slot fastest,
         % lead slowest, so every row of Wk must be repeated n_s times in place.
         % repmat would tile the whole table instead, which shifts every weight
         % to the wrong lead.
         Wbig = repelem(Wk, n_s, 1);                      % (slot*lead) x n_m
         ri = 1 + (kk == 3) + (kk == 5)*2;                % 2 for K=3, 3 for K=5
         E_cmb(:, :, d, ri) = single(reshape(predict_ensemble(Fd, Wbig), n_s, n_s));
      end

      % rule three, inverse covariance, one fit per lead block
      eps_list = [0.0 0.3];
      for ib = 1:st.n_blk
         leads = st.blocks{ib};
         Fb = reshape(double(E_day(:, leads, :)), [], n_m)';
         for e = 1:2
            st_e = st;  st_e.eps = eps_list(e);  st_e.K_sel = 0;
            [~, w] = combine_ensemble(st_e, leads(1), "opt");
            if isempty(w), w = w_eq; end
            ri = 3 + e;
            E_cmb(:, leads, d, ri) = single(reshape(predict_ensemble(Fb, w), n_s, numel(leads)));
         end
      end
   end

   st = update_ensemble(st, d, E_day);
   if mod(d, 20) == 0
      fprintf("  day %3d/%d\n", d, n_d);
   end
end

%% ---- pooled RMSE per rule ----
pooled = zeros(n_r,1);
for ri = 1:n_r
   V = double(E_cmb(:, :, first_day:end, ri));
   pooled(ri) = sqrt(mean(V(:).^2));
end
Rall = zeros(n_m,1);
for m = 1:n_m
   V = double(E4(:, :, first_day:end, m));
   Rall(m) = sqrt(mean(V(:).^2));
end
[best_single, i_best] = min(Rall);

fprintf("\n=========== pooled RMSE over days %d to %d ===========\n", first_day, n_d);
fprintf("%-30s %10s %12s\n", "rule", "$/MWh", "vs best single");
for ri = 1:n_r
   fprintf("%-30s %10.3f %11.2f%%\n", rules{ri,1}, pooled(ri), ...
      100*(pooled(ri)/best_single - 1));
end
fprintf("%-30s %10.3f\n", "best single: " + names(i_best), best_single);

%% ---- criterion: agreement with the offline combination study ----
combo_path = fullfile(fig_dir, "combos.mat");
assert(exist(combo_path, 'file') == 2, ...
   'combos.mat is missing, run run_ensemble_combos.m first');
C = load(combo_path);
cn = string(C.comb_name);  cv = C.comb_all(:);
fprintf("\nagainst run_ensemble_combos.m, the same rules computed offline:\n");
worst = 0;  n_cmp = 0;
for ri = 1:n_r
   j = find(cn == rules{ri,2}, 1);
   if isempty(j)
      fprintf("  %-30s no matching offline row for ""%s""\n", rules{ri,1}, rules{ri,2});
      continue
   end
   d_ri = abs(pooled(ri) - cv(j));
   worst = max(worst, d_ri);  n_cmp = n_cmp + 1;
   fprintf("  %-30s online %7.3f  offline %7.3f  diff %6.3f\n", ...
      rules{ri,1}, pooled(ri), cv(j), d_ri);
end
fprintf("  %d rules compared, worst difference %.3f $/MWh\n", n_cmp, worst);
assert(n_cmp >= 4, 'fewer than four rules could be matched');
assert(worst < 0.1, 'the online engine disagrees with the offline study by %.3f', worst);
fprintf("  ONLINE ENGINE MATCHES THE OFFLINE STUDY\n");

%% ---- four-segment rolling forward ----
seg = round(linspace(first_day, n_d+1, 5));
fprintf("\nfour-segment rolling forward, pooled RMSE per segment\n");
fprintf("%-30s", "rule");
for s = 1:4, fprintf("%12s", sprintf("seg %d", s)); end
fprintf("\n");
seg_ens = zeros(n_r,4);  seg_best = zeros(1,4);
for s = 1:4
   idx = seg(s):(seg(s+1)-1);
   for ri = 1:n_r
      V = double(E_cmb(:, :, idx, ri));
      seg_ens(ri,s) = sqrt(mean(V(:).^2));
   end
   best = inf;
   for m = 1:n_m
      V = double(E4(:, :, idx, m));
      best = min(best, sqrt(mean(V(:).^2)));
   end
   seg_best(s) = best;
end
for ri = 1:n_r
   fprintf("%-30s", rules{ri,1});
   for s = 1:4, fprintf("%12.3f", seg_ens(ri,s)); end
   fprintf("\n");
end
fprintf("%-30s", "best single model");
for s = 1:4, fprintf("%12.3f", seg_best(s)); end
fprintf("\n%-30s", "best rule beats best single");
for s = 1:4
   fprintf("%12s", string(min(seg_ens(:,s)) < seg_best(s)));
end
fprintf("\n");

%% ---- quantile band from the trailing window ----
[sorted_pool, i_rule] = sort(pooled);
ri = i_rule(1);                            % the best rule of the five
inside_lead = zeros(n_s,1);  cnt_lead = 0;
for d = first_day:n_d
   lo_idx = max(first_day, d - n_w);
   past = double(E_cmb(:, :, lo_idx:d-1, ri));        % slot x lead x day
   P = reshape(permute(past, [1 3 2]), [], n_s);      % (slot*day) x lead
   q = quantile(P, [0.05 0.95], 1);                   % 2 x lead
   e = double(E_cmb(:, :, d, ri));                    % slot x lead
   ok = e >= repmat(q(1,:), n_s, 1) & e <= repmat(q(2,:), n_s, 1);
   inside_lead = inside_lead + sum(ok, 1)';
   cnt_lead = cnt_lead + n_s;
end
cov_by_lead = inside_lead / cnt_lead;
cov_all = mean(cov_by_lead);
fprintf("\n5 to 95 percent band from the trailing window, rule %s\n", rules{ri,1});
fprintf("  coverage %.1f%% (target 90.0%%)\n", 100*cov_all);
fprintf("  narrowest %.1f%% at lead %d, widest %.1f%% at lead %d\n", ...
   100*min(cov_by_lead), find(cov_by_lead == min(cov_by_lead), 1), ...
   100*max(cov_by_lead), find(cov_by_lead == max(cov_by_lead), 1));

% The per-cell error surfaces of every rule are saved so the profiles and the
% heatmaps can be built without re-running the online engine.
save(fullfile(fig_dir, "ensemble_online.mat"), "rules", "pooled", "Rall", ...
   "seg_ens", "seg_best", "seg", "cov_all", "cov_by_lead", "names", ...
   "first_day", "n_d", "E_cmb", "-v7.3");
fprintf("\nwritten to %s\n", fullfile(fig_dir, "ensemble_online.mat"));
fprintf("### SCRIPT COMPLETED ###\n");
