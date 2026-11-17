%% Profile endpoints, so the report quotes numbers that are on the figures.
clear; clc;
project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
S = load(fullfile(fig_dir, "atlas_v4.mat"), "E4", "names", "d_score");
E4 = S.E4;  names = string(S.names(:));  d = S.d_score;
[n_s, n_h, ~, n_m] = size(E4);

Rd = zeros(n_s, n_h, n_m);
for m = 1:n_m
   Rd(:, :, m) = sqrt(mean(double(E4(:, :, d, m)).^2, 3));
end
k = @(s) find(names == s, 1);
show = ["Anchor-mix" "MW + level (run state)" "Kalman harmonic SS" ...
        "T28 + AR4" "Multi-window T"];

fprintf("=== R over the 288 times of day, at four leads, days %d to %d ===\n", d(1), d(end));
for h = [1 12 72 288]
   fprintf("\nlead %d (%g h)\n", h, h*5/60);
   fprintf("%-26s %9s %9s %9s %9s\n", "model", "min", "median", "max", "max/min");
   for s = show
      v = Rd(:, h, k(s));
      fprintf("%-26s %9.2f %9.2f %9.2f %9.2f\n", s, min(v), median(v), max(v), ...
         max(v)/min(v));
   end
end

fprintf("\n=== R over the 288 leads, at four times of day ===\n");
for sl = [1 73 145 217]
   fprintf("\nslot %d (%02d:%02d)\n", sl, floor(sl*5/60), mod(sl*5, 60));
   fprintf("%-26s %9s %9s %9s %9s\n", "model", "min", "median", "max", "max/min");
   for s = show
      v = Rd(sl, :, k(s));
      fprintf("%-26s %9.2f %9.2f %9.2f %9.2f\n", s, min(v), median(v), max(v), ...
         max(v)/min(v));
   end
end

fprintf("\n=== the crossover inside the 18:05 row ===\n");
for s = ["T28 + AR4" "Anchor-mix" "Kalman harmonic SS"]
   v = Rd(217, :, k(s));
   cross = find(v > Rd(217, :, k("Anchor-mix")), 1);
   fprintf("  %-20s first lead where it is worse than Anchor-mix: %s\n", s, ...
      string(cross) + " (" + string(cross*5/60) + " h)");
end
fprintf("### ENDPOINTS DONE ###\n");
