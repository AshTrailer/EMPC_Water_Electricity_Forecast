%% Probe the AR sweep: what R is, and where the per-cell optimum lands.
clear; clc;
fig_dir = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\level_multiwindow_figs";
A = load(fullfile(fig_dir, "ar_sweep.mat"), "p_list", "Rp_all", "Rp_lead", ...
   "Rp_slot", "ss_by_p");
pl = A.p_list(:)';  P = numel(pl);
R4 = double(A.ss_by_p{pl == 4});
fprintf("Rp_all(4)            %.4f\n", A.Rp_all(pl == 4));
fprintf("sqrt(mean(R4.^2))    %.4f\n", sqrt(mean(R4(:).^2)));
fprintf("sqrt(mean(R4))       %.4f\n", sqrt(mean(R4(:))));
fprintf("Rp_lead(4,72)        %.4f\n", A.Rp_lead(pl == 4, 72));
fprintf("mean(R4(:,72))       %.4f\n", mean(R4(:, 72)));

% keep only the candidate set M19 actually chooses among, plus a coarse look
cand = [1 2 3 5 8];
ic = arrayfun(@(p) find(pl == p, 1), cand);
[n_s, n_h] = size(R4);
stack = zeros(n_s, n_h, numel(cand));
for i = 1:numel(cand), stack(:, :, i) = double(A.ss_by_p{ic(i)}); end
[~, bp] = min(stack, [], 3);
fprintf("\nin-sample per-cell best order among %s, from the sweep:\n", mat2str(cand));
for i = 1:numel(cand)
   fprintf("  p=%-3d chosen for %6d cells (%.1f%%)\n", cand(i), sum(bp(:) == i), ...
      100*sum(bp(:) == i)/(n_s*n_h));
end

% the headroom: surface at p=1 minus the per-cell best available
r1 = double(A.ss_by_p{pl == 1});
bestv = min(stack, [], 3);
gap = r1 - bestv;
fprintf("\nif every cell could pick its best order in sample:\n");
fprintf("  median gain %.3f, mean gain %.3f, largest gain %.3f $/MWh\n", ...
   median(gap(:)), mean(gap(:)), max(gap(:)));
fprintf("  cells with gain over 1.0: %d of %d\n", sum(gap(:) > 1), n_s*n_h);

% per-lead in-sample optimum over the same candidate set, pooled over slots
fprintf("\nper-lead optimum of the pooled profile, over p=1..48, and over the candidate set\n");
for h = [1 6 12 36 72 144 288]
   [v1, i1] = min(A.Rp_lead(:, h));
   [v2, i2] = min(A.Rp_lead(ic, h));
   fprintf("  lead %3d: over 1..48 p=%-3d %.3f | over candidates p=%-2d %.3f\n", ...
      h, pl(i1), v1, cand(i2), v2);
end
fprintf("\nper-cell optimum, counted at the same leads\n");
for h = [1 6 12 36 72 144 288]
   c = histcounts(bp(:, h), 0.5:(numel(cand)+0.5));
   fprintf("  lead %3d:", h);
   for i = 1:numel(cand), fprintf("  p=%d %3d", cand(i), c(i)); end
   fprintf("\n");
end
fprintf("### PROBE DONE ###\n");
