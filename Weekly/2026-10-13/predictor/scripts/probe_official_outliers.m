function probe_official_outliers()
   % PROBE_OFFICIAL_OUTLIERS  Which product puts impossible prices into the cube.
   %
   %   The band cells of the official composite reach 23199.9 $/MWh in a window
   %   whose actual price never passes 406.11. A handful of those cells would set
   %   the scale of any squared statistic computed over the surface, so they are
   %   located here rather than left as an unexplained maximum.
   %
   % Run: runs\run_probe_official_outliers.bat <log name>

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   addpath(genpath(fullfile(root, "Predicitor")));

   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   lead_min = official_lead_axis();
   lead_min = lead_min(:)';
   d_score = double(O.d_score);  d_score = d_score(:)';
   names = ["none", "P5MIN", "PREDISPATCH", "PD7DAY"];

   O4 = double(O.O4(:, :, d_score));
   SRC = O.SRC4(:, :, d_score);
   AGE = double(O.AGE4(:, :, d_score));
   band = find(lead_min >= 360 & lead_min <= 1440);
   v3 = O4(:, band, :);
   s3 = SRC(:, band, :);
   fprintf("band cells %d\n", numel(v3));
   for p = 0:3
      m = s3 == p;
      fprintf("  %-12s %8d cells (%.2f%%)  max |value| %10.1f  |value|>5000: %d\n", ...
         names(p + 1), sum(m, "all"), 100 * mean(m, "all"), ...
         max(abs(v3(m))), sum(abs(v3(m)) > 5000));
   end

   [~, ord] = sort(abs(v3(:)), "descend");
   fprintf("\nlargest |official| values in the band\n");
   fprintf("  %-4s %-5s %-9s %11s  %-12s %8s\n", "day", "slot", "lead_h", "value", "source", "age_h");
   for i = 1:15
      [s, kb, d] = ind2sub(size(v3), ord(i));
      k = band(kb);  dd = d_score(d);
      fprintf("  %-4d %-5d %-9.1f %11.1f  %-12s %8.2f\n", dd, s, lead_min(k) / 60, ...
         v3(s, kb, d), names(double(O.SRC4(s, k, dd)) + 1), double(O.AGE4(s, k, dd)) / 60);
   end

   fprintf("\nthe same over the whole lead axis\n");
   for p = 0:3
      m = SRC == p;
      fprintf("  %-12s max |value| %12.1f  |value|>5000: %7d of %8d (%.2f%%)\n", ...
         names(p + 1), max(abs(O4(m))), sum(abs(O4(m)) > 5000), sum(m, "all"), ...
         100 * mean(abs(O4(m)) > 5000));
   end

   % ---- the same picture as a histogram, for the figure -------------------
   edges = logspace(0, log10(30000), 37);
   hist_all = zeros(4, numel(edges) - 1);
   for p = 0:3
      x = abs(v3(s3 == p));
      x = x(isfinite(x));
      if isempty(x), continue; end
      hist_all(p + 1, :) = histcounts(x, edges);
   end
   % the realised price range, which is the only scale the values can be read on
   ymin = inf;  ymax = -inf;
   for m = ["202608", "202609", "202610"]
      fid = fopen(fullfile(root, "AEMO_Data", "PRICE_AND_DEMAND_" + m + "_VIC1.csv"), "r");
      c = textscan(fid, "%s %s %f %f %s", "Delimiter", ",", "HeaderLines", 1);
      fclose(fid);
      v = c{4}(string(c{1}) == "VIC1");
      ymin = min(ymin, min(v));  ymax = max(ymax, max(v));
   end
   fprintf("\nrealised price range %.2f to %.2f $/MWh\n", ymin, ymax);

   out = struct();
   out.source_names = names;
   out.hist_edges = edges;
   out.hist_counts = hist_all;
   out.band_source_cells = arrayfun(@(p) sum(s3(:) == p), 0:3);
   out.band_above_5000 = arrayfun(@(p) sum(abs(v3(s3 == p)) > 5000), 0:3);
   out.band_max = arrayfun(@(p) max([abs(v3(s3 == p)); NaN], [], "omitnan"), 0:3);
   out.actual_min = ymin;  out.actual_max = ymax;
   txt = jsonencode(out);
   f = fullfile(root, "Weekly", "2026-10-13", "research", "verify", "official_sources.json");
   fid = fopen(f, "w");
   fwrite(fid, txt, "char");
   fclose(fid);
   fprintf("wrote %s (%d bytes)\n", f, numel(txt));
   fprintf("### SCRIPT COMPLETED ###\n");
end
