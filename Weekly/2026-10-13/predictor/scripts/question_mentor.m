function question_mentor()
   % QUESTION_MENTOR  The two questions the supervisor raised, answered from the
   % artifacts on disk.
   %
   % Q1  Do the three AEMO products agree where their horizons overlap?
   %     The composite keeps only the winner, so the overlap has to be evaluated
   %     with the sixth output of official_composite, which prices every target
   %     with every product that reaches it. Pairs that genuinely overlap:
   %     P5MIN against PREDISPATCH on the half-hour grid inside the first hour,
   %     and PREDISPATCH against PD7DAY over 164.5 to 183.0 hours.
   %
   % Q2  Does a fitted correction on top of the official forecast beat the
   %     official forecast itself? One correction is tested: the mean error of
   %     the same time of day over a trailing window of complete days, added to
   %     the official value. That is the smallest correction that can be called a
   %     correction, and it is causal: day d uses only complete days before d.
   %
   % Read only apart from one JSON written next to the extraction output.

   project_root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(project_root, "AEMO_Data", "level_multiwindow_figs");
   out_json = fullfile(project_root, "Weekly", "2026-10-13", "deck",
      "deck_mentor.json");

   [lead_min, ~, band] = official_lead_axis();
   n_h = numel(lead_min);

   S = load(fullfile(project_root, "AEMO_Data", "level_multiwindow_figs", "atlas_60d.mat"), ...
      "t_test", "y_test", "q1_by_day", "q2_by_day", "keys", "R", "d_score", "n_train");
   d_score = double(S.d_score(:)');
   n_d_full = numel(S.t_test);
   n_s = 288;
   n_w = 60;

   % ---- Q1 ------------------------------------------------------------------
   cfg = official_composite_load(fullfile(project_root, "AEMO_Data"));
   n_prod = numel(cfg.products);
   fprintf("products: %s\n", strjoin(string(cfg.names), ", "));

   % The overlap is bounded by the horizons, and each product pair only needs the
   % columns where both can reach the target. PD7DAY's horizon moves with the
   % run, so the column set is taken from the widest run of each product and the
   % per-cell pair mask then decides which cells really carry two values.
   n_s = 288;
   n_d_full = numel(S.t_test);
   A = nan(n_s, n_h, n_d_full, n_prod, "single");
   tmr = tic;
   for d = 1:n_d_full
      for s = 1:n_s
         idx = (d - 1) * n_s + s;
         if idx > numel(S.t_test), continue; end
         [~, ~, ~, ~, ~, allv] = official_composite(S.t_test(idx), lead_min, cfg);
         A(s, :, d, :) = single(allv');
      end
   end
   fprintf("product cube %d x %d x %d x %d in %.1f s\n", n_s, n_h, n_d_full, n_prod, toc(tmr));

   pairs = [1 2; 2 3];
   q1 = struct("a", {}, "b", {}, "name", {}, "cells", {}, "same", {}, "diff_pct", ...
      {}, "mean_diff", {}, "rmse_diff", {}, "p50_abs", {}, "p95_abs", {}, "max_abs", {});
   for i = 1:size(pairs, 1)
      a = A(:, :, :, pairs(i, 1));
      b = A(:, :, :, pairs(i, 2));
      m = isfinite(a) & isfinite(b);
      dd = double(a(m)) - double(b(m));
      q1(i) = struct("a", cfg.names(pairs(i, 1)), "b", cfg.names(pairs(i, 2)), ...
         "name", sprintf("%s vs %s", cfg.names(pairs(i, 1)), cfg.names(pairs(i, 2))), ...
         "cells", sum(m(:)), "same", sum(dd == 0), ...
         "diff_pct", 100 * mean(dd ~= 0), "mean_diff", mean(dd), ...
         "rmse_diff", sqrt(mean(dd.^2)), "p50_abs", median(abs(dd)), ...
         "p95_abs", prctile(abs(dd), 95), "max_abs", max(abs(dd)));
      fprintf("%-30s cells %8d  identical %6.2f%%  rmse of the difference %.3f  p95 |diff| %.3f\n", ...
         q1(i).name, q1(i).cells, 100 * q1(i).same / max(q1(i).cells, 1), ...
         q1(i).rmse_diff, q1(i).p95_abs);
   end

   % Where the second pair overlaps, by lead column, to show it is a horizon
   % effect and not a constant offset.
   a = A(:, :, :, 2);  b = A(:, :, :, 3);
   m = isfinite(a) & isfinite(b);
   per_lead = nan(n_h, 1);
   for k = 1:n_h
      mk = m(:, k, :);
      if ~any(mk(:)), continue; end
      dk = double(a(:, k, :)) - double(b(:, k, :));
      per_lead(k) = sqrt(mean(dk(mk).^2));
   end
   have = find(any(m, [1 3]));
   fprintf("PREDISPATCH vs PD7DAY overlap spans columns %d to %d, leads %.1f to %.1f h\n", ...
      have(1), have(end), lead_min(have(1)) / 60, lead_min(have(end)) / 60);

   % ---- Q2 ------------------------------------------------------------------
   O = load(fullfile(fig_dir, "official_60d.mat"), "O4", "SRC4");
   O4 = O.O4;                                     % 288 x 376 x 60 single
   % Official timestamps END the interval, so the run available at the origin of
   % day d is the run that produced day d-1's last interval. The correction for
   % day d therefore uses complete days strictly before d.
   q1_seq = repelem(double(S.q1_by_day(:)), n_s);
   q2_seq = repelem(double(S.q2_by_day(:)), n_s);
   yc = clamp_price(double(S.y_test(:)), [q1_seq, q2_seq]);

   wins = [7 14 28 56];
   res = struct("w", {}, "med", {}, "pooled", {}, "lower", {}, "higher", {}, ...
      "median_diff", {}, "med_lead", {});
   best_w = 0;  best_med = inf;  best_off = nan;
   for wi = 1:numel(wins)
      w = wins(wi);
      Oc = nan(n_s, n_h, numel(d_score), "single");
      for j = 1:numel(d_score)
         d = d_score(j);
         % per-slot bias over the last w complete days before d
         lo = max(1, d - w);
         idxs = lo:(d - 1);
         if isempty(idxs), continue; end
         past = double(O4(:, :, idxs));
         act = reshape(yc, n_s, n_d_full);
         bias = mean(act(:, idxs), 2, "omitnan") - mean(mean(past, 3, "omitnan"), 2, "omitnan");
         Oc(:, :, j) = single(double(O4(:, :, d)) + bias);
      end
      % score on the same grid the deck uses: clamp both sides, RMSE per cell
      Rc = zeros(n_s, n_h);
      Ro = zeros(n_s, n_h);
      for k = 1:n_h
         for j = 1:numel(d_score)
            d = d_score(j);
            tgt = (d - 1) * n_s + (1:n_s)';
            q1v = q1_seq(tgt);  q2v = q2_seq(tgt);
            av = clamp_price(yc(tgt), [q1v, q2v]);
            ov = double(O4(:, k, d));
            cv = double(Oc(:, k, j));
            eo = av - clamp_price(ov, [q1v, q2v]);
            ec = av - clamp_price(cv, [q1v, q2v]);
            Ro(:, k) = Ro(:, k) + eo.^2;
            Rc(:, k) = Rc(:, k) + ec.^2;
         end
      end
      Ro = sqrt(Ro / numel(d_score));
      Rc = sqrt(Rc / numel(d_score));
      off = Rc - Ro;
      res(wi) = struct("w", w, "med", median(Rc(:), "omitnan"), ...
         "pooled", sqrt(mean(Rc(isfinite(Rc)).^2)), ...
         "lower", sum(off(:) < 0, "omitnan"), "higher", sum(off(:) > 0, "omitnan"), ...
         "median_diff", median(off(:), "omitnan"), ...
         "med_lead", median(Rc, 1, "omitnan"));
      fprintf("correction w=%2d: median R %.3f (official %.3f), better in %6d cells, worse in %6d, median diff %+.4f\n", ...
         w, res(wi).med, median(Ro(:), "omitnan"), res(wi).lower, res(wi).higher, res(wi).median_diff);
      if res(wi).med < best_med
         best_med = res(wi).med;  best_w = w;  best_off = Ro;
      end
   end

   % ---- write ---------------------------------------------------------------
   out = struct();
   out.question1 = q1;
   out.overlap = struct("first_col", have(1), "last_col", have(end), ...
      "first_h", lead_min(have(1)) / 60, "last_h", lead_min(have(end)) / 60, ...
      "per_lead_rmse", per_lead(have), "cols", have);
   out.question2 = res;
   out.best_w = best_w;
   out.official_median_R = median(best_off(:), "omitnan");
   out.scored_days = numel(d_score);
   out.n_cells = n_s * n_h;
   txt = jsonencode(out, "PrettyPrint", true);
   fid = fopen(out_json, "w");
   fwrite(fid, txt);
   fclose(fid);
   fprintf("\nwrote %s\n", out_json);
end
