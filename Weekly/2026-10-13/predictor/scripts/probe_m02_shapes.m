function probe_m02_shapes()
   % PROBE_M02_SHAPES  Shapes of the four dimensional read and the baseline.
   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   addpath(genpath(fullfile(root, "Predicitor")));
   fd = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   A = matfile(fullfile(fd, "atlas_60d.mat"));
   O = matfile(fullfile(fd, "official_60d.mat"));
   names = string(A.names);
   names = names(:);
   fprintf("names %d\n", numel(names));
   for i = 1:numel(names)
      fprintf("  %2d %s\n", i, names(i));
   end
   [lm, ~, ~] = official_lead_axis();
   lm = lm(:)';
   band = find(lm >= 360 & lm <= 1440);
   cols = [find(lm == 60, 1), band];
   dsc = double(A.d_score);
   dsc = dsc(:)';
   fprintf("lead axis %d columns, lead(12) %g, band %d to %d, cols %d, dsc %d to %d\n", ...
      numel(lm), lm(12), band(1), band(end), numel(cols), dsc(1), dsc(end));
   tic;
   raw = cols(1):band(end);
   sel = [1, band - cols(1) + 1];
   E4b = double(A.E4(1:288, raw, dsc, :));
   E4b = E4b(:, sel, :, :);
   fprintf("E4 read %.1f s, raw %d columns, kept %d, size %s\n", toc, numel(raw), ...
      numel(sel), mat2str(size(E4b)));
   Ea = permute(E4b(:, :, :, find(names == "Anchor-mix")), [3 1 2]);
   Eo = double(O.E4_off(1:288, raw, dsc));
   Eo = permute(Eo(:, sel, :), [3 1 2]);
   fprintf("Ea %s  Eo %s\n", mat2str(size(Ea)), mat2str(size(Eo)));
   fprintf("finite ours %.4f  official %.4f\n", mean(isfinite(Ea), "all"), ...
      mean(isfinite(Eo), "all"));
   RA = reshape(sqrt(mean(Ea(:, :, 2:end) .^ 2, 1, "omitnan")), 288, 37);
   RB = reshape(sqrt(mean(Eo(:, :, 2:end) .^ 2, 1, "omitnan")), 288, 37);
   mA = median(RA, 1, "omitnan");
   mB = median(RB, 1, "omitnan");
   fprintf("band ratio, median of per-column ratios %.4f (expect 1.3327)\n", ...
      median(mA ./ mB));
   fprintf("band medians ours %.3f, official %.3f, ratio of medians %.4f\n", ...
      median(mA), median(mB), median(mA) / median(mB));
   r1a = median(sqrt(mean(Ea(:, :, 1) .^ 2, 1, "omitnan")), "omitnan");
   r1o = median(sqrt(mean(Eo(:, :, 1) .^ 2, 1, "omitnan")), "omitnan");
   fprintf("one hour ours %.3f official %.3f ratio %.4f (expect 0.8500)\n", ...
      r1a, r1o, r1a / r1o);
end
