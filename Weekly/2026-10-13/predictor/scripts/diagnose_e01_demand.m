function diagnose_e01_demand()
   % DIAGNOSE_E01_DEMAND  Does the AEMO demand forecast carry band information we lack?
   %
   % E01 gate, as registered: regress the band error on the demand forecast's
   % deviation from its seasonal norm and read the partial R squared. Below 1 per
   % cent the channel is abandoned.
   %
   % Four things this script refuses to assume:
   %
   %   1. That total_demand in the PREDISPATCH file is a forecast. If one target
   %      carried a single value across every run it would be the realised
   %      demand, which is a leak. The spread across runs is measured first and
   %      the run aborts if it is absent.
   %   2. That the gate is the verdict. A demand anomaly that explains band error
   %      on the fitting days may explain nothing out of sample, so the candidate
   %      is fitted on days 1 to 28 and scored on days 29 to 60, which is the
   %      atlas split and leaves the scored days untouched by the fit.
   %   3. That a positive R squared means the pool has missed the channel. Every
   %      model in the atlas is put against the same regressor, so a channel one
   %      model already absorbs shows up as a low R squared there.
   %   4. That the correction is a bias fix. It carries no intercept on purpose:
   %      x already has zero mean over the fitting days slot by slot, so a
   %      constant would only re-fit the night bias that N16 rejected and the two
   %      effects would stop being separable.
   %
   % Cube addressing as everywhere else: a cell is indexed by its target slot and
   % target day. The origin of a cell is target minus lead, and the demand
   % forecast used is the last PREDISPATCH run published at or before that origin.
   %
   % Writes research/verify/e01_demand.json.
   % Run: runs\run_diagnose_e01_demand.bat <log name>

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
   c_24h = find(lead_min == 1440, 1);
   n_b = numel(band);
   jd_score = 29:60;

   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   o_score = double(O.d_score);  o_score = o_score(:)';
   n_day = numel(o_score);
   assert(isequal(o_score, jd_score), "e01:days", "the atlas scores days other than 29 to 60");
   names = string(A.names);
   n_m = numel(names);
   k_a = find(names == "Anchor-mix", 1);
   assert(~isempty(k_a), "e01:anchor", "Anchor-mix is not in the atlas");

   R_off = double(O.R_off);
   Ebo = double(O.E4_off(:, band, o_score));
   E1o = reshape(double(O.E4_off(:, c_1h, o_score)), n_s, 1, n_day);
   Eb_anc = double(A.E4(:, band, o_score, k_a));
   E1a = reshape(double(A.E4(:, c_1h, o_score, k_a)), n_s, 1, n_day);
   Eb_fit = double(A.E4(:, band, 1:28, k_a));
   Eb_off_fit = double(O.E4_off(:, band, 1:28));

   % calibration against the registered baseline, so a definition slip shows up
   % here and not inside a conclusion
   colR_off = median(R_off(:, band), 1, "omitnan");
   colR_anc = median(sqrt(mean(Eb_anc .^ 2, 3, "omitnan")), 1, "omitnan");
   rat_anc = colR_anc ./ colR_off;
   fprintf("official   column-median R over the band: median %8.3f  (registered 29.395)\n", ...
      median(colR_off));
   fprintf("anchor-mix column-median R over the band: median %8.3f  (registered 41.040)\n", ...
      median(colR_anc));
   fprintf("anchor-mix band ratio: median of the column ratios %6.3f (registered 1.333), " + ...
      "ratio of the medians %6.3f\n", median(rat_anc), median(colR_anc) / median(colR_off));
   fprintf("           per column ratio runs %.3f to %.3f; 1 h %7.3f vs %7.3f; " + ...
      "24 h %7.3f vs %7.3f\n", min(rat_anc), max(rat_anc), ...
      median(sqrt(mean(E1a .^ 2, 3, "omitnan"))), median(sqrt(mean(E1o .^ 2, 3, "omitnan"))), ...
      median(sqrt(mean(Eb_anc(:, end, :) .^ 2, 3, "omitnan"))), ...
      median(sqrt(mean(Ebo(:, end, :) .^ 2, 3, "omitnan"))));

   % ======================================================================
   % 1) the demand series, and the guard on whether it is a forecast
   % ======================================================================
   fprintf("\n=== 1) PREDISPATCH total_demand ===\n");
   [DEM, eff_r, n_col_dem, same] = predispatch_demand_load(fullfile(win, ...
      "predispatch_30min_VIC1.csv"));
   assert(same(1) / same(2) < 0.02, "e01:leak", ...
      "total_demand repeats per target, so it is realised demand and not a forecast");

   % ======================================================================
   % 2) the demand forecast on the cube's grid, and the seasonal anomaly
   % ======================================================================
   t0 = double(nem_minutes("2026-08-11 00:00:00"));
   tz = datetime(2025, 1, 1) + minutes(t0);
   assert(abs(tz - datetime(2026, 8, 11)) < minutes(1), "e01:epoch", ...
      "day 1 of the 60-day window is not 2026-08-11");
   days_all = 1:60;
   dow = weekday(tz + days(days_all - 1));
   is_weekend = (dow == 1) | (dow == 7);
   fprintf("  day 1 %s weekday, %d weekend days in the 28 fitting days\n", ...
      string(tz, "yyyy-MM-dd"), sum(is_weekend(1:28)));

   cols_need = unique([c_1h, band]);
   j_band = find(ismember(cols_need, band));
   j_1h = find(cols_need == c_1h);
   [X, dinfo] = predispatch_on_grid(DEM, eff_r, t0, days_all, ...
      cols_need, lead_min, n_s);
   fprintf("  on the cube grid: %d of %d cells (%.2f%%); no run before the origin %d, " + ...
      "run stops short of the target %d\n", dinfo.filled, dinfo.total, ...
      100 * dinfo.filled / dinfo.total, dinfo.no_run, ...
      dinfo.no_next_frac + dinfo.no_base);

   N = norm_profile(X, days_all, is_weekend);
   daytype = 1 + double(is_weekend);
   xx = X ./ N(:, :, daytype) - 1;
   xv = reshape(xx(:, j_band, jd_score), [], 1);
   xv = xv(isfinite(xv));
   fprintf("  anomaly x = demand / seasonal norm - 1, band cells of the scored days:\n");
   fprintf("     median %+.4f  p1 %+.4f  p99 %+.4f  max|.| %.4f  sd %.4f\n", ...
      median(xv), prctile(xv, 1), prctile(xv, 99), max(abs(xv)), std(xv));
   fprintf("  across-lead spread of one target's demand forecast, median relative range %.4f\n", ...
      lead_spread(X(:, j_band, :)));

   xxb = xx(:, j_band, :);
   avb = reshape(mean(isfinite(xxb), [1 3]), 1, n_b);
   lb = lead_min(band);
   pickL = @(L) find(lb == L, 1);
   fprintf("  band availability at the origin, by lead: 6 h %5.1f%%  12 h %5.1f%%  " + ...
      "18 h %5.1f%%  24 h %5.1f%%  lowest %5.1f%%\n", 100 * avb(pickL(360)), ...
      100 * avb(pickL(720)), 100 * avb(pickL(1080)), 100 * avb(pickL(1440)), 100 * min(avb));

   % ======================================================================
   % 3) the gate, and the same regressor against every model in the atlas
   % ======================================================================
   fprintf("\n=== 2) gate: band error against the demand anomaly, within slot ===\n");
   [r2_a, b_a, t_a] = gate_pooled(Eb_anc, xxb, 1:n_b, jd_score);
   [r2_o, b_o, t_o] = gate_pooled(Ebo, xxb, 1:n_b, jd_score);
   fprintf("  Anchor-mix  R2 %8.4f  b %+9.2f  cluster t %+6.2f\n", r2_a, b_a, t_a);
   fprintf("  official    R2 %8.4f  b %+9.2f  cluster t %+6.2f\n", r2_o, b_o, t_o);

   r2_col_a = zeros(1, n_b);  r2_col_o = zeros(1, n_b);
   for i = 1:n_b
      [r2_col_a(i), ~, ~] = gate_pooled(Eb_anc, xxb, i, jd_score);
      [r2_col_o(i), ~, ~] = gate_pooled(Ebo, xxb, i, jd_score);
   end
   fprintf("  Anchor-mix per column R2: median %7.4f  range %7.4f to %7.4f  over 1%%: %d of %d\n", ...
      median(r2_col_a), min(r2_col_a), max(r2_col_a), sum(r2_col_a > 0.01), n_b);
   fprintf("  official   per column R2: median %7.4f  range %7.4f to %7.4f  over 1%%: %d of %d\n", ...
      median(r2_col_o), min(r2_col_o), max(r2_col_o), sum(r2_col_o > 0.01), n_b);

   r2_mod = zeros(n_m, 1);  r2_mod_col = zeros(n_m, 1);
   for m = 1:n_m
      Em = double(A.E4(:, band, o_score, m));
      [r2_mod(m), ~, ~] = gate_pooled(Em, xxb, 1:n_b, jd_score);
      rc = zeros(1, n_b);
      for i = 1:n_b
         [rc(i), ~, ~] = gate_pooled(Em, xxb, i, jd_score);
      end
      r2_mod_col(m) = median(rc);
   end
   fprintf("\n  R2 of the demand anomaly against each model's band error\n");
   [~, ord] = sort(r2_mod, "descend");
   for i = 1:n_m
      m = ord(i);
      fprintf("   %2d %-26s pooled %7.4f  column median %7.4f\n", ...
         m, names(m), r2_mod(m), r2_mod_col(m));
   end
   fprintf("  %d of %d models sit below the 1 per cent gate\n", sum(r2_mod < 0.01), n_m);

   [r2_2p, b_2p] = gate_twopiece(Eb_anc, xxb, 1:n_b, jd_score);
   [r2_tr, b_tr] = gate_trimmed(Eb_anc, xxb, 1:n_b, jd_score, 0.99);
   fprintf("\n  two-piece, x above and below zero: R2 %7.4f  b(+) %+9.2f  b(-) %+9.2f\n", ...
      r2_2p, b_2p(1), b_2p(2));
   fprintf("  top 1 per cent of |x| dropped:      R2 %7.4f  b %+9.2f\n", r2_tr, b_tr);

   % ======================================================================
   % 2b) ceiling: the demand that actually happened at the target
   % ======================================================================
   % The forecast cube needs a run at the origin to reach the target, and one
   % publication in three does not reach 24 hours. The realised demand has no
   % lead dimension and no such restriction, so it measures how much a demand
   % anomaly could explain at all. It is not a predictor, it is an upper bound:
   % a ceiling under the gate closes the channel whatever a forecast could do.
   fprintf("\n=== 2b) ceiling, the demand that actually happened at the target ===\n");
   Yd = load_actual_demand(fullfile(root, "AEMO_Data"), t0, n_s);
   Na = nan(n_s, 2);
   for w = 1:2
      sel = (is_weekend == (w == 2)) & (days_all <= 28);
      Na(:, w) = mean(Yd(:, sel), 2, "omitnan");
   end
   xa = reshape(Yd ./ Na(:, daytype) - 1, n_s, 1, 60);
   xva = reshape(xa(:, 1, jd_score), [], 1);
   xva = xva(isfinite(xva));
   fprintf("  anomaly of the realised demand: median %+.4f  p1 %+.4f  p99 %+.4f  sd %.4f\n", ...
      median(xva), prctile(xva, 1), prctile(xva, 99), std(xva));
   [r2_ca, b_ca, t_ca] = gate_pooled(Eb_anc, xa, ones(1, n_b), jd_score);
   [r2_co, b_co, t_co] = gate_pooled(Ebo, xa, ones(1, n_b), jd_score);
   fprintf("  Anchor-mix R2 %8.4f  b %+9.2f  cluster t %+6.2f\n", r2_ca, b_ca, t_ca);
   fprintf("  official   R2 %8.4f  b %+9.2f  cluster t %+6.2f\n", r2_co, b_co, t_co);
   hb = [1 5 13 25 37];
   fprintf("  by lead, realised:");
   for i = hb
      [rc, ~, ~] = gate_pooled(Eb_anc(:, i, :), xa, 1, jd_score);
      fprintf("  %2.0fh %7.4f", lead_min(band(i)) / 60, rc);
   end
   fprintf("\n  by lead, forecast:");
   for i = hb
      [rc, ~, ~] = gate_pooled(Eb_anc(:, i, :), xxb(:, i, :), 1, jd_score);
      fprintf("  %2.0fh %7.4f", lead_min(band(i)) / 60, rc);
   end
   fprintf("\n");

   % ======================================================================
   % 4) the candidate, fitted on days 1 to 28
   % ======================================================================
   fprintf("\n=== 3) candidate: Anchor-mix plus a demand correction ===\n");
   xf = xxb(:, :, 1:28);
   hour = ceil((1:n_s)' / 12);                        % 24 groups of 30 minutes
   bkt = zeros(1, n_b);
   for i = 1:n_b
      L = lead_min(band(i));
      bkt(i) = 1 + (L >= 540) + (L >= 720) + (L >= 1080);   % 6-9, 9-12, 12-18, 18-24 h
   end
   grp1 = ones(n_s, n_b, 28);
   grp_h = repmat(hour, 1, n_b, 28);
   grp_hb = repmat(reshape(bkt, 1, n_b, 1), n_s, 1, 28);

   [bp1, bn1] = fit_piece(Eb_fit, xf, grp1);
   [bp2, bn2] = fit_piece(Eb_fit, xf, grp_h);
   [bp3, bn3] = fit_piece(Eb_fit, xf, grp_hb);
   fprintf("  V1 global       b(+) %+8.2f  b(-) %+8.2f\n", bp1, bn1);
   fprintf("  V2 by hour      b(+) median %+8.2f  range %+8.2f to %+8.2f\n", ...
      median(bp2), min(bp2), max(bp2));
   fprintf("                  b(-) median %+8.2f  range %+8.2f to %+8.2f\n", ...
      median(bn2), min(bn2), max(bn2));
   fprintf("  V3 hour x lead  b(+) median %+8.2f  b(-) median %+8.2f\n", ...
      median(bp3), median(bn3));

   % V4 uses the estimator the gate uses. A two-piece fit through the origin
   % cannot separate the mean error from the slope, and the anomaly has a large
   % negative median here, so V1 to V3 return slopes several times the pooled
   % one and the correction shifts every cell by a constant.
   [a1_4, mx4] = fit_slot(Eb_fit, xf);
   Eb1_fit = double(A.E4(:, c_1h, 1:28, k_a));
   xf1 = reshape(xx(:, j_1h, 1:28), n_s, 1, 28);
   [a1_1h, mx1_1h] = fit_slot(Eb1_fit, xf1);
   fprintf("  V4 per column   slope median %+8.2f  range %+8.2f to %+8.2f, negative %d of %d\n", ...
      median(a1_4), min(a1_4), max(a1_4), sum(a1_4 < 0), n_b);

   % ======================================================================
   % 5) out of sample, days 29 to 60
   % ======================================================================
   fprintf("\n=== 4) out of sample, days %d to %d ===\n", jd_score(1), jd_score(end));
   Es = Eb_anc;
   xs = xxb(:, :, jd_score);
   xs1 = reshape(xx(:, j_1h, jd_score), n_s, 1, n_day);
   grp1s = ones(n_s, n_b, n_day);
   grp_hs = repmat(hour, 1, n_b, n_day);
   grp_hbs = repmat(reshape(bkt, 1, n_b, 1), n_s, 1, n_day);

   corr4 = zeros(size(xs));
   for i = 1:n_b
      corr4(:, i, :) = a1_4(i) * (xs(:, i, :) - mx4(:, i));
   end
   % V5 uses the estimator and the application in the same space. The gate
   % removes the day common component from both sides, so the correction must
   % remove it too. V4 applied the slope to the raw anomaly, which also acts on
   % the day level, and the level differs by 11% between the fitting and the
   % scoring windows, so V4 shifts every cell by a constant.
   corr5 = zeros(size(xs));
   for i = 1:n_b
      xi = xs(:, i, :);
      corr5(:, i, :) = a1_4(i) * (xi - mean(xi, 1, "omitnan"));
   end
   % V6 fits on the scoring days themselves, so it is the ceiling of this
   % correction family and not a candidate: whatever it cannot reach, no version
   % of the same slope can. V7 keeps the frozen slope and swaps the demand
   % forecast for the demand that happened, which separates a wrong slope from a
   % noisy regressor.
   [a1_6] = fit_slot(Eb_anc, xs);
   corr6 = zeros(size(xs));
   for i = 1:n_b
      xi = xs(:, i, :);
      corr6(:, i, :) = a1_6(i) * (xi - mean(xi, 1, "omitnan"));
   end
   % xa covers all sixty days; the candidates live on the scored days only.
   Xa = repmat(xa(:, :, jd_score), 1, n_b, 1);
   corr7 = zeros(size(xs));
   for i = 1:n_b
      xi = Xa(:, i, :);
      corr7(:, i, :) = a1_4(i) * (xi - mean(xi, 1, "omitnan"));
   end
   [a1_1h6] = fit_slot(E1a, xs1);
   % The realised anomaly at the target does not depend on the lead, so the same
   % vector serves the 1 h column.
   xa1 = xa(:, :, jd_score);
   corr_set = {apply_piece(xs, grp1s, bp1, bn1), ...
               apply_piece(xs, grp_hs, bp2, bn2), ...
               apply_piece(xs, grp_hbs, bp3, bn3), corr4, corr5, corr6, corr7};
   corr_1h = {apply_piece(xs1, ones(n_s, 1, n_day), bp1, bn1), ...
              apply_piece(xs1, repmat(hour, 1, 1, n_day), bp2, bn2), ...
              apply_piece(xs1, ones(n_s, 1, n_day), bp3, bn3), ...
              a1_1h(1) * (xs1 - mx1_1h), ...
              a1_1h(1) * (xs1 - mean(xs1, 1, "omitnan")), ...
              a1_1h6(1) * (xs1 - mean(xs1, 1, "omitnan")), ...
              a1_1h(1) * (xa1 - mean(xa1, 1, "omitnan"))};
   lab = {"V1 global", "V2 by hour", "V3 hour x lead", "V4 within slot", ...
      "V5 within day", "V6 oracle", "V7 realised"};

   m1_off = median(sqrt(mean(E1o .^ 2, 3, "omitnan")));
   m24_off = median(sqrt(mean(Ebo(:, end, :) .^ 2, 3, "omitnan")));
   Rbo_off = sqrt(mean(Ebo .^ 2, 3, "omitnan"));
   Rbo_anc = sqrt(mean(Eb_anc .^ 2, 3, "omitnan"));
   V = struct("label", {}, "band_med", {}, "ratio", {}, "ratio_med", {}, ...
      "r_1h", {}, "ratio_1h", {}, "r_24h", {}, "ratio_24h", {}, ...
      "win_off", {}, "win_anc", {}, "dm_off_better", {}, "dm_off_worse", {}, ...
      "dm_anc_better", {}, "dm_anc_worse", {});
   Rn2 = [];
   for v = 1:7
      En = Es - corr_set{v};
      Rn = sqrt(mean(En .^ 2, 3, "omitnan"));
      colR = median(Rn, 1, "omitnan");
      rat = colR ./ colR_off;
      E1 = E1a - corr_1h{v};
      r1 = median(sqrt(mean(E1 .^ 2, 3, "omitnan")));
      r24 = median(Rn(:, end), "omitnan");
      wo = mean(Rn < Rbo_off, "all");
      wa = mean(Rn < Rbo_anc, "all");
      [g1, w1] = dm_cells(En, Ebo);
      [g2, w2] = dm_cells(En, Es);
      V(v) = struct("label", lab{v}, "band_med", median(colR), "ratio", median(rat), ...
         "ratio_med", median(colR) / median(colR_off), "r_1h", r1, ...
         "ratio_1h", r1 / m1_off, "r_24h", r24, "ratio_24h", r24 / m24_off, ...
         "win_off", wo, "win_anc", wa, "dm_off_better", g1, "dm_off_worse", w1, ...
         "dm_anc_better", g2, "dm_anc_worse", w2);
      fprintf("  %-16s band median R %7.3f  ratio %6.3f  med of column ratios %6.3f\n", ...
         lab{v}, V(v).band_med, V(v).ratio, V(v).ratio_med);
      fprintf("  %-16s 1 h %6.3f (ratio %6.3f)   24 h %6.3f (ratio %6.3f)\n", ...
         "", r1, V(v).ratio_1h, r24, V(v).ratio_24h);
      fprintf("  %-16s band cells ahead of official %5.1f%%   ahead of Anchor-mix %5.1f%%\n", ...
         "", 100 * wo, 100 * wa);
      fprintf("  %-16s DM vs official better %5d worse %5d | vs anchor better %5d worse %5d\n", ...
         "", g1, w1, g2, w2);
      if v == 2, Rn2 = Rn; end
   end
   fprintf("  reference: Anchor-mix band median R %7.3f  ratio %6.3f\n", ...
      median(colR_anc), median(rat_anc));

   % control: the same correction applied to official's own error. If official's
   % error also responds, the demand we can see is not the demand it used.
   [op, on] = fit_piece(Eb_off_fit, xf, grp1);
   Eo_new = Ebo - apply_piece(xs, grp1s, op, on);
   fprintf("\n  control, same global correction on official's error:\n");
   fprintf("     band median R %7.3f to %7.3f, b(+) %+8.2f, b(-) %+8.2f\n", ...
      median(colR_off), median(median(sqrt(mean(Eo_new .^ 2, 3, "omitnan")), 1, "omitnan")), op, on);

   % ======================================================================
   % 6) what the figure needs
   % ======================================================================
   R2map = r2_by_slot(Eb_anc, xxb, jd_score);
   xcol = reshape(xs, [], 1);
   ecol = reshape(Es, [], 1);
   eocol = reshape(Ebo, [], 1);
   nbin = 41;
   okx = isfinite(xcol) & isfinite(ecol);
   xe = linspace(prctile(xcol(okx), 0.5), prctile(xcol(okx), 99.5), nbin + 1);
   ye = linspace(prctile(ecol(okx), 0.5), prctile(ecol(okx), 99.5), nbin + 1);
   H_ours = histcounts2(xcol(okx), ecol(okx), xe, ye);
   oko = isfinite(xcol) & isfinite(eocol);
   H_off = histcounts2(xcol(oko), eocol(oko), xe, ye);
   % conditional mean of the error inside each x bin, which is the shape the
   % linear fit is approximating
   ctr = 0.5 * (xe(1:end-1) + xe(2:end));
   cmean = nan(1, numel(ctr));
   for i = 1:numel(ctr)
      sel = okx & xcol >= xe(i) & xcol < xe(i+1);
      if sum(sel) >= 50, cmean(i) = mean(ecol(sel)); end
   end

   out = struct();
   out.gate = struct("r2_anchor", r2_a, "b_anchor", b_a, "t_anchor", t_a, ...
      "r2_official", r2_o, "b_official", b_o, "t_official", t_o, ...
      "r2_2p", r2_2p, "b_2p", b_2p, "r2_trim", r2_tr, "b_trim", b_tr, ...
      "r2_ceiling", r2_ca, "b_ceiling", b_ca, "t_ceiling", t_ca, ...
      "r2_ceiling_official", r2_co, "b_ceiling_official", b_co, ...
      "r2_col_anchor", r2_col_a, "r2_col_official", r2_col_o, ...
      "r2_model", r2_mod, "r2_model_col", r2_mod_col, "model_names", cellstr(names));
   out.baseline = struct("official_band", median(colR_off), ...
      "anchor_band", median(colR_anc), "anchor_ratio", median(rat_anc), ...
      "official_1h", m1_off, "official_24h", m24_off);
   out.coef = struct("bp1", bp1, "bn1", bn1, "bp2", bp2, "bn2", bn2, ...
      "bp3", bp3, "bn3", bn3, "bkt", bkt, "b_official", op, "bn_official", on);
   out.variants = V;
   out.profile = struct("lead_min", lead_min(band), "colR_official", colR_off, ...
      "colR_anchor", colR_anc, "colR_new", median(Rn2, 1, "omitnan"));
   out.maps = struct("R2_by_slot", R2map, "dR_new_minus_official", Rn2 - colR_off);
   out.hist = struct("x_edges", xe, "e_edges", ye, "counts_ours", H_ours, ...
      "counts_official", H_off, "x_centre", ctr, "cond_mean_ours", cmean);
   out.demand = struct("n_run", numel(eff_r), "coverage", mean(isfinite(X), "all"), ...
      "x_median", median(xv), "x_p1", prctile(xv, 1), "x_p99", prctile(xv, 99), ...
      "x_sd", std(xv), "same_target_share", same(1) / same(2));
   fid = fopen(fullfile(out_dir, "e01_demand.json"), "w");
   fprintf(fid, "%s", jsonencode(out));
   fclose(fid);
   fprintf("\nwrote %s\n", fullfile(out_dir, "e01_demand.json"));
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
      assert(isfile(p), "e01:actual", "no realised demand file at %s", p);
      fid = fopen(p, "r");
      assert(fid > 0, "e01:actual_open", "cannot open %s", p);
      c = textscan(fid, "%s %s %f %f %s", "Delimiter", ",", "HeaderLines", 1, ...
         "ReturnOnError", false);
      fclose(fid);
      % SETTLEMENTDATE is written with slashes here, unlike every other AEMO
      % file in the project, so it is normalised before parsing.
      tm = [tm; double(nem_minutes(strrep(c{2}, "/", "-")))];
      dm = [dm; c{3}];
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
      assert(max(abs(tm(k(ok)) - t(ok))) == 0, "e01:actual_grid", ...
         "a target instant is not on the settlement grid");
      Yd(ok, d) = dm(k(ok));
   end
   fprintf("  realised demand matched at %d of %d target instants (%.1f%%)\n", ...
      sum(isfinite(Yd), "all"), numel(Yd), 100 * mean(isfinite(Yd), "all"));
end

% =========================================================================
function N = norm_profile(X, days, is_weekend)
   % Seasonal norm of the demand forecast: mean over the fitting days, by slot,
   % column and day type.
   fit = days <= 28;
   N = nan(size(X, 1), size(X, 2), 2);
   for w = 1:2
      sel = (is_weekend == (w == 2)) & fit;
      if ~any(sel), continue; end
      N(:, :, w) = mean(X(:, :, sel), 3, "omitnan");
   end
end

% =========================================================================
function s = lead_spread(D)
   % How much one target's demand forecast moves between leads. Large would mean
   % the demand forecast is a different object at every horizon, which would make
   % the anomaly dependent on the lead rather than on the day.
   lo = min(D, [], 2, "omitnan");
   hi = max(D, [], 2, "omitnan");
   s = median((hi - lo) ./ max(abs(lo), 1), "all", "omitnan");
end

% =========================================================================
function [r2, b, t] = gate_pooled(E, xxb, cols, days)
   % Within-slot correlation between the error and the demand anomaly, pooled
   % over the requested columns and days. Each cell is centred on its own slot
   % mean over those days, so the slot level is out of the regression.
   y = [];  v = [];  g = [];
   for i = 1:numel(cols)
      for k = 1:numel(days)
         e = E(:, cols(i), k);
         x = xxb(:, cols(i), days(k));
         ok = isfinite(e) & isfinite(x);
         cnt = sum(ok);
         if cnt < 3, continue; end
         ec = e;  ec(~ok) = 0;
         xc = x;  xc(~ok) = 0;
         ed = (ec - sum(ec) / cnt) .* ok;
         xd = (xc - sum(xc) / cnt) .* ok;
         y = [y; ed(ok)];  v = [v; xd(ok)];
         g = [g; repmat(k, cnt, 1)];
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
function [r2, b] = gate_twopiece(E, xxb, cols, days)
   y = [];  vp = [];  vn = [];
   for i = 1:numel(cols)
      for k = 1:numel(days)
         e = E(:, cols(i), k);
         x = xxb(:, cols(i), days(k));
         ok = isfinite(e) & isfinite(x);
         cnt = sum(ok);
         if cnt < 3, continue; end
         ec = e;  ec(~ok) = 0;
         xc = x;  xc(~ok) = 0;
         ed = (ec - sum(ec) / cnt) .* ok;
         xd = (xc - sum(xc) / cnt) .* ok;
         y = [y; ed(ok)];
         vp = [vp; max(xd(ok), 0)];  vn = [vn; min(xd(ok), 0)];
      end
   end
   Xm = [vp vn];
   b = (Xm' * Xm) \ (Xm' * y);
   r2 = 1 - sum((y - Xm * b) .^ 2) / sum((y - mean(y)) .^ 2);
end

% =========================================================================
function [r2, b] = gate_trimmed(E, xxb, cols, days, q)
   y = [];  v = [];
   for i = 1:numel(cols)
      for k = 1:numel(days)
         e = E(:, cols(i), k);
         x = xxb(:, cols(i), days(k));
         ok = isfinite(e) & isfinite(x);
         cnt = sum(ok);
         if cnt < 3, continue; end
         ec = e;  ec(~ok) = 0;
         xc = x;  xc(~ok) = 0;
         ed = (ec - sum(ec) / cnt) .* ok;
         xd = (xc - sum(xc) / cnt) .* ok;
         y = [y; ed(ok)];  v = [v; xd(ok)];
      end
   end
   keep = abs(v) <= prctile(abs(v), 100 * q);
   y = y(keep);  v = v(keep);
   b = (v' * y) / (v' * v);
   r2 = (v' * y) ^ 2 / ((v' * v) * (y' * y));
end

% =========================================================================
function [R2map, bmap] = r2_by_slot(E, xxb, days)
   % One R squared per slot, pooled over the band columns, each column centred on
   % its own mean across the scored days.
   n_s = size(E, 1);
   n_b = size(E, 2);
   n_d = numel(days);
   R2map = zeros(n_s, 1);
   bmap = zeros(n_s, 1);
   for s = 1:n_s
      e = reshape(E(s, :, :), n_b, n_d);
      x = reshape(xxb(s, :, days), n_b, n_d);
      ok = isfinite(e) & isfinite(x);
      if sum(ok(:)) < 50, continue; end
      ec = e;  ec(~ok) = 0;
      xc = x;  xc(~ok) = 0;
      cnt = sum(ok, 2);
      cnt(cnt == 0) = 1;
      ed = (ec - sum(ec, 2) ./ cnt) .* ok;
      xd = (xc - sum(xc, 2) ./ cnt) .* ok;
      yy = ed(ok);  vv = xd(ok);
      if sum(vv .^ 2) <= 0, continue; end
      R2map(s) = (vv' * yy) ^ 2 / ((vv' * vv) * (yy' * yy));
      bmap(s) = (vv' * yy) / (vv' * vv);
   end
end

% =========================================================================
function [bp, bn] = fit_piece(E, xx, grp)
   % Two-piece through the origin, one pair of slopes per group label.
   gl = unique(grp(:));
   bp = zeros(numel(gl), 1);  bn = zeros(numel(gl), 1);
   yv = E(:);  xv = xx(:);  gv = grp(:);
   for i = 1:numel(gl)
      ok = (gv == gl(i)) & isfinite(yv) & isfinite(xv);
      if sum(ok) < 20, continue; end
      y = yv(ok);  x = xv(ok);
      xp = max(x, 0);  xn = min(x, 0);
      if sum(xp .^ 2) <= 0 || sum(xn .^ 2) <= 0
         b = (x' * y) / max(x' * x, 1e-12);
         bp(i) = b;  bn(i) = b;
      else
         c = ([xp xn]' * [xp xn]) \ ([xp xn]' * y);
         bp(i) = c(1);  bn(i) = c(2);
      end
   end
end

function c = apply_piece(xx, grp, bp, bn)
   % The correction the fitted slopes imply, cell by cell.
   xp = max(xx, 0);  xn = min(xx, 0);
   c = zeros(size(xx));
   gl = unique(grp(:));
   for i = 1:numel(gl)
      ok = (grp == gl(i)) & isfinite(xx);
      c(ok) = bp(i) * xp(ok) + bn(i) * xn(ok);
   end
end

% =========================================================================
function [a1, mx] = fit_slot(E, X)
   % One slope per column on within-slot demeaned data, plus the slot mean of the
   % regressor taken from the fitting window, so the correction is applied out of
   % sample.
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
