%% Inspect R along the lead axis for models that should not depend on it.
clear; clc;
project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
S = load(fullfile(fig_dir, "atlas_60d.mat"), "n_h", "keys", "lead_min", "d_score");
A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
ds = S.d_score;  keys = string(S.keys(:));  n_h = S.n_h;  lead_min = double(S.lead_min(:));

for k = ["T28" "carry_forward" "kalman_harm"]
   j = find(keys == k, 1);
   E = double(A.E4(:, :, ds, j));
   R = sqrt(mean(E.^2, 3));
   clear E
   fprintf("\n=== %s ===\n", k);
   dR = abs(diff(R, 1, 2));
   mcol = max(dR, [], 1);                 % worst slot per adjacent column pair
   fprintf("columns where R is bit-identical to the next one in EVERY slot: %d of %d\n", ...
      sum(mcol == 0), numel(mcol));
   [s, o] = sort(mcol, "descend");
   fprintf("column pairs with the largest change (column c -> c+1):\n");
   for i = 1:6
      c = o(i);
      fprintf("  c=%3d  lead %8.1f h -> %8.1f h   max|dR| %10.4f   mean|dR| %8.4f\n", ...
         c, lead_min(c)/60, lead_min(c+1)/60, s(i), mean(dR(:, c)));
   end
   fprintf("  median over column pairs of max|dR| : %.6g\n", median(mcol));
   fprintf("  R at slot 100, columns 56 to 62:\n");
   fprintf("   %s\n", mat2str(R(100, 56:62), 6));
   fprintf("  R at slot 100, columns 104 to 110:\n");
   fprintf("   %s\n", mat2str(R(100, 104:110), 6));
   clear R dR
end
fprintf("\n### DONE ###\n");
