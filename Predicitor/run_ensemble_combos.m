%% ============================================================
%  RUN_ENSEMBLE_COMBOS  Convex combination study on a saved error atlas
%
%  Loads AEMO_Data/level_multiwindow_figs/atlas_full.mat, written by
%  run_full_ensemble_test.m, and redoes the combination part only. Split out
%  so the combinations can be reworked without re-streaming 153 warm-up days
%  plus 120 test days.
%
%  Scoring identity used throughout, valid for any convex weight vector:
%     f_c = sum_m w_m f_m  with  sum_m w_m = 1
%     =>  e_c = y - f_c = sum_m w_m (y - f_m) = sum_m w_m e_m
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(predictor_root, "Shared"));
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");

atlas_name = string(getenv("ATLAS_OUT"));
if strlength(atlas_name) == 0
   atlas_name = "atlas_full.mat";
end
S = load(fullfile(fig_dir, atlas_name));
E4 = S.E4;  names = S.names;  Rpool = S.Rpool;  Rall = S.Rall;
[n_s, ~, n_d, n_models] = size(E4);
h_show = [1 6 12 36 72 144 288];
h_lab  = {'5min','30min','1h','3h','6h','12h','24h'};

n_w = 28;  blk = 48;  n_blk = n_s / blk;
sub_slots = 1:6:n_s;
sub_leads = 1:6:n_s;

% Every causal rule leaves days 1..n_w unwritten, because no trailing window
% exists there. Scoring the whole array then averages in n_w days of zeros and
% understates the RMSE by sqrt((n_d-n_w)/n_d), about 12 percent here, while a
% rule that writes every day (fixed equal weights) is not diluted at all. Every
% rule is therefore scored on the same day range, the one where weights exist.
d_score = (n_w+1):n_d;
R = @(x) sqrt(mean(reshape(x(:, :, d_score), [], 1).^2));
surf_of = @(Ec) sqrt(mean(Ec(:, :, d_score).^2, 3));

fprintf("atlas %s | %d models | %d days | weight window %d d | lead blocks %d\n", ...
   mat2str(size(E4)), n_models, n_d, n_w, n_blk);

% ---- how much does the template need averaging over slots? ---------------
i_mw_run = model_index("MW_run");
rms_slots = squeeze(sqrt(mean(double(E4(:,:,:,i_mw_run)).^2, 1)));   % lead x day
fprintf("%s lead 1 day 1 RMSE %.2f\n", names(i_mw_run), rms_slots(1,1));

comb_name = {};  comb_all = [];  comb_surf = {};  comb_extra = {};

%% 1. fixed equal weights over chosen subsets
% Model sets are named, not numbered, so appending a model to the registry
% cannot change what "ALL" means here.
subsets = { "ALL",       1:n_models; ...
            "CHAMPS2 (anchor, MWrun)",          model_index(["anchor_mix" "MW_run"]); ...
            "CHAMPS3 (anchor, MWrun, T28+DMS4)", model_index(["anchor_mix" "MW_run" "T28_DMS4"]); ...
            "GOOD5 (AR4,DMS4,anchor,MW,MWrun)", model_index(["T28_AR4" "T28_DMS4" "anchor_mix" "MW" "MW_run"]); ...
            "SHORTLONG (AR4,MWrun)",            model_index(["T28_AR4" "MW_run"]); ...
            "TEMPLATES (T28,MW,MWrun)",         model_index(["T28" "MW" "MW_run"]) };
for si = 1:size(subsets,1)
   sub = subsets{si,2};
   Ec = zeros(n_s, n_s, n_d, 'single');
   for m = sub
      Ec = Ec + single(double(E4(:,:,:,m)) / numel(sub));
   end
   comb_name{end+1} = "equal " + subsets{si,1};
   comb_all(end+1) = R(Ec);  comb_surf{end+1} = surf_of(Ec);  comb_extra{end+1} = "";
   clear Ec
end

%% 2. causal best-k equal, chosen per lead from the trailing window
Mrr = zeros(n_s, n_d, n_models);
for m = 1:n_models
   Mrr(:,:,m) = squeeze(sqrt(mean(double(E4(:,:,:,m)).^2, 1)));
end
pick_log = zeros(n_s, n_d, n_models);
for kbest = [2 3 5]
   Ec = zeros(n_s, n_s, n_d, 'single');
   for h = 1:n_s
      tr  = squeeze(Mrr(h, :, :));
      trs = filter(ones(n_w,1)/n_w, 1, tr, [], 1);
      for d = n_w+1:n_d
         % trs(d,:) is the mean over days d-n_w+1 .. d, which INCLUDES the day
         % being scored. Selecting models with the scored day's own error is
         % look-ahead; the trailing window must stop at d-1.
         [~, ord] = sort(trs(d-1,:));
         sel = ord(1:kbest);
         Ec(:, h, d) = single(sum(double(E4(:, h, d, sel)), 4) / kbest);
         if kbest == 3
            pick_log(h, d, sel) = pick_log(h, d, sel) + 1;
         end
      end
   end
   comb_name{end+1} = sprintf("causal best-%d equal", kbest);
   comb_all(end+1) = R(Ec);  comb_surf{end+1} = surf_of(Ec);  comb_extra{end+1} = "";
   clear Ec
end

%% 3. causal optimal weights (Bates-Granger), fitted on subsampled cells and
%     applied to every lead; shrinkage pulls the covariance toward its diagonal
for lam_s = [0.0 0.3]
   for spec = 1:2
      if spec == 1
         sets = {1:n_s};  label = "optimal weights, whole atlas";
      else
         sets = arrayfun(@(b) (b*blk+1):((b+1)*blk), 0:n_blk-1, 'UniformOutput', false);
         label = "optimal weights, 4h blocks";
      end
      if lam_s > 0
         label = label + sprintf(" (shrink %.1f)", lam_s);
      end
      Ec = zeros(n_s, n_s, n_d, 'single');
      for ls = 1:numel(sets)
         all_leads = sets{ls};
         leads_fit = all_leads(1:6:end);        % subsample within this lead set
         for d = n_w+1:n_d
            past = double(E4(sub_slots, leads_fit, d-n_w:d-1, :));
            X = reshape(past, [], n_models);
            Sx = (X' * X) / size(X,1);
            Sx = (1-lam_s)*Sx + lam_s*(trace(Sx)/n_models)*eye(n_models);
            w = Sx \ ones(n_models,1);  w = w / sum(w);
            blk4 = squeeze(double(E4(:, all_leads, d, :)));
            Ec(:, all_leads, d) = single(reshape(reshape(blk4, [], n_models) * w, ...
               n_s, numel(all_leads)));
         end
      end
      comb_name{end+1} = label;
      comb_all(end+1) = R(Ec);  comb_surf{end+1} = surf_of(Ec);  comb_extra{end+1} = "";
      clear Ec blk4 past X
   end
end

%% 4. causal two-model blends, with the weight trace kept for inspection
pair_specs = { ["anchor_mix" "MW_run"],       "anchor + MWrun"; ...
               ["anchor_mix" "T28_AR4"],      "anchor + AR4"; ...
               ["anchor_mix" "MW"],           "anchor + MW"; ...
               ["MW_run" "T28_AR4"],          "MWrun + AR4" };
pairs = cell(size(pair_specs,1),2);
for pi = 1:size(pair_specs,1)
   pairs{pi,1} = model_index(pair_specs{pi,1});
   pairs{pi,2} = pair_specs{pi,2};
end
wfits = cell(size(pairs,1),1);
for pi = 1:size(pairs,1)
   pair = pairs{pi,1};
   Ec = zeros(n_s, n_s, n_d, 'single');
   Wt = zeros(n_s, 2, n_d);
   for ls = 0:n_blk-1
      leads = ls*blk + (1:blk);
      for d = n_w+1:n_d
         past = double(E4(sub_slots, leads, d-n_w:d-1, pair));
         X = reshape(past, [], 2);
         Sx = (X' * X) / size(X,1);
         w = Sx \ ones(2,1);  w = w / sum(w);
         Wt(leads, :, d) = repmat(w', blk, 1);
         blk2 = squeeze(double(E4(:, leads, d, pair)));
         Ec(:, leads, d) = single(reshape(reshape(blk2, [], 2) * w, n_s, numel(leads)));
      end
   end
   comb_name{end+1} = "causal 2-model blend (" + pairs{pi,2} + ")";
   comb_all(end+1) = R(Ec);  comb_surf{end+1} = surf_of(Ec);  comb_extra{end+1} = "";
   wfits{pi} = Wt;
   clear Ec blk2
end
clear past X

%% ---- report ----
fprintf("\n================ combinations ================\n");
fprintf("%-44s %11s", "combination", "whole atlas");
for k = 1:numel(h_show), fprintf("%10s", h_lab{k}); end
fprintf("\n");
for c = 1:numel(comb_name)
   fprintf("%-44s %11.2f", comb_name{c}, comb_all(c));
   for k = 1:numel(h_show)
      fprintf("%10.2f", mean(comb_surf{c}(:, h_show(k))));
   end
   fprintf("\n");
end
fprintf("\n%-44s %11.2f", "BEST single model (anchor-mix)", min(Rall));
for k = 1:numel(h_show), fprintf("%10.2f", min(Rpool(:,k))); end
fprintf("\n");

fprintf("\nverbose single models, for reference:\n");
fprintf("%-26s %11s", "model", "whole atlas");
for k = 1:numel(h_show), fprintf("%10s", h_lab{k}); end
fprintf("\n");
for m = 1:n_models
   fprintf("%-26s %11.2f", names(m), Rall(m));
   for k = 1:numel(h_show), fprintf("%10.2f", Rpool(m,k)); end
   fprintf("\n");
end

fprintf("\nbest of everything at each lead:\n");
for k = 1:numel(h_show)
   sv = Rpool(:, k);  [sv_min, sv_i] = min(sv);
   cv = cellfun(@(Sm) mean(Sm(:, h_show(k))), comb_surf);
   [cv_min, cv_i] = min(cv);
   if cv_min < sv_min
      fprintf("  lead %-6s %8.2f  %-44s (best single %8.2f %s)\n", ...
         h_lab{k}, cv_min, comb_name{cv_i}, sv_min, names(sv_i));
   else
      fprintf("  lead %-6s %8.2f  %-44s\n", h_lab{k}, sv_min, names(sv_i));
   end
end
[av, ai] = min(comb_all);
fprintf("  whole atlas %8.2f  %s\n", av, comb_name{ai});

%% ---- which models the causal best-3 actually picks ----
fprintf("\nwhich models the causal best-3 rule keeps (share of the 120 days):\n");
for m = 1:n_models
   sel = squeeze(pick_log(:,:,m));
   used = mean(sel > 0, 2) * 100;      % percent of days picked, by lead
   fprintf("  %-26s lead1 %5.1f%%   lead72 %5.1f%%   lead288 %5.1f%%\n", ...
      names(m), used(1), used(72), used(288));
end

%% ---- weight trace of the two-model blends ----
fprintf("\nweight traces, mean over the 120 scored days:\n");
for pi = 1:size(pairs,1)
   Wt = wfits{pi};
   fprintf("  %-20s  lead  1: %.3f / %.3f    lead 72: %.3f / %.3f    lead 288: %.3f / %.3f\n", ...
      pairs{pi,2}, mean(Wt(1,1,:)), mean(Wt(1,2,:)), mean(Wt(72,1,:)), mean(Wt(72,2,:)), ...
      mean(Wt(288,1,:)), mean(Wt(288,2,:)));
end

%% ---- figure: everything at long lead vs the best single model ----
fig_dir2 = fig_dir;
fh = figure('Name','Combination vs champion','Position',[70 70 1240 470]);
tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
hx = (1:n_s)'/12;
cn = string(comb_name);
showc = [find(contains(cn, "causal best-3")), ...
         find(contains(cn, "causal best-5")), ...
         find(contains(cn, "2-model blend (anchor + AR4)")), ...
         find(contains(cn, "2-model blend (anchor + MWrun)")), ...
         find(contains(cn, "equal ALL"))];
showc = showc(1:min(5,numel(showc)));
i_anchor = model_index("anchor_mix");
nexttile(1); hold on;
plot(hx, mean(surf_of(double(E4(:,:,:,i_anchor))),1), 'k-', 'LineWidth', 2);
for c = showc
   plot(hx, mean(comb_surf{c},1), 'LineWidth', 1.2);
end
hold off; grid on; xlim([0 24]); xticks(0:3:24); ylim([0 60]);
xlabel('lead (hour)'); ylabel('pooled RMSE ($/MWh)');
title('pooled over 288 slots', 'FontSize', 10);
legend([{'Anchor-mix (best single)'}, comb_name(showc)], 'Location','northwest','FontSize',7);
nexttile(2); hold on;
plot(hx, median(surf_of(double(E4(:,:,:,i_anchor))),1), 'k-', 'LineWidth', 2);
for c = showc
   plot(hx, median(comb_surf{c},1), 'LineWidth', 1.2);
end
hold off; grid on; xlim([0 24]); xticks(0:3:24); ylim([0 60]);
xlabel('lead (hour)'); ylabel('median over slots ($/MWh)');
title('median over 288 slots', 'FontSize', 10);
title(tl, 'Combinations against the best single model', 'FontSize', 12);
subtitle(tl, sprintf("VIC1 5-min RRP | %d days | clamped | convex weights fitted on a trailing %d-day window", ...
   n_d, n_w), 'FontSize', 8);
exportgraphics(fh, fullfile(fig_dir2, "ensemble_combo.png"), "Resolution", 130);

save(fullfile(fig_dir, "combos.mat"), "comb_name", "comb_all", "comb_surf", ...
   "pick_log", "wfits", "pairs", "-v7.3");
fprintf("\nfigure and combination results written to %s\n", fig_dir);
fprintf("### COMBOS COMPLETED ###\n");
