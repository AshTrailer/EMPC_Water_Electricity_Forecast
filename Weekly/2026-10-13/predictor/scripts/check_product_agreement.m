function check_product_agreement()
   % CHECK_PRODUCT_AGREEMENT  Do the AEMO products agree where their horizons
   % overlap? This is the supervisor's fourth question and it has never been
   % measured.
   %
   % METHOD. The composite keeps only the winning product per cell, so the
   % overlap is invisible in the stored value. The sixth output of
   % OFFICIAL_COMPOSITE prices every target with every product that reaches it,
   % and the two pairs that genuinely overlap are then compared cell by cell:
   %
   %    P5MIN against PREDISPATCH  where both can price the same target inside
   %                               the first hour. P5MIN is 5-minute and
   %                               PREDISPATCH is 30-minute, so the only shared
   %                               targets are the :00 and :30 ones.
   %    PREDISPATCH against PD7DAY where both reach 164.5 to 183.0 hours.
   %
   % Read only.

   project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   addpath(genpath(fullfile(project_root, "Predicitor")));
   fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
   deck_dir = fullfile(project_root, "Weekly", "2026-10-13", "deck");
   out_json = fullfile(deck_dir, "deck_overlap.json");

   [lead_min, ~, ~] = official_lead_axis();
   n_h = numel(lead_min);
   n_s = 288;

   S = load(fullfile(project_root, "AEMO_Data", "level_multiwindow_figs", "atlas_60d.mat"), ...
      "lead_min", "d_score", "t_test");
   n_d = numel(S.t_test);
   cfg = official_composite_load(fullfile(project_root, "AEMO_Data"));
   n_prod = numel(cfg.products);

   % The columns each pair can share, from the horizons alone, and on the grid
   % the pair shares. P5MIN is 5-minute and PREDISPATCH is 30-minute, so the
   % first-hour comparison can only be made on the :00 and :30 targets, which
   % are the columns where the axis itself is on the half hour.
   long_cols = find(lead_min >= 164.5 * 60);
   hour_cols = find(lead_min <= 55 & mod(lead_min, 30) == 0);
   fprintf("columns where PD7DAY can reach: %d to %d (%.1f to %.1f h)\n", ...
      long_cols(1), long_cols(end), lead_min(long_cols(1))/60, lead_min(long_cols(end))/60);
   fprintf("columns shared by P5MIN and PREDISPATCH inside the first hour: %s\n", ...
      mat2str(hour_cols'));

   keep = [hour_cols(:); long_cols(:)];
   nk = numel(keep);
   is_pair1 = lead_min(keep) <= 55;
   D = nan(n_s, nk, n_d, "single");        % difference, product a minus product b

   tmr = tic;
   for d = 1:n_d
      for s = 1:n_s
         idx = (d - 1) * n_s + s;
         if idx > numel(S.t_test), continue; end
         [~, ~, ~, ~, ~, allv] = official_composite(S.t_test(idx), lead_min(keep), cfg);
         % The difference is formed on the raw published values. Clamping both
         % sides first would fold a disagreement wider than the clamp band back to
         % the band edge and understate it, and this comparison is between two
         % forecasts rather than between a forecast and the realised price.
         a = allv(:, 1);     % P5MIN
         b = allv(:, 2);     % PREDISPATCH
         c = allv(:, 3);     % PD7DAY
         m1 = isfinite(a) & isfinite(b);
         d1 = nan(nk, 1);  d1(m1) = a(m1) - b(m1);
         m2 = isfinite(b) & isfinite(c);
         d2 = nan(nk, 1);  d2(m2) = b(m2) - c(m2);
         % One array carries both pairs: the first hour columns hold pair 1 and
         % the long columns hold pair 2, and the two sets do not intersect.
         row = d2;
         row(is_pair1) = d1(is_pair1);
         D(s, :, d) = single(row');
      end
   end
   fprintf("overlap cube %d x %d x %d in %.1f s\n", n_s, nk, n_d, toc(tmr));

   rows = struct("name", {}, "cells", {}, "identical", {}, "pct_identical", {}, ...
      "mean_diff", {}, "rmse_diff", {}, "p50_abs", {}, "p95_abs", {}, "max_abs", {});
   for p = 1:2
      if p == 1
         m = repmat(reshape(is_pair1, 1, nk), n_s, 1);
         nm = sprintf("%s vs %s, first hour", cfg.names(1), cfg.names(2));
      else
         m = repmat(reshape(~is_pair1, 1, nk), n_s, 1);
         nm = sprintf("%s vs %s, 164.5 to 183.0 hours", cfg.names(2), cfg.names(3));
      end
      dd = double(D(:, :, :));
      dd = dd(repmat(m, 1, 1, n_d));
      dd = dd(isfinite(dd));
      rows(p) = struct("name", nm, "cells", numel(dd), ...
         "identical", sum(dd == 0), "pct_identical", 100 * mean(dd == 0), ...
         "mean_diff", mean(dd), "rmse_diff", sqrt(mean(dd.^2)), ...
         "p50_abs", median(abs(dd)), "p95_abs", prctile(abs(dd), 95), ...
         "max_abs", max(abs(dd)));
      fprintf("%-44s cells %7d  identical %5.2f%%  mean %+7.3f  rmse %7.3f  p95|d| %7.3f\n", ...
         nm, rows(p).cells, rows(p).pct_identical, rows(p).mean_diff, ...
         rows(p).rmse_diff, rows(p).p95_abs);
   end

   % Per column, so the section can show whether agreement drifts with the lead.
   per_col = nan(1, nk);
   for k = 1:nk
      v = double(D(:, k, :));
      v = v(isfinite(v));
      if isempty(v), continue; end
      per_col(k) = sqrt(mean(v.^2));
   end

   out = struct();
   out.pair = rows;
   out.lead_min = lead_min(keep)';
   out.lead_h = lead_min(keep)' / 60;
   out.per_col_rmse = per_col;
   out.first_hour_cols = sum(is_pair1);
   out.long_cols = sum(~is_pair1);
   out.scored_days = n_d;
   out.note = "the difference is between the two products' raw published values, no clamping";
   fid = fopen(out_json, "w");
   fwrite(fid, jsonencode(out, "PrettyPrint", true));
   fclose(fid);
   fprintf("\nwrote %s\n", out_json);
end
