%% Checks behind the questions on the figure set. Nothing is written.
clear; clc;
project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");

fprintf("=== what is inside ar_sweep.mat ===\n");
w = whos("-file", fullfile(fig_dir, "ar_sweep.mat"));
for i = 1:numel(w)
   fprintf("  %-22s %-12s %s\n", w(i).name, class(w(i).class), mat2str(w(i).size));
end

S = load(fullfile(fig_dir, "atlas_v4.mat"), "E4", "names", "comb_name", ...
   "comb_surf", "d_score");
E4 = S.E4;  names = string(S.names(:));  d = S.d_score;  cn = string(S.comb_name(:));
[n_s, n_h, ~, n_m] = size(E4);
k = @(s) find(names == s, 1);

% ---- 1. the cell the reader flagged: slot 1, lead 288, M12 against M8 ----
i8 = k("Anchor-mix");  i12 = k("MW + level (run state)");
e8 = squeeze(double(E4(1, 288, d, i8)));
e12 = squeeze(double(E4(1, 288, d, i12)));
r8 = sqrt(mean(e8.^2));  r12 = sqrt(mean(e12.^2));
sq = e12.^2 - e8.^2;
L = 7;  m = mean(sq);  dev = sq - m;  v = mean(dev.^2);
for l = 1:L
   v = v + 2*(1 - l/(L+1))*mean(dev(1+l:end).*dev(1:end-l));
end
dmst = m/sqrt(v/numel(sq));
fprintf("\n=== cell (slot 1, lead 288), M12 minus M8 ===\n");
fprintf("  RMSE M8 %.3f, M12 %.3f, difference of RMSE %+.3f\n", r8, r12, r12 - r8);
fprintf("  mean of squared-error difference %+.4f\n", m);
fprintf("  DM statistic %.3f, two-sided p %.3g\n", dmst, erfc(abs(dmst)/sqrt(2)));
[~, ord] = sort(abs(dev), "descend");
fprintf("  the largest single day carries %.1f%% of the sum of |deviation|\n", ...
   100*abs(dev(ord(1)))/sum(abs(dev)));
fprintf("  the largest three days carry %.1f%%\n", ...
   100*sum(abs(dev(ord(1:3))))/sum(abs(dev)));

% how many cells are like this: small RMSE gap but significant
Rd = zeros(n_s, n_h, n_m);
for mm = 1:n_m
   Rd(:, :, mm) = sqrt(mean(double(E4(:, :, d, mm)).^2, 3));
end
Dg = Rd(:, :, i12) - Rd(:, :, i8);
fprintf("\ncells with |difference of RMSE| under 1.0: %d of %d\n", ...
   sum(abs(Dg(:)) < 1), n_s*n_h);

% ---- 2. M13 against M8 ----
i13 = k("Kalman harmonic SS");
D13 = Rd(:, :, i13) - Rd(:, :, i8);
fprintf("\n=== M13 against M8 ===\n");
fprintf("  M13 lower in %d cells (%.1f%%), M8 lower in %d (%.1f%%)\n", ...
   sum(D13(:) < 0), 100*sum(D13(:) < 0)/(n_s*n_h), ...
   sum(D13(:) > 0), 100*sum(D13(:) > 0)/(n_s*n_h));
for h = [1 12 36 72 144 288]
   fprintf("    lead %3d: M13 lower in %3d of 288 times of day\n", h, sum(D13(:, h) < 0));
end

% ---- 3. the recommended rule against M8, as a profile over lead ----
pk = find(contains(cn, "optimal weights, 4h blocks") & contains(cn, "shrink 0.3"), 1);
Cc = double(S.comb_surf{pk});
Dc = Cc - Rd(:, :, i8);
fprintf("\n=== %s against M8 ===\n", cn(pk));
fprintf("slot      lead1   lead12  lead36  lead72  lead144 lead288   first lead where comb is better\n");
for sl = [1 73 145 217]
   row = Dc(sl, :);
   cr = find(row < 0, 1);
   fprintf("%02d:%02d  ", floor(sl*5/60), mod(sl*5, 60));
   for h = [1 12 36 72 144 288]
      fprintf("%8.2f", row(h));
   end
   if isempty(cr)
      fprintf("   never\n");
   else
      fprintf("   %d (%g h)\n", cr, cr*5/60);
   end
end
fprintf("\nper lead, how many of the 288 times of day the combination is lower:\n");
for h = [1 6 12 24 36 72 144 288]
   fprintf("  lead %3d (%5.2f h): %3d of 288\n", h, h*5/60, sum(Dc(:, h) < 0));
end
fprintf("  leads where the combination is lower in all 288: %d of 288\n", ...
   sum(all(Dc < 0, 1)));
fprintf("  leads where it is lower in fewer than half: %d of 288\n", ...
   sum(sum(Dc < 0, 1) < 144));
fprintf("### CHECKS DONE ###\n");
