function extract_deck_numbers()
   % EXTRACT_DECK_NUMBERS  Every number the deck quotes, on ONE population.
   %
   %   Read-only. A matfile handle is used so the 415 MB error cube is read one
   %   model's 32-day slab at a time; nothing is ever loaded whole.
   %
   %   WHY THE SURFACE IS REBUILT HERE. atlas_60d.mat stores R over all 60 days
   %   (run_full_ensemble_test.m line 622) while report_figures.m recomputes R
   %   over d_score, the 32 scored days (report_figures.m line 55). The two are
   %   different populations, and the 60-day handover quotes BOTH: section 4.1
   %   is the 60-day surface, sections 4.2 to 4.6 and all twelve figures are the
   %   32-day surface. Every figure, the Diebold-Mariano table, the census, the
   %   combination rules and the official comparison are on the 32-day surface,
   %   and the report's own section 1 asserts 32 samples per cell. So the deck
   %   takes the 32-day surface as canonical and this script prints both, side by
   %   side, so the difference is measured rather than argued.
   %
   %   Judge: the recomputed 32-day census must reproduce the number the figure
   %   run printed at 07:20 (figures_60d_v8.log), official 23574 cells 21.77%.
   %
   %   Output: deck_numbers_60d.json next to the deck tools, plus a printed table.

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   out_json = fullfile(root, "Weekly", "2026-10-13", "deck", "deck_numbers_60d.json");

   atlas = fullfile(fig_dir, "atlas_60d.mat");
   official = fullfile(fig_dir, "official_60d.mat");
   A = matfile(atlas);
   O = matfile(official);

   L = load(atlas, "names", "keys");
   names = string(L.names(:));
   keys = string(L.keys(:));
   lead_min = double(A.lead_min);   lead_min = lead_min(:);
   win_cells = double(A.win_cells); win_cells = win_cells(:);
   P_set = double(A.P_set);         P_set = P_set(:)';
   ar_sel = double(A.ar_sel);
   Rall = double(A.Rall);           Rall = Rall(:);
   comb_name = string(A.comb_name); comb_name = comb_name(:);
   R60 = double(A.R);                       % all 60 days, the atlas's own R
   R_off = double(O.R_off);                 % 32 scored days
   SRC4 = O.SRC4;
   AGE4 = O.AGE4;
   d_score = double(O.d_score);     d_score = d_score(:)';
   ds = d_score;

   n_s = size(R60, 1);  n_h = size(R60, 2);  n_m = size(R60, 3);
   assert(n_m == numel(names), 'model count %d vs %d names', n_m, numel(names));
   assert(numel(lead_min) == n_h, 'lead axis %d vs %d columns', numel(lead_min), n_h);

   % R on the scored days, read slab by slab so the cube is never resident
   fprintf("rebuilding R over days %d to %d, one model slab at a time\n", ds(1), ds(end));
   R = zeros(n_s, n_h, n_m);
   for m = 1:n_m
      e = A.E4(:, :, ds, m);
      R(:, :, m) = sqrt(mean(double(e).^2, 3));
   end
   chk = load(official, "R_off"); %#ok<NASGU>

   want = [60, 1440, 10980];
   col = zeros(1, numel(want));
   for i = 1:numel(want)
      c = find(lead_min == want(i), 1);
      assert(~isempty(c), 'lead %g min is not a column', want(i));
      col(i) = c;
   end
   fprintf("horizon columns %s (leads %s min)\n", mat2str(col), mat2str(lead_min(col)'));

   out = struct();
   out.window = "2026-08-11..2026-10-09";
   out.scored_days = struct('n', numel(ds), 'first', ds(1), 'last', ds(end));
   out.lead_axis = struct('n_col', n_h, 'first_min', lead_min(1), 'last_min', lead_min(end), ...
      'cols_of_interest', col, 'leads_of_interest', lead_min(col)');
   out.n_slot = n_s;

   % ---- per model, both populations side by side --------------------------
   fprintf("\n%-26s %-19s %-19s %-19s\n", "model", "R 32d  1h/24h/7.6d", ...
      "R 60d  1h/24h/7.6d", "cells 32d");
   model = struct([]);
   for m = 1:n_m
      e = struct();
      e.key = keys(m);  e.name = names(m);
      e.med32 = zeros(1, 3);  e.med60 = zeros(1, 3);
      for i = 1:numel(col)
         v32 = R(:, col(i), m);      e.med32(i) = median(v32);
         e.min32(i) = min(v32);      e.max32(i) = max(v32);
         v60 = R60(:, col(i), m);    e.med60(i) = median(v60);
      end
      e.win_cells = win_cells(m);
      e.win_share = 100 * win_cells(m) / (n_s * n_h);
      e.pooled_Rall = Rall(m);
      model = [model; e]; %#ok<AGROW>
      fprintf("%-26s %6.2f %6.2f %6.2f   %6.2f %6.2f %6.2f   %8d\n", names(m), ...
         e.med32(1), e.med32(2), e.med32(3), e.med60(1), e.med60(2), e.med60(3), e.win_cells);
   end
   out.model = model;

   % ---- does the 32-day surface reproduce the figure run? ------------------
   [~, wm] = min(R, [], 3);
   [~, wm3] = min(cat(3, R, R_off), [], 3);
   cand = [names; "Official AEMO composite"];
   wins3 = zeros(numel(cand), 1);
   for c = 1:numel(cand), wins3(c) = sum(wm3(:) == c); end
   fprintf("\ncensus, 32-day surface, official competing (the figure run printed 23574 for the official):\n");
   [s3, i3] = sort(wins3, 'descend');
   for c = 1:numel(i3)
      fprintf("  %-26s %6d  %5.2f%%\n", cand(i3(c)), s3(c), 100*s3(c)/(n_s*n_h));
   end
   out.census_32d_with_official = struct('label', cellstr(cand), 'cells', num2cell(wins3), ...
      'share_pct', num2cell(100*wins3/(n_s*n_h)));
   % ---- census, 32-day surface, models only --------------------------------
   % The stored win_cells was computed from the atlas's own R, which is over all
   % 60 days (run_full_ensemble_test.m lines 620 to 649). It is kept here under a
   % name that says so, and the canonical count is recomputed on the 32-day
   % surface so the census and the official comparison share one population.
   wins_m = zeros(n_m, 1);
   for c = 1:n_m, wins_m(c) = sum(wm(:) == c); end
   for m = 1:n_m
      model(m).win_cells_32d = wins_m(m);
      model(m).win_share_32d = 100 * wins_m(m) / (n_s * n_h);
      model(m).win_cells_60d = win_cells(m);
   end
   out.model = model;
   fprintf("\ncensus, 32-day surface, models only:\n");
   [s2, i2] = sort(wins_m, 'descend');
   for c = 1:numel(i2)
      fprintf("  %-26s %6d  %5.2f%%   (60-day count %6d)\n", names(i2(c)), s2(c), ...
         100*s2(c)/(n_s*n_h), win_cells(i2(c)));
   end
   out.census_32d_models_only = struct('label', cellstr(names), 'cells', num2cell(wins_m), ...
      'share_pct', num2cell(100*wins_m/(n_s*n_h)));

   % ---- official ----------------------------------------------------------
   off = struct();
   for i = 1:numel(col)
      v = R_off(:, col(i));
      off.med(i) = median(v, 'omitnan');
      off.min(i) = min(v, [], 'omitnan');
      off.max(i) = max(v, [], 'omitnan');
      off.n_finite(i) = sum(isfinite(v));
   end
   off.pooled = sqrt(mean(R_off(isfinite(R_off)).^2));
   off.comparable_cells = sum(isfinite(R_off), 'all');
   off.cells_total = n_s * n_h;
   off.median_by_lead = median(R_off, 1, 'omitnan');       % 1 x n_h
   off.coverage_by_lead = sum(isfinite(R_off), 1);         % 1 x n_h
   sr = SRC4(:, :, ds);
   off.src_p5min = sum(sr(:) == 1);
   off.src_predispatch = sum(sr(:) == 2);
   off.src_pd7day = sum(sr(:) == 3);
   off.src_none = sum(sr(:) == 0);
   off.src_cells = numel(sr);
   fprintf("\nofficial, 32 scored days: med 1h %.2f  24h %.2f  7.6d %.2f  pooled %.2f\n", ...
      off.med(1), off.med(2), off.med(3), off.pooled);
   fprintf("official source mix over the %d scored days: P5MIN %.2f%%  PREDISPATCH %.2f%%  PD7DAY %.2f%%  none %.2f%%\n", ...
      numel(ds), 100*off.src_p5min/off.src_cells, 100*off.src_predispatch/off.src_cells, ...
      100*off.src_pd7day/off.src_cells, 100*off.src_none/off.src_cells);
   ag = AGE4(:, :, ds);
   src_lab = ["P5MIN", "PREDISPATCH", "PD7DAY"];
   for p = 1:3
      a = double(ag(sr == p)) / 60;
      a = a(isfinite(a));
      q = quantile(a, [0.05 0.25 0.5 0.75 0.95 1.0]);
      fprintf("age %-12s n=%8d  p05 %.2f  p25 %.2f  med %.2f  p75 %.2f  p95 %.2f  max %.2f h\n", ...
         src_lab(p), numel(a), q(1), q(2), q(3), q(4), q(5), q(6));
      off.age_q{p} = q;
      off.age_median_h(p) = q(3);
      off.age_max_h(p) = q(6);
   end
   out.official = off;

   % ---- coverage, both populations labelled --------------------------------
   % Index with numbers and an explicit colon on every dimension. A LOGICAL
   % index in the middle position collapses the trailing dimension:
   % size(sr(:, logicalMask)) came back [288 11] instead of [288 11 32], which
   % silently turned a 101376-cell coverage count into 3168. Measured, not
   % guessed, in probe_coverage.m.
   c1 = find(lead_min < 60);  c2 = find(lead_min >= 60);
   cov = struct();
   cov.band1_total_60d = n_s * numel(c1) * 60;
   cov.band1_present_60d = sum(SRC4(:, c1, :) ~= 0, 'all');
   cov.band2_total_60d = n_s * numel(c2) * 60;
   cov.band2_present_60d = sum(SRC4(:, c2, :) ~= 0, 'all');
   cov.band1_total_32d = n_s * numel(c1) * numel(ds);
   cov.band1_present_32d = sum(sr(:, c1, :) ~= 0, 'all');
   cov.band2_total_32d = n_s * numel(c2) * numel(ds);
   cov.band2_present_32d = sum(sr(:, c2, :) ~= 0, 'all');
   cov.present_by_lead_60d = reshape(sum(sum(SRC4 ~= 0, 1), 3), 1, []);
   cov.present_by_lead_32d = reshape(sum(sum(sr ~= 0, 1), 3), 1, []);
   fprintf("\ncoverage, 5-55 min band: %d of %d (%.1f%%) over 60 days, %d of %d (%.1f%%) over the 32 scored days\n", ...
      cov.band1_present_60d, cov.band1_total_60d, 100*cov.band1_present_60d/cov.band1_total_60d, ...
      cov.band1_present_32d, cov.band1_total_32d, 100*cov.band1_present_32d/cov.band1_total_32d);
   fprintf("coverage, 60 min-183 h band: %d of %d (%.1f%%) over 60 days, %d of %d (%.1f%%) over the 32 scored days\n", ...
      cov.band2_present_60d, cov.band2_total_60d, 100*cov.band2_present_60d/cov.band2_total_60d, ...
      cov.band2_present_32d, cov.band2_total_32d, 100*cov.band2_present_32d/cov.band2_total_32d);
   cov.probe_lead_min = lead_min(col)';
   cov.probe_present_60d = cov.present_by_lead_60d(col);
   cov.probe_present_32d = cov.present_by_lead_32d(col);
   fprintf("coverage at the probe leads, 60d / 32d, out of %d rows: %s / %s\n", n_s, ...
      mat2str(cov.probe_present_60d), mat2str(cov.probe_present_32d));
   out.coverage = cov;

   % ---- M19 order choice ---------------------------------------------------
   bands = [5 55; 60 240; 270 720; 750 1440; 1470 2880; 2910 5760; 5790 10980];
   blab = ["5-55 min", "1-4 h", "4-12 h", "12-24 h", "1-2 d", "2-4 d", "4-7.6 d"];
   fprintf("\nM19 order choice, share by lead band (%%):\n  %-10s", "band");
   for c = 1:numel(P_set), fprintf("%7s", "p=" + string(P_set(c))); end
   fprintf("\n");
   S = zeros(numel(blab), numel(P_set));
   for b = 1:numel(blab)
      msk = lead_min >= bands(b, 1) & lead_min <= bands(b, 2);
      sel = ar_sel(:, msk);
      fprintf("  %-10s", blab(b));
      for c = 1:numel(P_set)
         S(b, c) = 100 * sum(sel(:) == c) / numel(sel);
         fprintf("%7.1f", S(b, c));
      end
      fprintf("\n");
   end
   m19 = struct();
   m19.P_set = P_set;
   m19.band_label = cellstr(blab);
   m19.share_pct = S;
   m19.share_overall_pct = arrayfun(@(c) 100 * sum(ar_sel(:) == c) / numel(ar_sel), 1:numel(P_set));
   fprintf("  overall   ");
   for c = 1:numel(P_set), fprintf("%7.1f", m19.share_overall_pct(c)); end
   fprintf("\n  cells choosing p=1: %d of %d\n", sum(ar_sel(:) == 1), numel(ar_sel));

   % The handover's section 4.7 reports six discrete probe leads, not bands.
   probe = [5, 60, 360, 1440, 4320, 10980];
   pcol = zeros(1, numel(probe));
   for i = 1:numel(probe), pcol(i) = find(lead_min == probe(i), 1); end
   fprintf("\nM19 order choice at the six probe leads (%%), columns %s:\n  %-10s", ...
      mat2str(pcol), "lead");
   for c = 1:numel(P_set), fprintf("%7s", "p=" + string(P_set(c))); end
   fprintf("\n");
   Sp = zeros(numel(probe), numel(P_set));
   for i = 1:numel(probe)
      sel = ar_sel(:, pcol(i));
      fprintf("  %-10s", lead_label(probe(i)));
      for c = 1:numel(P_set)
         Sp(i, c) = 100 * sum(sel == c) / numel(sel);
         fprintf("%7.1f", Sp(i, c));
      end
      fprintf("\n");
   end
   m19.probe_lead_min = probe;
   m19.probe_label = arrayfun(@(x) lead_label(x), probe);
   m19.probe_share_pct = Sp;

   % ar_sel is the snapshot in force at the END of the window: one order per
   % cell. ar_sel_hist is how many times each order was picked for that cell
   % across the daily re-selections, which is a different question and is what
   % the handover's section 4.7 appears to tabulate.
   hist3 = double(A.ar_sel_hist);
   fprintf("\nsame, from ar_sel_hist (share of daily picks), band view:\n  %-10s", "band");
   for c = 1:numel(P_set), fprintf("%7s", "p=" + string(P_set(c))); end
   fprintf("\n");
   Sh = zeros(numel(blab), numel(P_set));
   for b = 1:numel(blab)
      msk = find(lead_min >= bands(b, 1) & lead_min <= bands(b, 2));
      acc = sum(sum(hist3(:, msk, :), 1), 2);   % 1 x 1 x n_cand
      acc = reshape(acc, 1, []);
      fprintf("  %-10s", blab(b));
      for c = 1:numel(P_set)
         Sh(b, c) = 100 * acc(c) / sum(acc);
         fprintf("%7.1f", Sh(b, c));
      end
      fprintf("\n");
   end
   fprintf("same, at the six probe leads:\n  %-10s", "lead");
   for c = 1:numel(P_set), fprintf("%7s", "p=" + string(P_set(c))); end
   fprintf("\n");
   Shp = zeros(numel(probe), numel(P_set));
   for i = 1:numel(probe)
      acc = reshape(sum(hist3(:, pcol(i), :), 1), 1, []);
      fprintf("  %-10s", lead_label(probe(i)));
      for c = 1:numel(P_set)
         Shp(i, c) = 100 * acc(c) / sum(acc);
         fprintf("%7.1f", Shp(i, c));
      end
      fprintf("\n");
   end
   m19.hist_band_share_pct = Sh;
   m19.hist_probe_share_pct = Shp;
   % Both variants are kept. ar_sel is the order in force at the end of the
   % window; ar_sel_hist is the share of the daily re-picks. The handover's
   % section 4.7 quotes the second, so the deck has to be able to tell them
   % apart from inside the JSON rather than from a console log.
   m19.hist_overall_pct = zeros(1, numel(P_set));
   for c = 1:numel(P_set)
      m19.hist_overall_pct(c) = 100 * sum(sum(sum(hist3(:, :, c), 1), 2), 3) / sum(hist3(:));
   end
   out.m19 = m19;

   % ---- head to head, 32-day surface --------------------------------------
   m20 = find(keys == "T28_ARn", 1);
   m4 = find(keys == "T28_AR4", 1);
   m8 = find(keys == "anchor_mix", 1);
   d = R(:, :, m20) - R(:, :, m4);
   out.m20_vs_m4 = struct('lower', sum(d(:) < 0), 'higher', sum(d(:) > 0), ...
      'ties', sum(d(:) == 0), 'median_diff', median(d(:)), 'cells', numel(d));
   fprintf("\nM20 vs M4, 32-day surface: lower %d  higher %d  ties %d  median %.3f\n", ...
      out.m20_vs_m4.lower, out.m20_vs_m4.higher, out.m20_vs_m4.ties, out.m20_vs_m4.median_diff);

   % ---- which model owns which stretch of the lead axis ---------------------
   % The winner of each cell, cut across the lead, reported as the runs of columns
   % a single model holds over all 288 times of day. This is what the winner maps
   % in the deck show as bands, and a band boundary stated as a time of day and a
   % lead is the only form in which it can be quoted on a slide.
   [~, wm] = min(R, [], 3);
   [~, wr] = min(cat(3, R, R_off), [], 3);
   owner = zeros(1, n_h);
   for c = 1:n_h
      v = wm(:, c);
      [cnt, val] = histc(v, 1:n_m);   %#ok<HISTC>
      [~, best] = max(cnt);
      if cnt(best) > n_s / 2, owner(c) = best; end
   end
   runs = struct('model', {}, 'from_col', {}, 'to_col', {}, 'from_min', {}, 'to_min', {});
   c = 1;
   while c <= n_h
      if owner(c) == 0, c = c + 1; continue; end
      d = c;
      while d < n_h && owner(d + 1) == owner(c), d = d + 1; end
      if d - c + 1 >= 8
         runs(end+1) = struct('model', names(owner(c)), 'from_col', c, 'to_col', d, ...
            'from_min', lead_min(c), 'to_min', lead_min(d)); %#ok<AGROW>
      end
      c = d + 1;
   end
   out.majority_band = runs;   fprintf("\ncolumns where one model wins more than half of the 288 times of day:\n");
   for i = 1:numel(runs)
      fprintf("  %-26s columns %3d..%3d  leads %6g..%6g min\n", runs(i).model, ...
         runs(i).from_col, runs(i).to_col, runs(i).from_min, runs(i).to_min);
   end
   fprintf("  columns with no majority winner: %d of %d\n", sum(owner == 0), n_h);

   % How contested each column is. The winner map looks like bands, and this is
   % the measurement that decides whether a band is one model dominating or the
   % leading model merely having the largest minority.
   lead_share = zeros(1, n_h);
   lead_model = strings(1, n_h);
   for c = 1:n_h
      v = wm(:, c);
      [cnt, ~] = histc(v, 1:n_m);   %#ok<HISTC>
      [best_n, best_i] = max(cnt);
      lead_share(c) = 100 * best_n / n_s;
      lead_model(c) = names(best_i);
   end
   % One struct per column rather than two parallel cell arrays: struct() with
   % cell values requires every non-scalar field to have the same dimensions, and
   % a row of percentages next to a row of names is not that.
   ls = struct('col', {}, 'lead_min', {}, 'model', {}, 'share_pct', {});
   for c = 1:n_h
      ls(c) = struct('col', c, 'lead_min', lead_min(c), ...
         'model', lead_model(c), 'share_pct', lead_share(c));
   end
   out.lead_share = {ls};
   fprintf("the leading model's share of the 288 times of day, by column:\n");
   for c = [1 6 11 12 22 58 97 106 154 202 250 298 328 376]
      fprintf("  col %3d (lead %6g min): %-26s %5.1f%%\n", c, lead_min(c), ...
         lead_model(c), lead_share(c));
   end
   fprintf("  columns where the leading model has more than half: %d of %d\n", ...
      sum(lead_share > 50), n_h);
   fprintf("  columns where it has less than a third: %d of %d\n", ...
      sum(lead_share < 100/3), n_h);

   out.cross_col = find(median(R_off, 1, 'omitnan') > median(R(:, :, find(keys == "T28", 1))), 1);
   fprintf("the official median passes the template's at column %d\n", out.cross_col);

   pick = find(contains(comb_name, "optimal weights") & contains(comb_name, "lead bands") ...
      & contains(comb_name, "shrink 0.3") & ~contains(comb_name, "whole atlas"), 1);
   if ~isempty(pick)
      cs = A.comb_surf;                 % a cell array, so it loads whole
      Cc = double(cs{pick});
      dd = Cc - R(:, :, m8);
      out.comb_vs_anchor = struct('label', comb_name(pick), 'lower', sum(dd(:) < 0), ...
         'higher', sum(dd(:) > 0), 'median_diff', median(dd(:)));
      fprintf("recommended combination vs Anchor-mix: lower %d  higher %d  median %.3f\n", ...
         out.comb_vs_anchor.lower, out.comb_vs_anchor.higher, out.comb_vs_anchor.median_diff);
   end
   comb_all = double(A.comb_all); comb_all = comb_all(:);
   out.comb = struct('label', cellstr(comb_name), 'pooled', num2cell(comb_all));

   % ---- the 48-column banding of the grid ---------------------------------
   % Past the first hour one column is 30 minutes wide, so 48 columns span
   % exactly one day and a lead-independent model repeats itself. This is
   % measured here rather than asserted on a slide, because the claim is that
   % the banding is grid structure and not an artefact of the data.
   band = struct();
   band.lag = 48;
   band.ac = zeros(1, n_m);
   for m = 1:n_m
      v = R(:, :, m);
      xx = v(:, 1:end-band.lag);  yy = v(:, band.lag+1:end);
      xx = xx(:);  yy = yy(:);
      cc = corrcoef(xx, yy);
      band.ac(m) = cc(1, 2);
   end
   % A SCALAR struct whose 'names' field is a cell array of char. Passing
   % cellstr(names) unwrapped makes struct() build an n_m-element struct ARRAY,
   % and then the next field assignment fails with "scalar structure required".
   out.banding = struct('lag', band.lag, 'ac', band.ac, 'names', {cellstr(names(:))'});
   fprintf("\nlag-%d autocorrelation of R along the lead axis, 32-day surface:\n", band.lag);
   for m = 1:n_m
      fprintf("  %-26s %.3f\n", names(m), band.ac(m));
   end
   mt = find(keys == "T28", 1);
   vt = R(:, :, mt);
   ident = all(vt(:, 1:end-1) == vt(:, 2:end), 1);
   same = sum(ident);
   jump = find(~ident);
   out.banding.identical_pairs = same;
   out.banding.pairs = n_h - 1;
   out.banding.differing_cols = (jump + 1);
   out.banding.differing_lead_min = lead_min(jump + 1)';
   % The seven exceptions are 48 columns apart, so their leads differ by exact
   % multiples of 1440 minutes. They are NOT at a multiple of 24 hours from the
   % origin: the first is at 1470 minutes, which is one day plus 30 minutes. The
   % earlier note in the handover said "multiples of 24 hours", which is true of
   % the spacing and false of the position, and the check below is the one that
   % can be run.
   gaps = diff(lead_min(jump + 1));
   out.banding.exceptions_are_daily = all(mod(gaps, 1440) == 0);
   out.banding.exception_gap_min = unique(gaps);
   out.banding.exceptions_at_multiple_of_day = all(mod(lead_min(jump + 1), 1440) == 0);
   fprintf("  Template T28: %d of %d adjacent column pairs are bit-identical\n", same, n_h - 1);
   fprintf("  columns that differ: %s (leads %s min)\n", ...
      mat2str(jump + 1), mat2str(lead_min(jump + 1)'));
   fprintf("  the exceptions are %s minutes apart, all multiples of a day: %d\n", ...
      mat2str(out.banding.exception_gap_min), out.banding.exceptions_are_daily);
   fprintf("  the exception leads themselves sit on a day boundary: %d\n", ...
      out.banding.exceptions_at_multiple_of_day);

   txt = jsonencode(out, "PrettyPrint", true);
   fid = fopen(out_json, "w");
   fwrite(fid, txt, "char");
   fclose(fid);
   fprintf("\nwrote %s (%d bytes)\n", out_json, numel(txt));
end

function s = lead_label(minutes)
   if minutes < 60
      s = sprintf("%g min", minutes);
   elseif minutes < 1440
      s = sprintf("%g h", minutes/60);
   else
      s = sprintf("%g d", minutes/1440);
   end
end
