%% ============================================================
%  DIAGNOSE_FIGS  Two questions raised by reading the 60-day figures
%
%  Q1. Why do M1, M3, M5, M7 and M13 show blocky or banded structure in F1?
%      Hypothesis: those models anchor on the price AT THE ORIGIN, and the
%      origin's distance in days from the target is
%         dayAhead(u, h) = floor((u - 1 + h) / 288)
%      which steps by one every 288 leads. Inside one lead column it is a step
%      function of u with a SINGLE jump, at u* = 289 - mod(h, 288). If the
%      hypothesis holds, each column has one dominant jump and it sits there.
%
%  Q2. Why does F2b show so little significance where F2a shows a large
%      difference? Hypothesis: cell_dm averages over days without omitnan, so a
%      single missing official day turns the whole cell into NaN and the cell is
%      then reported as unresolved rather than as incomparable.
%
%  Run: matlab -batch "run('...\diagnose_figs.m')"
% ============================================================
clear; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(predictor_root);  addpath(fullfile(predictor_root, "Shared"));
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");

S = load(fullfile(fig_dir, "atlas_60d.mat"), "n_d", "n_h", "keys", "names", ...
   "lead_min", "h_all", "d_score");
O = load(fullfile(fig_dir, "official_60d.mat"), "O4", "E4_off", "SRC4", "AGE4");
A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
n_s = 288;                       % slots per day, fixed everywhere in the project
n_h = S.n_h;  n_d = S.n_d;
h_all = double(S.h_all(:));  lead_min = double(S.lead_min(:));  ds = S.d_score;
keys = string(S.keys(:));
dAhead = @(u, h) floor((u - 1 + h) / n_s);

%% ---- Q1  one jump per column, at the predicted place --------------------
fprintf("=== Q1  is the block structure dayAhead? ===\n");
fprintf("For each model and each sampled lead column: the largest single-step jump\n");
fprintf("in R as the target slot sweeps the day, against the predicted position.\n\n");
probe_cols = [1 6 12 24 58 106 160 202 260 320 376];
probe_cols = probe_cols(probe_cols <= n_h);
fprintf("%-24s %8s %10s %10s %10s %10s\n", "model", "col", "lead h", "pred u*", "meas u*", "jump/med");
for k = ["persistence" "theta_y" "carry_forward" "CF_DMS4" "kalman_harm"]
   j = find(keys == k, 1);
   E = double(A.E4(:, :, ds, j));
   R = sqrt(mean(E.^2, 3));
   clear E
   n_hit = 0;  n_probe = 0;
   for c = probe_cols
      col = R(:, c);
      d = abs(diff(col));
      [mx, iu] = argmax(d);
      pred = 289 - mod(h_all(c), n_s);
      if pred == 289, pred = 288; end
      med = median(d(d > 0));
      if c <= 12 || n_probe < 6
         fprintf("%-24s %8d %10.0f %10d %10d %10.2f\n", k, c, lead_min(c), pred, iu, mx/max(med,eps));
      end
      n_probe = n_probe + 1;
      if abs(iu - pred) <= 2, n_hit = n_hit + 1; end
   end
   fprintf("%-24s  largest jump lands within 2 slots of the prediction in %d of %d sampled columns\n\n", ...
      k, n_hit, n_probe);
end

% How much of R does dayAhead explain, per model, over the whole surface?
fprintf("variance of R explained by dayAhead alone, per model:\n");
U = (1:n_s)';
DA = zeros(n_s, n_h);
for c = 1:n_h
   DA(:, c) = dAhead(U, h_all(c));
end
for j = 1:numel(keys)
   E = double(A.E4(:, :, ds, j));
   R = sqrt(mean(E.^2, 3));
   clear E
   gm = mean(R(:));
   ss = sum((R(:) - gm).^2);
   ssb = 0;
   for g = unique(DA(:))'
      m = (DA == g);
      ssb = ssb + sum(m(:)) * (mean(R(m)) - gm)^2;
   end
   fprintf("  %-24s %6.1f%%\n", keys(j), 100*ssb/ss);
   clear R
end

%% ---- Q2  the official comparison set -------------------------------------
fprintf("\n=== Q2  what can actually be compared against the official ===\n");
O4 = O.O4;  E4_off = O.E4_off;
have = isfinite(O4(:, :, ds));                 % slot x lead x scored day
cnt = squeeze(sum(have, 3));                   % days present, per cell
n_cells = n_s*n_h;
fprintf("cells (slot, lead): %d\n", n_cells);
fprintf("  official complete over all %d scored days: %d (%.2f%%)\n", ...
   numel(ds), sum(cnt(:) == numel(ds)), 100*sum(cnt(:) == numel(ds))/n_cells);
fprintf("  official present but incomplete:            %d (%.2f%%)\n", ...
   sum(cnt(:) > 0 & cnt(:) < numel(ds)), 100*sum(cnt(:) > 0 & cnt(:) < numel(ds))/n_cells);
fprintf("  official absent on every scored day:        %d (%.2f%%)\n", ...
   sum(cnt(:) == 0), 100*sum(cnt(:) == 0)/n_cells);

% The cell_dm the figures use averages without omitnan, so one missing day
% poisons the cell. Show how many cells that affects.
sq_nan = squeeze(any(~isfinite(E4_off(:, :, ds)), 3));
fprintf("\n  cells F2a can colour: %d, of which the DM sees a NaN: %d\n", ...
   sum(cnt(:) > 0), sum(sq_nan(:) & cnt(:) > 0));

% For the model the reader asked about, compare the two verdicts at long leads.
kshow = find(keys == "carry_forward", 1);
E5 = double(A.E4(:, :, ds, kshow));
R5 = sqrt(mean(E5.^2, 3));
Roff = sqrt(mean(E4_off(:, :, ds).^2, 3, 'omitnan'));
D5 = R5 - Roff;
fprintf("\n  %s against the official, by lead:\n", keys(kshow));
fprintf("  %10s %10s %10s %12s %12s\n", "lead", "comparable", "lower", "diff med", "NaN days>0");
for c = [1 12 18 30 58 106 202 300 376]
   if c > n_h, continue; end
   tot = sum(cnt(:, c) > 0);
   lo = sum(D5(cnt(:, c) == numel(ds), c) < 0);
   md = median(D5(cnt(:, c) > 0, c), 'omitnan');
   nz = sum(sq_nan(:, c) & cnt(:, c) > 0);
   fprintf("  %10.1f %10d %10d %12.3f %12d\n", lead_min(c)/60, tot, lo, md, nz);
end
clear E5

fprintf("\n### DIAGNOSIS DONE ###\n");

function [mx, i] = argmax(v)
   [mx, i] = max(v);
end
