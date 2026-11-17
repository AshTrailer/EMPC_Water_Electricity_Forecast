%% The two rankings behind figure six, printed so the report quotes exact ranks.
clear; clc;
project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
S = load(fullfile(fig_dir, "atlas_v4.mat"), "E4", "names", "d_score");
E4 = S.E4;  names = string(S.names(:));  d = S.d_score;
[n_s, n_h, ~, n_m] = size(E4);

Rd = zeros(n_s, n_h, n_m);
pooled = zeros(n_m, 1);
for m = 1:n_m
   v = double(E4(:, :, d, m)).^2;
   Rd(:, :, m) = sqrt(mean(v, 3));
   pooled(m) = sqrt(mean(v, "all"));
end
[~, wm] = min(Rd, [], 3);
wins = zeros(n_m, 1);
for m = 1:n_m, wins(m) = sum(sum(wm == m)); end

[~, rp] = sort(pooled, "ascend");
[~, rw] = sort(wins, "descend");
rank_p = zeros(n_m,1);  rank_w = zeros(n_m,1);
rank_p(rp) = 1:n_m;  rank_w(rw) = 1:n_m;

fprintf("%-26s %10s %6s %9s %6s %6s\n", "model", "pooled", "rank", "cells", "rank", "moved");
[~, om] = sort(abs(rank_p - rank_w), "descend");
for m = om'
   fprintf("%-26s %10.2f %6d %9d %6d %6d\n", names(m), pooled(m), rank_p(m), ...
      wins(m), rank_w(m), rank_w(m) - rank_p(m));
end
fprintf("\nmodels that keep their rank: %d of %d\n", sum(rank_p == rank_w), n_m);
fprintf("mean absolute rank move: %.2f\n", mean(abs(rank_p - rank_w)));
fprintf("### RANKS DONE ###\n");
