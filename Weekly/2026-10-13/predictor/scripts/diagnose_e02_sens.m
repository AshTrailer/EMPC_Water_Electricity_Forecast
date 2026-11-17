function diagnose_e02_sens()
   % DIAGNOSE_E02_SENS  Does the published demand-to-price slope carry band information?
   %
   % E02 gate, as registered: the pre-dispatch sensitivity ladder is the price
   % AEMO's own engine would produce if VIC1 demand moved by a fixed offset, so
   % it is a direct read of the supply curve at the forecast operating point. The
   % question is whether that slope explains the band error we cannot remove.
   %
   % Two things are established before any number is trusted.
   %
   %   1. The scenario ladder is monotone. If price did not rise with the demand
   %      offset, the column order would be wrong and every slope would be noise.
   %
   %   2. The base case price is the benchmark. The ladder is anchored on it, so
   %      a channel that contains it would be reading the answer. Every channel
   %      below is a difference between rungs and never the level. That is
   %      checked, not assumed: the base case price is compared with the official
   %      surface cell by cell, and a channel that turns out to contain the level
   %      is reported as inadmissible rather than used.
   %
   % The channels, all free of the price level:
   %   b2    (P+200 - P-200) / 400, the slope at the operating point, $/MWh per MW
   %   b5    (P+500 - P-500) / 1000, the same further out
   %   curv  the up-side slope between +500 and +1000 less the near slope between
   %         +100 and +200, $/MWh per MW; positive means the curve steepens
   %
   % Writes research/verify/e02_sens.json.
   % Run: runs\run_diagnose_e02_sens.bat <log name>

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   win = fullfile(root, "AEMO_Data", "window_60d_20260811_20261009_vic1");
   out_dir = fullfile(root, "Weekly", "2026-10-13", "research", "verify");
   if ~exist(out_dir, "dir"), mkdir(out_dir); end
   addpath(genpath(fullfile(root, "Predicitor")));

   n_s = 288;
   [lead_min, ~] = official_lead_axis();
   lead_min = lead_min(:)';
   band = find(lead_min >= 360 & lead_min <= 1440);
   c_1h = find(lead_min == 60, 1);
   n_b = numel(band);
   jd_score = 29:60;
   n_day = numel(jd_score);
   days_all = 1:60;
   t0 = double(nem_minutes("2026-08-11 00:00:00"));
   dow = weekday(datetime(2026, 8, 11) + days(0:59));
   is_weekend = (dow == 1) | (dow == 7);

   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   o_score = double(O.d_score);  o_score = o_score(:)';
   assert(isequal(o_score, jd_score), "e02:days", "the atlas scores days other than 29 to 60");
   names = string(A.names);
   k_a = find(names == "Anchor-mix", 1);
   assert(~isempty(k_a), "e02:anchor", "Anchor-mix is not in the atlas");

   R_off = double(O.R_off);
   Ebo = double(O.E4_off(:, band, o_score));
   Eb_anc = double(A.E4(:, band, o_score, k_a));
   E1a = reshape(double(A.E4(:, c_1h, o_score, k_a)), n_s, 1, n_day);
   Eb_fit = double(A.E4(:, band, 1:28, k_a));

   colR_off = median(R_off(:, band), 1, "omitnan");
   colR_anc = median(sqrt(mean(Eb_anc .^ 2, 3, "omitnan")), 1, "omitnan");
   rat_anc = colR_anc ./ colR_off;
   fprintf("calibration: official band median R %.3f, Anchor-mix %.3f, ratio of column medians %.4f\n", ...
      median(colR_off), median(colR_anc), median(rat_anc));
   assert(abs(median(colR_off) - 29.395) < 0.05, "e02:cal", ...
      "the official band median R is not the registered 29.395");

   % ======================================================================
   fprintf("\n=== 1) the sensitivity ladder ===\n");
   [P, eff_s, scen_mw, ref] = predispatch_sens_load(fullfile(win, "sens_vic1.csv"));
   [B0m, eff_b] = base_price_matrix(fullfile(win, "predispatch_30min_VIC1.csv"));
   fprintf("  base case runs %d, effective times shared with the ladder %d of %d\n", ...
      numel(eff_b), numel(intersect(double(eff_b), double(eff_s))), numel(eff_s));

   p8 = P(:, :, 1);   p9 = P(:, :, 2);   p10 = P(:, :, 3);  p11 = P(:, :, 4);
   p12 = P(:, :, 5);  p13 = P(:, :, 6);  p14 = P(:, :, 7);
   okc = all(isfinite(P), 3);
   n_ok = sum(okc, "all");
   up_ok = okc & (p8 <= p10) & (p10 <= p12) & (p12 <= p14);
   dn_ok = okc & (p13 <= p11) & (p11 <= p9);
   fprintf("  cells with all seven rungs: %d of %d (%.1f%%)\n", n_ok, numel(okc), ...
      100 * n_ok / numel(okc));
   fprintf("  five-rung up chain monotone %.2f%%, three-rung down chain monotone %.2f%%\n", ...
      100 * sum(up_ok, "all") / n_ok, 100 * sum(dn_ok, "all") / n_ok);
   % An inversion of a few cents is rounding, not a wrong column order, so the
   % size of the worst inversion is what says whether the ladder is usable.
   out_up = okc & ~up_ok;
   mag_up = max(max(p8 - p10, p10 - p12), p12 - p14);
   out_dn = okc & ~dn_ok;
   mag_dn = max(p13 - p11, p11 - p9);
   fprintf("  up chain inversions: median %.3f, p99 %.3f, max %.3f $/MWh\n", ...
      median(mag_up(out_up)), prctile(mag_up(out_up), 99), max(mag_up(out_up)));
   fprintf("  down chain inversions: median %.3f, p99 %.3f, max %.3f $/MWh\n", ...
      median(mag_dn(out_dn)), prctile(mag_dn(out_dn), 99), max(mag_dn(out_dn)));
   fprintf("  inversions larger than 1 $/MWh: up %.2f%%, down %.2f%% of all cells\n", ...
      100 * sum(mag_up > 1, "all") / n_ok, 100 * sum(mag_dn > 1, "all") / n_ok);
   fprintf("  sens effective times span %.1f days, first %s, last %s\n", ...
      (eff_s(end) - eff_s(1)) / 1440, ...
      char(datetime(2025, 1, 1) + minutes(double(eff_s(1))), "yyyy-MM-dd HH:mm"), ...
      char(datetime(2025, 1, 1) + minutes(double(eff_s(end))), "yyyy-MM-dd HH:mm"));

   [~, ia, ib] = intersect(double(eff_b), double(eff_s));
   B0p = B0m(ia, :);
   Pp = P(ib, :, :);
   okj = okc(ib, :) & isfinite(B0p);
   inside = okj & B0p >= Pp(:, :, 2) & B0p <= Pp(:, :, 1);
   fprintf("  base case price inside the minus 100 and plus 100 bracket: %.2f%% of %d cells\n", ...
      100 * sum(inside, "all") / sum(okj, "all"), sum(okj, "all"));

   B0 = predispatch_on_grid(B0p, eff_s(ib), t0, days_all, band, lead_min, n_s);
   O4 = double(O.O4(:, band, o_score));
   d0 = B0(:, :, jd_score) - O4;
   fin = isfinite(d0);
   leak = struct("paired", sum(fin, "all"), "frac_close", mean(abs(d0(fin)) < 0.01), ...
      "median_abs", median(abs(d0(fin))), "p99_abs", prctile(abs(d0(fin)), 99));
   fprintf("  base case price against the official surface on band cells: %d of %d paired\n", ...
      leak.paired, numel(d0));
   fprintf("    median |diff| %.4f, 99th %.4f, share within 0.01 %.2f%%\n", ...
      leak.median_abs, leak.p99_abs, 100 * leak.frac_close);

   % ======================================================================
   fprintf("\n=== 2) the channels on the cube grid ===\n");
   b2 = (p10 - p11) / 400;
   b5 = (p12 - p13) / 1000;
   curv = (p14 - p12) / 500 - (p10 - p8) / 100;
   [B2, ~] = predispatch_on_grid(b2, eff_s, t0, days_all, band, lead_min, n_s);
   [B5, ~] = predispatch_on_grid(b5, eff_s, t0, days_all, band, lead_min, n_s);
   [CV, ~] = predispatch_on_grid(curv, eff_s, t0, days_all, band, lead_min, n_s);
   v2 = 100 * B2(:, :, jd_score);  v2 = v2(isfinite(v2));
   vc = 100 * CV(:, :, jd_score);  vc = vc(isfinite(vc));
   fprintf("  coverage on band cells of the scored days: b2 %.1f%%, b5 %.1f%%, curv %.1f%%\n", ...
      100 * mean(isfinite(B2(:, :, jd_score)), "all"), ...
      100 * mean(isfinite(B5(:, :, jd_score)), "all"), ...
      100 * mean(isfinite(CV(:, :, jd_score)), "all"));
   fprintf("  b2 $/MWh per 100 MW: median %.2f, p10 %.2f, p90 %.2f, exactly zero %d of %d\n", ...
      median(v2), prctile(v2, 10), prctile(v2, 90), sum(v2 == 0), numel(v2));
   fprintf("  curv $/MWh per 100 MW: median %.2f, p10 %.2f, p90 %.2f\n", ...
      median(vc), prctile(vc, 10), prctile(vc, 90));

   bylead = [360 480 720 1080 1440];
   b2_lead = nan(1, numel(bylead));
   fprintf("\n  b2 by lead, $/MWh per 100 MW\n");
   for i = 1:numel(bylead)
      c = find(band == find(lead_min == bylead(i), 1), 1);
      v = 100 * B2(:, c, jd_score);
      b2_lead(i) = median(v(isfinite(v)));
      fprintf("    %4.1f h  %7.2f\n", bylead(i) / 60, b2_lead(i));
   end
   hr = floor((0:n_s-1)' * 5 / 60);
   b2_hr = nan(24, 1);  b2_lo = nan(24, 1);  b2_hi = nan(24, 1);
   for h = 0:23
      v = 100 * B2(hr == h, :, jd_score);
      v = v(isfinite(v));
      b2_hr(h + 1) = median(v);
      b2_lo(h + 1) = prctile(v, 25);
      b2_hi(h + 1) = prctile(v, 75);
   end
   fprintf("\n  b2 by hour of day, $/MWh per 100 MW\n   ");
   fprintf("%6.1f", b2_hr);
   fprintf("\n");

   % ======================================================================
   fprintf("\n=== 3) gate: band error against each channel, within slot ===\n");
   B2b = B2(:, :, jd_score);  B5b = B5(:, :, jd_score);  CVb = CV(:, :, jd_score);
   dd = 1:n_day;
   [g.r2_b2, g.b_b2, g.t_b2] = gate_pooled(Eb_anc, B2b, 1:n_b, dd);
   [g.r2_b5, g.b_b5, g.t_b5] = gate_pooled(Eb_anc, B5b, 1:n_b, dd);
   [g.r2_cv, g.b_cv, g.t_cv] = gate_pooled(Eb_anc, CVb, 1:n_b, dd);
   [g.r2_b2o, g.b_b2o, g.t_b2o] = gate_pooled(Ebo, B2b, 1:n_b, dd);
   [g.r2_cvo, g.b_cvo, g.t_cvo] = gate_pooled(Ebo, CVb, 1:n_b, dd);
   fprintf("  channel      ours R2   ours t    official R2  official t   cells\n");
   fprintf("  b2         %9.5f %8.2f %13.5f %11.2f\n", g.r2_b2, g.t_b2, g.r2_b2o, g.t_b2o);
   fprintf("  b5         %9.5f %8.2f\n", g.r2_b5, g.t_b5);
   fprintf("  curv       %9.5f %8.2f %13.5f %11.2f\n", g.r2_cv, g.t_cv, g.r2_cvo, g.t_cvo);

   r2_b2_col = nan(1, n_b);  t_b2_col = nan(1, n_b);  r2_cv_col = nan(1, n_b);
   for i = 1:n_b
      [r2_b2_col(i), ~, t_b2_col(i)] = gate_pooled(Eb_anc, B2b, i, dd);
      [r2_cv_col(i), ~, ~] = gate_pooled(Eb_anc, CVb, i, dd);
   end
   fprintf("  by lead on b2: 6 h %.5f, 8 h %.5f, 12 h %.5f, 18 h %.5f, 24 h %.5f\n", ...
      r2_b2_col(band == find(lead_min == 360, 1)), ...
      r2_b2_col(band == find(lead_min == 480, 1)), ...
      r2_b2_col(band == find(lead_min == 720, 1)), ...
      r2_b2_col(band == find(lead_min == 1080, 1)), ...
      r2_b2_col(band == find(lead_min == 1440, 1)));
   fprintf("  columns above the 1%% gate: b2 %d of %d, curv %d of %d\n", ...
      sum(r2_b2_col > 0.01), n_b, sum(r2_cv_col > 0.01), n_b);

   % ======================================================================
   fprintf("\n=== 4) ceiling: the slope against a demand surprise ===\n");
   Yd = load_actual_demand(fullfile(root, "AEMO_Data"), t0, n_s);
   Na = nan(n_s, 2);
   for w = 1:2
      sel = (is_weekend == (w == 2)) & ((1:60) <= 28);
      if any(sel), Na(:, w) = mean(Yd(:, sel), 2, "omitnan"); end
   end
   dt = 1 + double(is_weekend);
   Aa = Yd ./ Na(:, dt) - 1;
   av = Aa(:, jd_score);
   fprintf("  realised demand anomaly at the target: median %.4f, p10 %.4f, p90 %.4f\n", ...
      median(av, "all", "omitnan"), prctile(av(isfinite(av)), 10), ...
      prctile(av(isfinite(av)), 90));
   Ab = repmat(reshape(Aa(:, jd_score), n_s, 1, n_day), 1, n_b, 1);
   [g.r2_a, g.b_a, g.t_a] = gate_pooled(Eb_anc, Ab, 1:n_b, dd);
   g.r2_ba = gate_pooled(Eb_anc, B2b .* Ab, 1:n_b, dd);
   [g.r2_ab, g.b_a2, g.b_b22, g.t_a2, g.t_b22] = gate_two(Eb_anc, Ab, B2b, 1:n_b, dd);
   fprintf("  ours: anomaly alone %.5f (t %.2f), slope times anomaly %.5f, both %.5f\n", ...
      g.r2_a, g.t_a, g.r2_ba, g.r2_ab);
   fprintf("        with both: anomaly t %.2f, slope t %.2f\n", g.t_a2, g.t_b22);
   [g.r2_a_o, g.b_a_o, g.t_a_o] = gate_pooled(Ebo, Ab, 1:n_b, dd);
   g.r2_ab_o = gate_two(Ebo, Ab, B2b, 1:n_b, dd);
   fprintf("  official: anomaly alone %.5f (t %.2f), both %.5f\n", ...
      g.r2_a_o, g.t_a_o, g.r2_ab_o);

   % ======================================================================
   fprintf("\n=== 5) candidate: a per-column slope correction, fitted on days 1 to 28 ===\n");
   [a1, mx] = fit_col(Eb_fit, B2(:, :, 1:28));
   fprintf("  fitted slope: median %.4f, p10 %.4f, p90 %.4f, negative %d of %d\n", ...
      median(a1), prctile(a1, 10), prctile(a1, 90), sum(a1 < 0), n_b);
   Eb_c = Eb_anc;
   for i = 1:n_b
      x = B2b(:, i, :) - mx(:, i);
      Eb_c(:, i, :) = Eb_anc(:, i, :) - a1(i) * x;
   end
   base = band_report(Eb_anc, E1a, Ebo, colR_off);
   cand = band_report(Eb_c, E1a, Ebo, colR_off);
   fprintf("  anchor  band median R %.3f, ratio %.4f, 1 h %.3f, 24 h %.3f, cells ahead %.1f%%\n", ...
      base.mR, base.ratio, base.r1, base.r24, 100 * base.frac_win);
   fprintf("  + slope band median R %.3f, ratio %.4f, 1 h %.3f, 24 h %.3f, cells ahead %.1f%%\n", ...
      cand.mR, cand.ratio, cand.r1, cand.r24, 100 * cand.frac_win);
   [nb, nw] = dm_cells(Eb_c, Eb_anc);
   fprintf("  DM against the anchor: better %d, worse %d of %d band cells\n", nb, nw, n_s * n_b);

   % ======================================================================
   res = struct();
   res.ref = ref;
   res.ladder = struct("cells", n_ok, "frac_all", n_ok / numel(okc), ...
      "up_monotone", sum(up_ok, "all") / n_ok, "down_monotone", sum(dn_ok, "all") / n_ok, ...
      "base_inside", sum(inside, "all") / sum(okj, "all"));
   res.leak = leak;
   res.b2 = struct("median100", median(v2), "p10_100", prctile(v2, 10), ...
      "p90_100", prctile(v2, 90), "zero", sum(v2 == 0), "n", numel(v2), ...
      "by_lead_h", bylead / 60, "by_lead_100", b2_lead, ...
      "by_hour_100", b2_hr', "by_hour_p25", b2_lo', "by_hour_p75", b2_hi', ...
      "cover", mean(isfinite(B2(:, :, jd_score)), "all"));
   res.gate = g;
   res.gate_col = struct("lead_h", lead_min(band) / 60, "r2_b2", r2_b2_col, ...
      "t_b2", t_b2_col, "r2_curv", r2_cv_col);
   res.base = base;
   res.cand = cand;
   res.dm = struct("better", nb, "worse", nw, "cells", n_s * n_b);
   res.fit = struct("a1_median", median(a1), "a1_p10", prctile(a1, 10), ...
      "a1_p90", prctile(a1, 90), "a1_negative", sum(a1 < 0));
   res.baseline = struct("official_band_median", median(colR_off), ...
      "anchor_band_median", median(colR_anc), "ratio", median(rat_anc));
   f = fullfile(out_dir, "e02_sens.json");
   fid = fopen(f, "w");
   fwrite(fid, jsonencode(res), "char");
   fclose(fid);
   fprintf("\nwrote %s\n", f);
end

% =========================================================================
function [B0, eff_r] = base_price_matrix(csv)
   % The base case pre-dispatch price as a run by horizon matrix.
   fid = fopen(csv, "r");
   assert(fid > 0, "e02:base", "cannot open %s", csv);
   c = textscan(fid, "%s %s %s %f %f %f %f %f %f %s", "Delimiter", ",", ...
      "HeaderLines", 1, "ReturnOnError", false);
   fclose(fid);
   eff = nem_minutes(c{1});
   tgt = nem_minutes(c{3});
   lag = tgt - eff;
   [eff_r, ~, k] = unique(eff);
   n_run = numel(eff_r);
   col = double(lag / 30) + 1;
   n_col = max(col);
   B0 = nan(n_run, n_col);
   B0(sub2ind([n_run, n_col], double(k), col)) = c{5};
   last = accumarray(double(k), double(col), [n_run 1], @max);
   fill_p = sum(isfinite(B0), 2);
   assert(isequal(fill_p(:), last(:)), "e02:base_layout", ...
      "the base case matrix does not fill each run's own horizon");
end

% =========================================================================
function [a1, mx] = fit_col(E, X)
   % One slope per band column on within-slot demeaned data, plus the slot mean
   % of the channel over the fitting days. The centring constant comes from the
   % fitting window only, so the correction is applied out of sample.
   n_s = size(E, 1);
   n_b = size(E, 2);
   a1 = zeros(1, n_b);
   mx = nan(n_s, n_b);
   for i = 1:n_b
      xi = X(:, i, :);
      mx(:, i) = mean(xi, 3, "omitnan");
      y = [];  v = [];
      for k = 1:size(E, 3)
         e = E(:, i, k);
         x = xi(:, k);
         ok = isfinite(e) & isfinite(x);
         if sum(ok) < 3, continue; end
         y = [y; e(ok) - mean(e(ok))]; %#ok<AGROW>
         v = [v; x(ok) - mean(x(ok))]; %#ok<AGROW>
      end
      if numel(v) < 30 || sum(v .^ 2) <= 0, continue; end
      a1(i) = (v' * y) / (v' * v);
   end
end

% =========================================================================
function r = band_report(EB, E1B, EA, colR_off)
   % The section 7 shape: band column medians, ratio to official, the 1 h and
   % 24 h columns, and the share of band cells ahead of official.
   colR = median(sqrt(mean(EB .^ 2, 3, "omitnan")), 1, "omitnan");
   r.mR = median(colR);
   r.ratio = median(colR ./ colR_off);
   r.r1 = median(sqrt(mean(E1B .^ 2, 3, "omitnan")), "omitnan");
   r.r24 = colR(end);
   r.frac_win = mean(EB .^ 2 < EA .^ 2, "all", "omitnan");
end

% =========================================================================
function Yd = load_actual_demand(data_dir, t0, n_s)
   % The realised regional demand at each target instant, as a slot by day grid.
   % Monthly PRICE_AND_DEMAND files carry REGION, SETTLEMENTDATE, TOTALDEMAND,
   % RRP, PERIODTYPE, so demand is column 3 and the timestamp column 2.
   months = ["202608", "202609", "202610"];
   tm = [];  dm = [];
   for i = 1:numel(months)
      p = fullfile(data_dir, sprintf("PRICE_AND_DEMAND_%s_VIC1.csv", months(i)));
      assert(isfile(p), "e02:actual", "no realised demand file at %s", p);
      fid = fopen(p, "r");
      assert(fid > 0, "e02:actual_open", "cannot open %s", p);
      c = textscan(fid, "%s %s %f %f %s", "Delimiter", ",", "HeaderLines", 1, ...
         "ReturnOnError", false);
      fclose(fid);
      tm = [tm; double(nem_minutes(strrep(c{2}, "/", "-")))]; %#ok<AGROW>
      dm = [dm; c{3}]; %#ok<AGROW>
   end
   [tm, ord] = sort(tm);
   dm = dm(ord);
   keep = [true; diff(tm) > 0];
   tm = tm(keep);  dm = dm(keep);

   Yd = nan(n_s, 60);
   for d = 1:60
      t = t0 + (d - 1) * 1440 + 5 * (0:n_s-1)';
      k = interp1(tm, (1:numel(tm))', t, "nearest", NaN);
      ok = isfinite(k);
      assert(max(abs(tm(k(ok)) - t(ok))) == 0, "e02:actual_grid", ...
         "a target instant is not on the settlement grid");
      Yd(ok, d) = dm(k(ok));
   end
   fprintf("  realised demand matched at %d of %d target instants (%.1f%%)\n", ...
      sum(isfinite(Yd), "all"), numel(Yd), 100 * mean(isfinite(Yd), "all"));
end

% =========================================================================
function [r2, b, t] = gate_pooled(E, X, cols, days)
   % Within-slot correlation between the error and a channel, pooled over the
   % requested columns and days. Each cell is centred on its own slot mean over
   % those days, so the slot level is out of the regression.
   y = [];  v = [];  g = [];
   for i = 1:numel(cols)
      for k = 1:numel(days)
         e = E(:, cols(i), k);
         x = X(:, cols(i), days(k));
         ok = isfinite(e) & isfinite(x);
         cnt = sum(ok);
         if cnt < 3, continue; end
         ec = e;  ec(~ok) = 0;
         xc = x;  xc(~ok) = 0;
         ed = (ec - sum(ec) / cnt) .* ok;
         xd = (xc - sum(xc) / cnt) .* ok;
         y = [y; ed(ok)];  v = [v; xd(ok)]; %#ok<AGROW>
         g = [g; repmat(k, cnt, 1)]; %#ok<AGROW>
      end
   end
   if isempty(v) || sum(v .^ 2) <= 0
      r2 = NaN;  b = NaN;  t = NaN;  return;
   end
   b = (v' * y) / (v' * v);
   r2 = (v' * y) ^ 2 / ((v' * v) * (y' * y));
   u = y - b * v;
   ng = max(g);
   sg = accumarray(g, v .* u, [ng 1]);
   vb = sum(sg .^ 2) / (v' * v) ^ 2 * ng / (ng - 1);
   t = b / sqrt(vb);
end

% =========================================================================
function [r2, b1, b2, t1, t2] = gate_two(E, X1, X2, cols, days)
   % Two channels at once, within slot, with cluster robust t on both.
   y = [];  v1 = [];  v2 = [];  g = [];
   for i = 1:numel(cols)
      for k = 1:numel(days)
         e = E(:, cols(i), k);
         a = X1(:, cols(i), days(k));
         c = X2(:, cols(i), days(k));
         ok = isfinite(e) & isfinite(a) & isfinite(c);
         cnt = sum(ok);
         if cnt < 5, continue; end
         ed = e;  ad = a;  cd = c;
         ed(~ok) = 0;  ad(~ok) = 0;  cd(~ok) = 0;
         ed = (ed - sum(ed) / cnt) .* ok;
         ad = (ad - sum(ad) / cnt) .* ok;
         cd = (cd - sum(cd) / cnt) .* ok;
         y = [y; ed(ok)];  v1 = [v1; ad(ok)];  v2 = [v2; cd(ok)]; %#ok<AGROW>
         g = [g; repmat(k, cnt, 1)]; %#ok<AGROW>
      end
   end
   if isempty(y)
      r2 = NaN;  b1 = NaN;  b2 = NaN;  t1 = NaN;  t2 = NaN;  return;
   end
   V = [v1 v2];
   bb = (V' * V) \ (V' * y);
   b1 = bb(1);  b2 = bb(2);
   r2 = 1 - sum((y - V * bb) .^ 2) / sum(y .^ 2);
   u = y - V * bb;
   ng = max(g);
   S = zeros(2, 2);
   for k = 1:ng
      m = (g == k);
      z = V(m, :)' * u(m);
      S = S + z * z';
   end
   S = S * ng / (ng - 1);
   A = (V' * V) \ S / (V' * V);
   t1 = b1 / sqrt(A(1, 1));
   t2 = b2 / sqrt(A(2, 2));
end

% =========================================================================
function [n_better, n_worse] = dm_cells(EA, EB)
   % Per-cell paired Diebold-Mariano with HAC and BH control, the same form as
   % compare_surfaces: a positive loss differential means B has the larger error.
   D = EA .^ 2 - EB .^ 2;
   [n_s, n_b, n_d] = size(D);
   D = reshape(D, n_s * n_b, n_d);
   mu = mean(D, 2, "omitnan");
   L = min(10, n_d - 1);
   vh = mean(D .^ 2, 2, "omitnan") - mu .^ 2;
   for l = 1:L
      gl = mean(D(:, 1+l:end) .* D(:, 1:end-l), 2, "omitnan") - mu .^ 2;
      vh = vh + 2 * (1 - l / (L + 1)) * gl;
   end
   vh = max(vh, 1e-12);
   dm = mu ./ sqrt(vh / n_d);
   pv = erfc(abs(dm) / sqrt(2));
   m = numel(pv);
   [ps, ord] = sort(pv);
   k_max = find(ps <= (1:m)' / m * 0.05, 1, "last");
   if isempty(k_max), k_max = 0; end
   sig = false(m, 1);
   if k_max > 0, sig(ord(1:k_max)) = true; end
   n_better = sum(sig & mu > 0);
   n_worse = sum(sig & mu < 0);
end
