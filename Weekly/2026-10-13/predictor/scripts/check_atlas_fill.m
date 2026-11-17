%% ============================================================
%  CHECK_ATLAS_FILL  Which atlas cells were never reached, and does it matter?
%
%  E4 is preallocated to ZERO, so a cell the origin loop never reached reads as
%  a zero error rather than as absent. That is invisible to isfinite and it would
%  quietly dilute any average taken over such a cell. This script identifies the
%  unreached cells and asserts that none of them sits inside d_score, which is
%  the only set of days any reported number is taken over.
%
%  A cell is called unreached when EVERY model is exactly zero there. No real
%  forecast error is exactly zero for all of them at once, and the count is
%  cross-checked against the analytic rule: a cell at lead L reaching back past
%  the first scored day cannot have been filled.
%
%  Run: matlab -batch "run('...\check_atlas_fill.m')"
% ============================================================
clear; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
S = load(fullfile(fig_dir, "atlas_60d.mat"), "E4", "n_d", "n_h", "names", "d_score", "h_all");
E4 = S.E4;  n_d = S.n_d;  n_h = S.n_h;  d_score = S.d_score;  h_all = S.h_all;
[n_s, ~, ~, n_m] = size(E4);
fprintf("atlas %dx%dx%dx%d, %d models, scoring days %d to %d\n", ...
   n_s, n_h, n_d, n_m, n_m, d_score(1), d_score(end));

% ---- 1. unreached cells --------------------------------------------------
empty4 = all(E4 == 0, 4);                 % slot x lead x day, logical
n_empty = sum(empty4(:));
fprintf("cells that are zero for every model: %d of %d (%.2f%%)\n", ...
   n_empty, numel(empty4), 100*n_empty/numel(empty4));

% ---- 2. none of them inside d_score --------------------------------------
in_score = sum(empty4(:, :, d_score), 'all');
fprintf("of those, inside the scoring days: %d\n", in_score);
assert(in_score == 0, 'check_atlas_fill:scored', ...
   '%d unreached cells sit inside days %d to %d, so every average over those days is diluted', ...
   in_score, d_score(1), d_score(end));

% ---- 3. the pattern matches the rule -------------------------------------
% A cell at lead index k targets day d from an origin h_all(k) steps earlier, so
% it can only be filled when the origin still falls inside the window.
% Column vectors explicitly: sum(..., [1 3]) can come back with the singleton
% dimensions in a different order and a row-minus-column comparison then
% silently produces a matrix, which is what made this line print 376 times.
per_lead = reshape(sum(empty4, [1 3]), [], 1);
lead_day = h_all(:) / n_s;
expected = zeros(n_h, 1);
for k = 1:n_h
   % target days 1..ceil(lead/288) can never have a filled cell
   expected(k) = n_s * min(n_d, ceil(lead_day(k)));
end
mism = sum(abs(per_lead - expected) > n_s);   % allow the day-boundary slack
fprintf("per-lead unreached count against the analytic rule: %d of %d leads differ by more than one day\n", ...
   mism, n_h);
fprintf("  first lead  %6d unreached of %d (lead %g min)\n", per_lead(1), n_s*n_d, h_all(1)*5);
fprintf("  last  lead  %6d unreached of %d (lead %g min)\n", per_lead(end), n_s*n_d, h_all(end)*5);
for k = [1 12 58 202 n_h]
   fprintf("  lead index %4d  %6d unreached  expected about %6d\n", k, per_lead(k), expected(k));
end

% ---- 4. what the scored surface actually rests on ------------------------
cnt = squeeze(sum(~empty4(:, :, d_score), 3));
fprintf("\ndays contributing to each scored cell: min %d, median %d, max %d of %d\n", ...
   min(cnt(:)), median(cnt(:)), max(cnt(:)), numel(d_score));
fprintf("cells in d_score with fewer than %d contributing days: %d\n", ...
   numel(d_score), sum(cnt(:) < numel(d_score)));
fprintf("\n### FILL CHECK PASSED: no unreached cell lies inside the scoring days ###\n");
