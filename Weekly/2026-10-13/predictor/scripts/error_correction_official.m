function error_correction_official()
   % ERROR_CORRECTION_OFFICIAL  The correction the supervisor asked for, measured
   % on exactly the object the rest of the deck uses.
   %
   % "AEMO forecast plus an error correction" is not the same thing as using the
   % AEMO forecast. The correction tested here is the smallest one that deserves
   % the name: for each cell, the mean error the official composite made over the
   % last w complete days, subtracted from the error it makes today.
   %
   %   corrected error(s,h,d) = e(s,h,d) - mean over the w complete days
   %                                        before d of e(s,h,.)
   %
   % Causality. Day d is corrected only with days that had completely finished
   % before d began, so no scored day contributes to its own correction. Adding
   % the mean past error to today's forecast is the same thing as subtracting that
   % mean from today's error, which is the form used here.
   %
   % THE OBJECT. Every number below is on the object the deck uses: R per cell,
   % then the median of R over the 288 times of day at each of the 376 leads, then
   % the median of those 376 numbers. That last step is the median over leads of a
   % median over slots, which is the only way this figure can be compared with the
   % model table in deck_numbers_60d.json. Comparing a median over days with a
   % median over slots is the mistake this comment exists to prevent.
   %
   % Read only apart from one JSON.

   project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   addpath(genpath(fullfile(project_root, "Predicitor")));
   fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
   deck_dir = fullfile(project_root, "Weekly", "2026-10-13", "deck");
   out_json = fullfile(deck_dir, "deck_correction.json");

   W = load(fullfile(fig_dir, "official_60d.mat"), "E4_off", "d_score", "lead_min");
   E = double(W.E4_off);                 % 288 x 376 x 60, target-indexed
   d_score = double(W.d_score(:)');
   lead_min = double(W.lead_min(:));
   n_s = size(E, 1);  n_h = size(E, 2);
   fprintf("official error cube %d x %d x %d, scored days %d to %d\n", ...
      n_s, n_h, size(E, 3), d_score(1), d_score(end));

   % ---- the official baseline, on the deck's object -------------------------
   R_off = official_R(E, d_score, 0);
   med_off = median(R_off, 1, "omitnan");
   base = struct("median_R", median(med_off, "omitnan"), ...
      "R_lead_slot_median", med_off, ...
      "median_short", median(med_off(lead_min <= 1440), "omitnan"), ...
      "median_long", median(med_off(lead_min > 1440), "omitnan"));
   fprintf("official, no correction: median of the 376 column medians %.3f  (short end %.3f, long end %.3f)\n", ...
      base.median_R, base.median_short, base.median_long);

   % ---- the correction, swept ----------------------------------------------
   wins = [7 14 28 56];
   res = struct("w", {}, "median_R", {}, "median_short", {}, "median_long", {}, ...
      "better", {}, "worse", {}, "median_diff", {}, "R_lead_slot_median", {});
   for wi = 1:numel(wins)
      w = wins(wi);
      Rc = official_R(E, d_score, w);
      med_c = median(Rc, 1, "omitnan");
      diff = Rc - R_off;
      res(wi) = struct("w", w, "median_R", median(med_c, "omitnan"), ...
         "median_short", median(med_c(lead_min <= 1440), "omitnan"), ...
         "median_long", median(med_c(lead_min > 1440), "omitnan"), ...
         "better", sum(diff(:) < 0, "omitnan"), "worse", sum(diff(:) > 0, "omitnan"), ...
         "median_diff", median(diff(:), "omitnan"), ...
         "R_lead_slot_median", med_c);
      fprintf("w=%2d: median %.3f  better %6d  worse %6d  median per-cell change %+.3f\n", ...
         w, res(wi).median_R, res(wi).better, res(wi).worse, res(wi).median_diff);
   end
   [~, best] = min([res.median_R]);
   fprintf("best window %d days: %.3f against %.3f, a change of %+.3f\n", ...
      res(best).w, res(best).median_R, base.median_R, res(best).median_R - base.median_R);

   % ---- the sixteen models on the same object ------------------------------
   J = jsondecode(fileread(fullfile(deck_dir, "deck_numbers_60d.json")));
   mdl = struct("key", {}, "name", {}, "med32", {});
   for i = 1:numel(J.model)
      mdl(i) = struct("key", string(J.model(i).key), "name", string(J.model(i).name), ...
         "med32", reshape(double(J.model(i).med32), 1, []));
   end
   fprintf("\nmodel medians at 1 h / 24 h / 7.6 d, for comparison (288-slot medians):\n");
   for i = 1:numel(mdl)
      fprintf("   %-26s %7.2f %7.2f %7.2f\n", mdl(i).name, mdl(i).med32);
   end

   out = struct();
   out.scored_days = numel(d_score);
   out.n_cells = n_s * n_h;
   out.official = base;
   out.correction = res;
   out.best_w = res(best).w;
   out.models = mdl;
   out.formula = "corrected(s,h) = O(s,h) + mean over the w complete days before d of (actual - O)";
   out.object = "R per cell over the 32 scored days, then the median over the 288 slots at each lead, then the median over the 376 leads";
   fid = fopen(out_json, "w");
   fwrite(fid, jsonencode(out, "PrettyPrint", true));
   fclose(fid);
   fprintf("\nwrote %s\n", out_json);
end


function R = official_R(E, d_score, w)
   % R per cell over the scored days, with the causal correction of window w.
   % w = 0 is the official composite as it stands.
   n_s = size(E, 1);  n_h = size(E, 2);
   R = zeros(n_s, n_h);
   used = 0;
   for j = 1:numel(d_score)
      d = d_score(j);
      ec = E(:, :, d);
      if w > 0
         lo = max(1, d - w);
         if lo <= d - 1
            ec = ec - mean(E(:, :, lo:(d - 1)), 3, "omitnan");
         end
      end
      R = R + ec.^2;
      used = used + 1;
   end
   R = sqrt(R / used);
end
