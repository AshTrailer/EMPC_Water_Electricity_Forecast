%% ============================================================
%  DIAGNOSE_BANDS  Why the horizontal bands in F1, and how wide they are
%
%  Past column 11 the lead axis is 30 minutes per column, so ONE DAY IS EXACTLY
%  48 COLUMNS. Any model whose forecast anchors on the price at the origin has
%  an error that depends on how many days back the origin sits, and on the
%  origin's clock time. Both of those advance by exactly one day per 48 columns,
%  so the error surface must repeat with period 48 columns. That is the
%  horizontal banding in M1, M3, M5, M7 and M13.
%
%  The test is a lag-48 correlation of the surface with itself, per model. A
%  model that anchors on the target slot only, like the plain template, must
%  show no such periodicity.
%
%  Run: matlab -batch "run('...\diagnose_bands.m')"
% ============================================================
clear; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(predictor_root);  addpath(fullfile(predictor_root, "Shared"));
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");

S = load(fullfile(fig_dir, "atlas_60d.mat"), "n_h", "keys", "names", "lead_min", "d_score");
A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
n_s = 288;  n_h = S.n_h;  ds = S.d_score;
keys = string(S.keys(:));
c0 = 12;                       % first 30-minute column; one day is 48 of them

%% ---- lag-48 correlation, per model ---------------------------------------
fprintf("lag-48 correlation of R with itself, inside the 30-minute band\n");
fprintf("48 columns x 30 min = one day, so a model anchored on the origin repeats\n\n");
fprintf("%-24s %10s %10s\n", "model", "lag 48", "lag 96");
for j = 1:numel(keys)
   E = double(A.E4(:, :, ds, j));
   R = sqrt(mean(E.^2, 3));
   clear E
   r48 = lag_corr(R, c0, 48);
   r96 = lag_corr(R, c0, 96);
   fprintf("%-24s %10.3f %10.3f\n", keys(j), r48, r96);
   clear R
end

%% ---- where the surface actually changes, along the lead -------------------
fprintf("\nlead-direction change: how concentrated is it in a few columns?\n");
fprintf("%-24s %12s %12s %12s\n", "model", "p99/median", "top 6 columns", "share in them");
for k = ["persistence" "carry_forward" "CF_DMS4" "kalman_harm" "T28" "T_ewma"]
   j = find(keys == k, 1);
   E = double(A.E4(:, :, ds, j));
   R = sqrt(mean(E.^2, 3));
   clear E
   dR = abs(diff(R, 1, 2));                 % slot x (n_h-1)
   m = mean(dR, 1);                         % per column, averaged over slots
   [s, o] = sort(m, "descend");
   top = o(1:6);
   fprintf("%-24s %12.2f %12s %11.1f%%\n", k, s(1)/max(median(m), eps), ...
      mat2str(sort(top)), 100*sum(m(top))/sum(m));
   clear R dR
end

fprintf("\n### BAND DIAGNOSIS DONE ###\n");

function r = lag_corr(R, c0, lag)
   % Correlation between R(:, c) and R(:, c+lag) over all slots and columns.
   a = R(:, c0:end-lag);
   b = R(:, c0+lag:end);
   a = a(:);  b = b(:);
   ca = a - mean(a);  cb = b - mean(b);
   r = (ca' * cb) / sqrt((ca' * ca) * (cb' * cb));
end
