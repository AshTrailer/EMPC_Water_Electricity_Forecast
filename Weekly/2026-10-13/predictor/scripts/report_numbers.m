%% Exact counts behind the figure set, so the report quotes numbers and not shapes.
clear; clc;
project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
S = load(fullfile(fig_dir, "atlas_v5.mat"), "E4", "names", "R", "comb_name", ...
   "comb_surf", "d_score");
E4 = S.E4;  names = string(S.names(:));  d = S.d_score;
[n_s, n_h, ~, n_m] = size(E4);

Rd = zeros(n_s, n_h, n_m);
for m = 1:n_m
   Rd(:, :, m) = sqrt(mean(double(E4(:, :, d, m)).^2, 3));
end

fprintf("=== single models only, days %d to %d, %d cells ===\n", d(1), d(end), n_s*n_h);
[~, wm] = min(Rd, [], 3);
w = zeros(n_m,1);
for m = 1:n_m, w(m) = sum(sum(wm == m)); end
[~, o] = sort(w, "descend");
for m = o'
   fprintf("  %-26s %6d cells %6.2f%%\n", names(m), w(m), 100*w(m)/(n_s*n_h));
end

fprintf("\n=== the same census inside one lead, the 288 times of day ===\n");
fprintf("%-26s", "model");
for h = [1 12 72 288], fprintf("%9s", "h=" + string(h)); end
fprintf("\n");
for m = o'
   if w(m) == 0, continue; end
   fprintf("%-26s", names(m));
   for h = [1 12 72 288], fprintf("%9d", sum(wm(:, h) == m)); end
   fprintf("\n");
end

fprintf("\n=== all single models and all rules together, days %d to %d ===\n", d(1), d(end));
cn = string(S.comb_name(:));
Sa = zeros(n_s, n_h, n_m + numel(cn));
Sa(:, :, 1:n_m) = Rd;
for c = 1:numel(cn), Sa(:, :, n_m + c) = S.comb_surf{c}; end
lbl = [names(:); cn];
[~, wa] = min(Sa, [], 3);
wa_counts = zeros(numel(lbl),1);
for i = 1:numel(lbl), wa_counts(i) = sum(sum(wa == i)); end
[~, oa] = sort(wa_counts, "descend");
for i = oa'
   if wa_counts(i) > 0
      fprintf("  %-48s %6d cells %6.2f%%\n", lbl(i), wa_counts(i), ...
         100*wa_counts(i)/(n_s*n_h));
   end
end

% the recommended rule against the best single model, by RMSE sign
pk = find(contains(cn, "optimal weights, 4h blocks") & contains(cn, "shrink 0.3"), 1);
Cc = double(S.comb_surf{pk});
[~, bm] = min(sqrt(mean(reshape(double(E4(:,:,d,:)), [], n_m).^2, 1)));
Bm = Rd(:, :, bm);
Df = Cc - Bm;
fprintf("\n=== %s against %s ===\n", cn(pk), names(bm));
fprintf("  combination lower in %d cells (%.1f%%)\n", sum(Df(:) < 0), ...
   100*sum(Df(:) < 0)/(n_s*n_h));
fprintf("  %s lower in %d cells (%.1f%%)\n", names(bm), sum(Df(:) > 0), ...
   100*sum(Df(:) > 0)/(n_s*n_h));
fprintf("  median difference %+.3f, worst %+.2f, best %+.2f $/MWh\n", ...
   median(Df(:)), max(Df(:)), min(Df(:)));
fprintf("  combination lower in %d of the 288 leads at 18:05, %d at 06:05\n", ...
   sum(Df(217, :) < 0), sum(Df(73, :) < 0));
fprintf("### NUMBERS DONE ###\n");
