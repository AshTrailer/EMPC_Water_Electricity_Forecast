%% Drive compare_surfaces over the pairs that matter.
% Index map of atlas_full.mat:
%   1 Persistence   2 Template T28   3 Theta-y      4 T28 + AR4
%   5 Carry-fwd     6 T28 + DMS4     7 CF + DMS4    8 Anchor-mix
%   9 T28 + level  10 Multi-window  11 MW + level  12 MW + level (run state)
project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
addpath(fullfile(project_root, "Predicitor"));
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");

pairs = { 4, 12, "m04_T28AR4_vs_m12_MWrun", "the short-lead specialist against the long-lead one"; ...
          8, 12, "m08_anchor_vs_m12_MWrun", "the champion against its closest rival"; ...
          9, 11, "m09_vs_m11_level",        "same idea, single-window against multi-window" };

for p = 1:size(pairs,1)
   fprintf("\n\n################ %s ################\n", pairs{p,3});
   fprintf("## %s\n", pairs{p,4});
   compare_surfaces(pairs{p,1}, pairs{p,2}, fullfile(fig_dir, pairs{p,3} + ".png"));
end
fprintf("\n### COMPARE COMPLETED ###\n");
