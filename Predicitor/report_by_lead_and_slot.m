%% ============================================================
%  REPORT_BY_LEAD_AND_SLOT  The only two admissible comparisons
%
%  A single pooled number over the whole 288 by 288 surface mixes the lead
%  effect, the time-of-day effect and their interaction into one scalar, and
%  two models with the same scalar can rank in opposite orders at every lead.
%  So this script reports nothing pooled. It prints two tables:
%
%    fixed lead  : RMSE against the 288 times of day, one column per model
%    fixed slot  : RMSE against the 288 leads, one column per model
%
%  and, for each, which model wins where. Output:
%  AEMO_Data/level_multiwindow_figs/report_by_lead_and_slot.mat
% ============================================================
clear; close all; clc;

project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
predictor_root = fullfile(project_root, "Predicitor");
addpath(fullfile(predictor_root, "Shared"));
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");

S = load(fullfile(fig_dir, "atlas_v3.mat"));
E4 = S.E4;
[n_s, ~, n_d, n_m] = size(E4);
reg = model_registry();
names = string({reg.name});
fprintf("atlas %s | %d models | %d days\n", mat2str(size(E4)), n_m, n_d);

% R(slot, lead, model): RMS over days only, so both profiles stay live
R = zeros(n_s, n_s, n_m);
for m = 1:n_m
   R(:, :, m) = sqrt(mean(double(E4(:, :, :, m)).^2, 3));
end

%% ---- comparison one: fixed lead, all 288 times of day ----
h_show = [1 6 12 36 72 144 288];
h_lab  = {'5 min','30 min','1 h','3 h','6 h','12 h','24 h'};
fprintf("\n=== fixed lead, RMS over days at each time of day ===\n");
fprintf("columns: mean over the 288 times of day, then the best and worst time of day\n");
fprintf("%-24s", "model");
for k = 1:numel(h_show), fprintf("%9s", h_lab{k}); end
fprintf("%10s%10s\n", "best slot", "worst slot");
for m = 1:n_m
   fprintf("%-24s", names(m));
   for k = 1:numel(h_show)
      fprintf("%9.2f", mean(R(:, h_show(k), m)));
   end
   v = R(:, h_show(7), m);
   fprintf("%10.2f%10.2f\n", min(v), max(v));
end

fprintf("\nwhich model wins at each time of day, at lead 6h\n");
[~, w6] = min(R(:, 72, :), [], 3);
for m = 1:n_m
   fprintf("  %-24s wins %3d of 288 times of day\n", names(m), sum(w6 == m));
end
fprintf("which model wins at each time of day, at lead 24h\n");
[~, w24] = min(R(:, 288, :), [], 3);
for m = 1:n_m
   n = sum(w24 == m);
   if n > 0, fprintf("  %-24s wins %3d of 288 times of day\n", names(m), n); end
end

%% ---- comparison two: fixed time of day, all 288 leads ----
s_show = [1 73 145 217 288];
s_lab  = {'00:05','06:05','12:05','18:05','24:00'};
fprintf("\n=== fixed time of day, RMS over days at each lead ===\n");
fprintf("columns: mean over the 288 leads, then the best and worst lead\n");
fprintf("%-24s", "model");
for k = 1:numel(s_show), fprintf("%9s", s_lab{k}); end
fprintf("%10s%10s\n", "best lead", "worst lead");
for m = 1:n_m
   fprintf("%-24s", names(m));
   for k = 1:numel(s_show)
      fprintf("%9.2f", mean(R(s_show(k), :, m)));
   end
   v = R(s_show(3), :, m);
   fprintf("%10.2f%10.2f\n", min(v), max(v));
end

fprintf("\nwhich model wins at each lead, at 18:05\n");
[~, ws] = min(R(217, :, :), [], 3);
for m = 1:n_m
   n = sum(ws == m);
   if n > 0, fprintf("  %-24s wins %3d of 288 leads\n", names(m), n); end
end

%% ---- the same two comparisons for the five combination rules ----
O = load(fullfile(fig_dir, "ensemble_online.mat"));
E_cmb = O.E_cmb;  rules = string(O.rules(:,1));
first_day = O.first_day;
d_score = first_day:size(E_cmb, 3);
Rc = zeros(n_s, n_s, size(E_cmb, 4));
for r = 1:size(E_cmb, 4)
   Rc(:, :, r) = sqrt(mean(double(E_cmb(:, :, d_score, r)).^2, 3));
end
fprintf("\n=== combination rules, fixed lead, days %d to %d ===\n", d_score(1), d_score(end));
fprintf("%-34s", "rule");
for k = 1:numel(h_show), fprintf("%9s", h_lab{k}); end
fprintf("\n");
for r = 1:numel(rules)
   fprintf("%-34s", rules(r));
   for k = 1:numel(h_show), fprintf("%9.2f", mean(Rc(:, h_show(k), r))); end
   fprintf("\n");
end
fprintf("%-34s", "best single model");
for k = 1:numel(h_show)
   fprintf("%9.2f", min(mean(R(:, h_show(k), :), 1), [], 3));
end
fprintf("\n");
fprintf("which rule wins at each lead, over the %d days\n", numel(d_score));
[~, wr] = min(Rc, [], 3);
for r = 1:numel(rules)
   n = sum(wr(:) == r);
   if n > 0, fprintf("  %-34s wins %5d of %d (slot, lead) cells\n", rules(r), n, n_s*n_s); end
end

save(fullfile(fig_dir, "report_by_lead_and_slot.mat"), "R", "Rc", "names", ...
   "rules", "h_show", "s_show", "h_lab", "s_lab", "d_score", "-v7.3");
fprintf("\nwritten to %s\n", fullfile(fig_dir, "report_by_lead_and_slot.mat"));
fprintf("### SCRIPT COMPLETED ###\n");
