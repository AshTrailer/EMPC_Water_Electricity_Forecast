function diagnose_d02_d03_d06(tag)
   % DIAGNOSE_D02_D03_D06  Three diagnostics on the scored surface, no model change.
   %
   %    D02  is our forecast over-dispersed. Per band column, regress the settled
   %         price on the forecast. A slope below one means the forecast varies
   %         more than the conditional mean does. Two shrink forms are scored: the
   %         registered one, toward the column mean, and the one a model would
   %         actually use, toward the per-slot profile.
   %
   %    D03  is the revision sequence predictable. The cube is indexed by target
   %         slot, target day and lead, so two adjacent columns are two vintages of
   %         one target and their difference is an actual revision. If a revision
   %         correlates with the one before it, the next can be anticipated and
   %         applied now.
   %
   %    D06  does the daily mean persist. Lag one to seven autocorrelation of the
   %         daily mean, and the R squared of tomorrow on today.
   %
   % The stored error is a clamped actual minus a clamped forecast, so neither side
   % is recoverable from it alone. The clamp is therefore rebuilt from the price
   % series and validated against the official cube, whose forecast is stored
   % unclamped, before anything is measured.
   %
   % Run: runs\run_diagnose_d02_d03_d06.bat

   if nargin < 1 || strlength(string(tag)) == 0
      tag = "d02_d03_d06";
   end
   tag = string(tag);

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   data_dir = fullfile(root, "AEMO_Data");
   out_dir = fullfile(root, "Weekly", "2026-10-13", "research", "verify");
   addpath(genpath(fullfile(root, "Predicitor")));

   n_s = 288;
   [lead_min, lead_step, ~] = official_lead_axis();
   lead_min = lead_min(:)';
   lead_step = lead_step(:)';
   band = find(lead_min >= 360 & lead_min <= 1440);
   n_b = numel(band);
   lead_b = lead_min(band);
   step_b = lead_step(band);
   assert(n_b == 37, "d02:band", "band is %d columns, expected 37", n_b);

   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   names = string(A.names);
   m_anc = find(names == "Anchor-mix", 1);
   assert(~isempty(m_anc), "d02:anchor", "Anchor-mix is not in the atlas");
   dsc = double(A.d_score);
   dsc = dsc(:)';
   n_day = numel(dsc);
   t_test = A.t_test;
   t_test = t_test(:);
   n_win = 60;
   fprintf("scored days %d, window days %d to %d, band %d columns, %.1f to %.1f h\n", ...
      n_day, dsc(1), dsc(end), n_b, lead_b(1) / 60, lead_b(end) / 60);

   % =====================================================================
   % Rebuild the causal [Q1, Q99] clamp exactly as the two builders do
   % =====================================================================
   n_q = 30;
   [tp, yp] = read_vic1(data_dir, ["202607", "202608", "202609", "202610"]);
   y_win0 = yp(tp >= datetime(2026, 7, 12, 0, 5, 0) & tp <= datetime(2026, 8, 11, 0, 0, 0));
   assert(numel(y_win0) == n_q * n_s, "d02:warm", ...
      "warm-up window is %d samples, expected %d", numel(y_win0), n_q * n_s);
   mt = tp >= t_test(1) & tp <= t_test(end);
   y_test = yp(mt);
   assert(numel(y_test) == numel(t_test), "d02:len", ...
      "test window is %d samples, the cube has %d", numel(y_test), numel(t_test));
   assert(all(minutes(tp(mt) - t_test) == 0), "d02:time", "test window timestamps differ");
   assert(numel(y_test) == n_win * n_s, "d02:win", "test window is not 60 whole days");

   cs = init_price_clamp(reshape(y_win0, n_s, n_q)');
   q_by_day = zeros(n_win, 2);
   q_by_day(1, :) = cs.q;
   for d = 1:n_win - 1
      cs = update_price_clamp(cs, y_test((d - 1) * n_s + (1:n_s))');
      q_by_day(d + 1, :) = cs.q;
   end
   q1_seq = repelem(q_by_day(:, 1), n_s);
   q2_seq = repelem(q_by_day(:, 2), n_s);
   yc_seq = clamp_price(y_test, [q1_seq, q2_seq]);
   fprintf("clamp rebuilt: Q1 %.2f to %.2f, Q99 %.2f to %.2f\n", ...
      min(q_by_day(:, 1)), max(q_by_day(:, 1)), min(q_by_day(:, 2)), max(q_by_day(:, 2)));

   % =====================================================================
   % Slabs, [target day, target slot, band column]. The cube is indexed by the
   % target, so the settled price and the clamp are the same for every column.
   % =====================================================================
   Yg = zeros(n_day, n_s);
   Q1g = zeros(n_day, n_s);
   Q2g = zeros(n_day, n_s);
   for dd = 1:n_day
      k = (dsc(dd) - 1) * n_s + (1:n_s);
      Yg(dd, :) = yc_seq(k)';
      Q1g(dd, :) = q1_seq(k)';
      Q2g(dd, :) = q2_seq(k)';
   end
   Yc = repmat(Yg, 1, 1, n_b);
   Ea = nan(n_day, n_s, n_b);
   Eo = nan(n_day, n_s, n_b);
   Ocl = nan(n_day, n_s, n_b);
   for dd = 1:n_day
      Ea(dd, :, :) = reshape(double(A.E4(1:n_s, band, dsc(dd), m_anc)), n_s, 1, n_b);
      Eo(dd, :, :) = reshape(double(O.E4_off(1:n_s, band, dsc(dd))), n_s, 1, n_b);
      Ocl(dd, :, :) = reshape(double(O.O4(1:n_s, band, dsc(dd))), n_s, 1, n_b);
   end
   Pa = Yc - Ea;
   PoC = Yc - Eo;
   fprintf("cells: %d band cells, ours finite %.2f%%, official finite %.2f%%\n", ...
      numel(Yc), 100 * mean(isfinite(Ea), "all"), 100 * mean(isfinite(Eo), "all"));

   % The official forecast is stored unclamped, so this is a hard address check.
   Ochk = min(max(Ocl, repmat(Q1g, 1, 1, n_b)), repmat(Q2g, 1, 1, n_b));
   dc_ = abs(PoC - Ochk);
   dc_ = dc_(isfinite(dc_));
   fprintf("clamp check against the official cube: %d cells, max |diff| %.3g\n", ...
      numel(dc_), max(dc_));
   assert(max(dc_) < 1e-3, "d02:clamp", "the rebuilt clamp does not reproduce E4_off");
   clear Ocl Ochk

   % =====================================================================
   % Baseline band ratio on this reconstruction
   % =====================================================================
   r_base = band_ratio(Ea, Eo, n_b);
   RA = reshape(sqrt(mean(Ea .^ 2, 1, "omitnan")), n_s, n_b);
   RB = reshape(sqrt(mean(Eo .^ 2, 1, "omitnan")), n_s, n_b);
   med_own = median(RA, 1, "omitnan");
   med_off = median(RB, 1, "omitnan");
   fprintf("\nbaseline on this reconstruction\n");
   fprintf("  band column-median R: ours %.3f  official %.3f\n", median(med_own), median(med_off));
   fprintf("  median of the per-column ratio %.4f (primary criterion, target 1.3327)\n", r_base);
   fprintf("  ratio of the two medians %.4f\n", median(med_own) / median(med_off));

   % =====================================================================
   % D02  over-dispersion
   % =====================================================================
   fprintf("\n=== D02: is the forecast over-dispersed ===\n");
   gday = repmat((1:n_day)', n_s, 1);
   gslot = repelem((1:n_s)', n_day);
   yv = Yc(:, :, 1);
   yv = yv(:);
   s_yn = accumarray(gslot, yv, [], @mean_ok, NaN);
   y_within = yv - s_yn(gslot);
   lbl = ["ours", "official"];
   src = {Pa, PoC};
   d02 = struct();
   fld = ["b_glob", "se_glob", "lo_glob", "hi_glob", "r2_glob", "b_within", ...
      "se_within", "lo_within", "hi_within"];
   for f = fld
      d02.(f) = nan(2, n_b);
   end
   d02.n = zeros(2, n_b);
   for k = 1:2
      for jj = 1:n_b
         x = reshape(src{k}(:, :, jj), [], 1);
         [bg, ~, sc, rg, ng] = slope_fit(yv, x, gday);
         d02.b_glob(k, jj) = bg;
         d02.se_glob(k, jj) = sc;
         d02.lo_glob(k, jj) = bg - 1.96 * sc;
         d02.hi_glob(k, jj) = bg + 1.96 * sc;
         d02.r2_glob(k, jj) = rg;
         d02.n(k, jj) = ng;
         s_xn = accumarray(gslot, x, [], @mean_ok, NaN);
         x_within = x - s_xn(gslot);
         [bw, ~, sw, ~, ~] = slope_fit(y_within, x_within, gday);
         d02.b_within(k, jj) = bw;
         d02.se_within(k, jj) = sw;
         d02.lo_within(k, jj) = bw - 1.96 * sw;
         d02.hi_within(k, jj) = bw + 1.96 * sw;
      end
   end
   for k = 1:2
      fprintf("  %-8s b global  median %.3f  range %.3f to %.3f  95%% upper below 1: %d of %d\n", ...
         lbl(k), median(d02.b_glob(k, :), "omitnan"), min(d02.b_glob(k, :)), ...
         max(d02.b_glob(k, :)), sum(d02.hi_glob(k, :) < 1), n_b);
      fprintf("  %-8s b within  median %.3f  range %.3f to %.3f  95%% upper below 1: %d of %d\n", ...
         lbl(k), median(d02.b_within(k, :), "omitnan"), min(d02.b_within(k, :)), ...
         max(d02.b_within(k, :)), sum(d02.hi_within(k, :) < 1), n_b);
   end
   fprintf("  criterion: more than 18 of 37 columns with b significantly below one\n");

   % Two shrink forms, two folds by target day, so no day is fitted and scored.
   half = floor(n_day / 2);
   Pa_col = nan(n_day, n_s, n_b);
   Pa_pro = nan(n_day, n_s, n_b);
   Pa_amp = nan(n_day, n_s, n_b);
   beta_prof = nan(2, n_b);
   for fold = 1:2
      if fold == 1
         fitd = 1:half;  evd = half + 1:n_day;
      else
         fitd = half + 1:n_day;  evd = 1:half;
      end
      nf = numel(fitd);
      ne = numel(evd);
      slot_f = repelem((1:n_s)', nf);
      slot_e = repelem((1:n_s)', ne);
      for jj = 1:n_b
         xf = reshape(Pa(fitd, :, jj), [], 1);
         yf = reshape(Yc(fitd, :, jj), [], 1);
         ok = isfinite(xf) & isfinite(yf);
         if nnz(ok) < 200, continue; end
         X = [ones(nnz(ok), 1), xf(ok)];
         bv = X \ yf(ok);
         mu = mean(xf(ok));
         xe = reshape(Pa(evd, :, jj), [], 1);
         Pa_col(evd, :, jj) = reshape(mu + bv(2) * (xe - mu), ne, n_s);
         % profile form: target climatology as the level, shrink the rest
         ms = accumarray(slot_f, xf, [], @mean_ok, NaN);
         my = accumarray(slot_f, yf, [], @mean_ok, NaN);
         xfs = xf - ms(slot_f);
         yfs = yf - my(slot_f);
         oks = isfinite(xfs) & isfinite(yfs);
         if nnz(oks) < 200, continue; end
         bw = (xfs(oks)' * yfs(oks)) / (xfs(oks)' * xfs(oks));
         xes = xe - ms(slot_e);
         Pa_pro(evd, :, jj) = reshape(my, 1, n_s) + reshape(bw * xes, ne, n_s);
         % amplitude form: our own climatology as the level, so only the
         % day-to-day swing is compressed and the level is left alone
         Pa_amp(evd, :, jj) = reshape(ms, 1, n_s) + reshape(bw * xes, ne, n_s);
         beta_prof(fold, jj) = bw;
      end
   end
   r_col = band_ratio(Yc - Pa_col, Eo, n_b);
   r_pro = band_ratio(Yc - Pa_pro, Eo, n_b);
   r_amp = band_ratio(Yc - Pa_amp, Eo, n_b);
   [nb_c, nw_c] = dm_cells(Yc - Pa_col, Eo);
   [nb_p, nw_p] = dm_cells(Yc - Pa_pro, Eo);
   [nb_m, nw_m] = dm_cells(Yc - Pa_amp, Eo);
   fprintf("  shrink to the column mean:   band ratio %.4f  DM %d better / %d worse\n", ...
      r_col, nb_c, nw_c);
   fprintf("  shrink to the target profile: band ratio %.4f  DM %d better / %d worse\n", ...
      r_pro, nb_p, nw_p);
   fprintf("  shrink our own amplitude:    band ratio %.4f  DM %d better / %d worse\n", ...
      r_amp, nb_m, nw_m);
   fprintf("  beta, profile form: median %.3f, range %.3f to %.3f\n", ...
      median(beta_prof(:), "omitnan"), min(beta_prof(:)), max(beta_prof(:)));
   % The band's two endpoints, the win-cell share, and a perfect per-day level
   % oracle. The oracle is in sample and cannot be built: it is the upper bound on
   % what knowing the day's level would be worth.
   Ea_now = Yc - Pa;
   Ea_or = Ea_now;
   Eo_or = Eo;
   for dd = 1:n_day
      v = reshape(Ea_or(dd, :, :), [], 1);
      Ea_or(dd, :, :) = Ea_or(dd, :, :) - mean(v(isfinite(v)));
      v = reshape(Eo_or(dd, :, :), [], 1);
      Eo_or(dd, :, :) = Eo_or(dd, :, :) - mean(v(isfinite(v)));
   end
   st_base = cand_stats(Ea_now, Eo, n_b);
   st_col = cand_stats(Yc - Pa_col, Eo, n_b);
   st_pro = cand_stats(Yc - Pa_pro, Eo, n_b);
   st_amp = cand_stats(Yc - Pa_amp, Eo, n_b);
   st_orc = cand_stats(Ea_or, Eo, n_b);
   st_oro = cand_stats(Eo_or, Eo, n_b);
   fprintf("  %-22s %7s %7s %7s %7s\n", "candidate", "6 h", "24 h", "band", "win%");
   fprintf("  %-22s %7.4f %7.4f %7.4f %7.2f\n", "as measured", st_base.c6h, st_base.c24h, ...
      st_base.band, st_base.win);
   fprintf("  %-22s %7.4f %7.4f %7.4f %7.2f\n", "shrink to column mean", st_col.c6h, ...
      st_col.c24h, st_col.band, st_col.win);
   fprintf("  %-22s %7.4f %7.4f %7.4f %7.2f\n", "shrink to target profile", st_pro.c6h, ...
      st_pro.c24h, st_pro.band, st_pro.win);
   fprintf("  %-22s %7.4f %7.4f %7.4f %7.2f\n", "shrink our own amplitude", st_amp.c6h, ...
      st_amp.c24h, st_amp.band, st_amp.win);
   fprintf("  %-22s %7.4f %7.4f %7.4f %7.2f\n", "ours, day level oracle", st_orc.c6h, ...
      st_orc.c24h, st_orc.band, st_orc.win);
   fprintf("  %-22s %7.4f %7.4f %7.4f %7.2f\n", "official, day level oracle", st_oro.c6h, ...
      st_oro.c24h, st_oro.band, st_oro.win);
   fprintf("  the 1 h column is outside the band and no candidate here touches it, so it\n");
   fprintf("  stays at 0.85; the window comes from the 288-slot surface, not from this slab\n");
   d02.st_base = st_base;
   d02.st_col = st_col;
   d02.st_pro = st_pro;
   d02.st_amp = st_amp;
   d02.st_oracle_own = st_orc;
   d02.st_oracle_off = st_oro;
   d02.ratio_col = r_col;
   d02.ratio_prof = r_pro;
   d02.ratio_amp = r_amp;
   d02.dm_col = [nb_c, nw_c];
   d02.dm_prof = [nb_p, nw_p];
   d02.dm_amp = [nb_m, nw_m];
   d02.beta_prof = beta_prof;

   % =====================================================================
   % D03  revision structure
   % =====================================================================
   fprintf("\n=== D03: is the revision sequence predictable ===\n");
   d03 = struct();
   d03.c11 = nan(2, n_b - 1);
   d03.c12 = nan(2, n_b - 1);
   d03.eff = nan(2, n_b - 1);
   d03.rv = nan(2, n_b - 1);
   for k = 1:2
      P = src{k};
      for jj = 1:n_b - 1
         r1 = reshape(P(:, :, jj) - P(:, :, jj + 1), [], 1);
         e0 = reshape(Yc(:, :, jj) - P(:, :, jj), [], 1);
         e1 = reshape(Yc(:, :, jj + 1) - P(:, :, jj + 1), [], 1);
         d03.c12(k, jj) = corr_ok(r1, e1);
         ok = isfinite(e0) & isfinite(e1) & isfinite(r1);
         d03.eff(k, jj) = (mean(e1(ok) .^ 2) - mean(e0(ok) .^ 2)) / mean(r1(ok) .^ 2);
         d03.rv(k, jj) = mean(r1(ok) .^ 2);
         if jj < n_b - 1
            r2 = reshape(P(:, :, jj + 1) - P(:, :, jj + 2), [], 1);
            d03.c11(k, jj) = corr_ok(r1, r2);
         end
      end
   end
   for k = 1:2
      fprintf("  %-8s |corr(r(j), r(j+1))| median %.3f   |corr(r(j), e(j+1))| median %.3f\n", ...
         lbl(k), median(abs(d03.c11(k, :)), "omitnan"), median(abs(d03.c12(k, :)), "omitnan"));
      fprintf("  %-8s efficiency median %+.3f, range %+.3f to %+.3f, revision sd %.2f\n", ...
         lbl(k), median(d03.eff(k, :), "omitnan"), min(d03.eff(k, :)), max(d03.eff(k, :)), ...
         sqrt(median(d03.rv(k, :), "omitnan")));
   end
   fprintf("  criterion: median absolute correlation above 0.1\n");

   % Anticipate the next revision and apply it now. Two folds by target day.
   P = Pa;
   beta_ant = nan(n_b - 1, 2);
   for jj = 1:n_b - 1
      r1 = reshape(P(:, :, jj) - P(:, :, jj + 1), [], 1);
      e0 = reshape(Yc(:, :, jj) - P(:, :, jj), [], 1);
      for fold = 1:2
         if fold == 1
            sel = isfinite(e0) & isfinite(r1) & (gday <= half);
         else
            sel = isfinite(e0) & isfinite(r1) & (gday > half);
         end
         if nnz(sel) < 200, continue; end
         beta_ant(jj, fold) = (r1(sel)' * e0(sel)) / (r1(sel)' * r1(sel));
      end
   end
   Pa_ant = Pa;
   for jj = 1:n_b - 1
      r1 = P(:, :, jj) - P(:, :, jj + 1);
      bt = repmat(repmat(beta_ant(jj, 1), half, 1), 1, n_s);
      bt = [bt; repmat(repmat(beta_ant(jj, 2), n_day - half, 1), 1, n_s)];
      cur = Pa(:, :, jj);
      imp = cur + bt .* r1;
      sel = isfinite(imp) & isfinite(cur);
      cur(sel) = imp(sel);
      Pa_ant(:, :, jj) = cur;
   end
   r_ant = band_ratio(Yc - Pa_ant, Eo, n_b);
   [nb_a, nw_a] = dm_cells(Yc - Pa_ant, Eo);
   st_ant = cand_stats(Yc - Pa_ant, Eo, n_b);
   fprintf("  anticipated revision: band ratio %.4f  DM %d better / %d worse, beta median %+.3f\n", ...
      r_ant, nb_a, nw_a, median(beta_ant(:), "omitnan"));
   fprintf("  %-22s %7s %7s %7s %7s\n", "candidate", "6 h", "24 h", "band", "win%");
   fprintf("  %-22s %7.4f %7.4f %7.4f %7.2f\n", "as measured", st_base.c6h, st_base.c24h, ...
      st_base.band, st_base.win);
   fprintf("  %-22s %7.4f %7.4f %7.4f %7.2f\n", "revision anticipated", st_ant.c6h, ...
      st_ant.c24h, st_ant.band, st_ant.win);
   d03.st_ant = st_ant;
   d03.st_base = st_base;
   d03.ratio_ant = r_ant;
   d03.dm_ant = [nb_a, nw_a];
   d03.beta_ant = beta_ant;

   % =====================================================================
   % D06  persistence of the daily mean
   % =====================================================================
   fprintf("\n=== D06: does the daily mean persist ===\n");
   months = strings(0, 1);
   dd_ = dir(fullfile(data_dir, "PRICE_AND_DEMAND_*_VIC1.csv"));
   for i = 1:numel(dd_)
      tok = regexp(dd_(i).name, "PRICE_AND_DEMAND_(\d{6})_VIC1\.csv", "tokens", "once");
      if ~isempty(tok)
         months(end + 1, 1) = string(tok{1});
      end
   end
   months = sort(unique(months));
   fprintf("  price files on disk: %d months, %s to %s\n", numel(months), months(1), months(end));
   [td, yd] = read_vic1(data_dir, months);
   dkey = dateshift(td - minutes(5), "start", "day");
   [uk, ~, gk] = unique(dkey);
   n_per = accumarray(gk, 1);
   dmean = accumarray(gk, yd, [], @mean);
   dmed = accumarray(gk, yd, [], @median);
   keep_day = n_per == n_s;
   dmean = dmean(keep_day);
   dmed = dmed(keep_day);
   uk = uk(keep_day);
   fprintf("  settled series %s to %s, %d days, %d with all %d samples\n", ...
      string(uk(1)), string(uk(end)), numel(keep_day), nnz(keep_day), n_s);
   d06 = struct();
   d06.day = string(uk);
   d06.mean = dmean;
   d06.med = dmed;
   d06.acf = acf_ok(dmean, 14);
   [d06.r2_lag1, d06.b_lag1] = r2_lag(dmean, 1);
   d06.acf_med = acf_ok(dmed, 14);
   [d06.r2_lag1_med, d06.b_lag1_med] = r2_lag(dmed, 1);
   ew = uk >= datetime(2026, 8, 11) & uk <= datetime(2026, 10, 9);
   d06.acf_eval = acf_ok(dmean(ew), 14);
   [d06.r2_lag1_eval, d06.b_lag1_eval] = r2_lag(dmean(ew), 1);
   [d06.r2_win7, d06.b_win7] = r2_win(dmean, 7);
   fprintf("  daily mean %.2f, sd %.2f, median %.3f\n", mean(dmean), std(dmean), median(dmed));
   fprintf("  autocorrelation lags 1 to 7: %s\n", mat2str(round(d06.acf(2:8)', 3)));
   fprintf("  R squared, tomorrow on today: %.3f, slope %.3f, evaluation window %.3f\n", ...
      d06.r2_lag1, d06.b_lag1, d06.r2_lag1_eval);
   fprintf("  R squared, tomorrow on the trailing 7-day mean: %.3f\n", d06.r2_win7);
   fprintf("  same on the daily median: R squared %.3f, slope %.3f, lag one %.3f\n", ...
      d06.r2_lag1_med, d06.b_lag1_med, d06.acf_med(2));
   fprintf("  criterion: above 0.3 the level channel has room, below 0.1 only exogenous helps\n");

   % Bridge to the level candidate: how much of the band error is a day offset.
   [d06.day_share_own, d06.sd_day_own] = one_share(Yc - Pa);
   [d06.day_share_off, d06.sd_day_off] = one_share(Eo);
   fprintf("  band error carried by a per-target-day signed offset: ours %.3f, official %.3f\n", ...
      d06.day_share_own, d06.day_share_off);
   fprintf("  sd of the day offset: ours %.3f, official %.3f $/MWh\n", ...
      d06.sd_day_own, d06.sd_day_off);

   % =====================================================================
   % Write
   % =====================================================================
   out = struct();
   out.band_lead_min = lead_b;
   out.band_med_own = med_own;
   out.band_med_off = med_off;
   out.baseline_ratio = r_base;
   out.ratio_of_medians = median(med_own) / median(med_off);
   out.clamp_max_diff = max(dc_);
   out.d02 = d02;
   out.d03 = d03;
   out.d06 = d06;
   txt = jsonencode(out);
   f = fullfile(out_dir, tag + ".json");
   fid = fopen(f, "w");
   fwrite(fid, txt, "char");
   fclose(fid);
   fprintf("\nwrote %s (%d bytes)\n", f, numel(txt));

   plot_d02(out_dir, lead_b, d02, Yc, Pa, r_base);
   plot_d03(out_dir, lead_b, d03, Pa, PoC, Yc, n_b);
   plot_d06(out_dir, d06, Yc - Pa, Eo, uk, dmean, dmed);
   fprintf("wrote three figures\n");
end

% =========================================================================
function [tp, yp] = read_vic1(data_dir, months)
   T = strings(0, 1);
   V = zeros(0, 1);
   % Indexed, not `for m = months`: a for loop walks the columns of an array, so a
   % column of month strings would be one iteration holding all of them.
   for i = 1:numel(months)
      p = fullfile(data_dir, "PRICE_AND_DEMAND_" + months(i) + "_VIC1.csv");
      assert(isfile(p), "d02:file", "cannot find %s", p);
      fid = fopen(p, "r");
      assert(fid > 0, "d02:file", "cannot open %s", p);
      c = textscan(fid, "%s %s %f %f %s", "Delimiter", ",", "HeaderLines", 1);
      fclose(fid);
      keep = string(c{1}) == "VIC1";
      T = [T; string(c{2}(keep))];
      V = [V; c{4}(keep)];
   end
   t = datetime(strrep(T, "/", "-"), "InputFormat", "yyyy-MM-dd HH:mm:ss");
   y = V;
   [t, o] = sort(t);
   y = y(o);
   u = [true; diff(t) > minutes(0)];
   tp = t(u);
   yp = y(u);
end

% =========================================================================
function m = mean_ok(v)
   v = v(isfinite(v));
   if isempty(v), m = NaN; else, m = mean(v); end
end

% =========================================================================
function r = corr_ok(a, b)
   ok = isfinite(a) & isfinite(b);
   if nnz(ok) < 30, r = NaN; return; end
   a = a(ok) - mean(a(ok));
   b = b(ok) - mean(b(ok));
   sa = sqrt(sum(a .^ 2));
   sb = sqrt(sum(b .^ 2));
   if sa <= 0 || sb <= 0, r = NaN; else, r = (a' * b) / (sa * sb); end
end

% =========================================================================
function [b, se_n, se_c, r2, n] = slope_fit(y, x, g)
   ok = isfinite(y) & isfinite(x) & isfinite(g);
   y = y(ok);
   x = x(ok);
   g = g(ok);
   n = numel(y);
   b = NaN;  se_n = NaN;  se_c = NaN;  r2 = NaN;
   if n < 200, return; end
   X = [ones(n, 1), x];
   if rank(X) < 2, return; end
   bv = X \ y;
   u = y - X * bv;
   b = bv(2);
   XtXi = inv(X' * X);
   se_n = sqrt((u' * u) / (n - 2) * XtXi(2, 2));
   gs = unique(g);
   G = numel(gs);
   meat = zeros(2, 2);
   for k = 1:G
      mm = g == gs(k);
      s = X(mm, :)' * u(mm);
      meat = meat + s * s';
   end
   V = XtXi * meat * XtXi * (G / (G - 1)) * ((n - 1) / (n - 2));
   se_c = sqrt(V(2, 2));
   ss = sum((y - mean(y)) .^ 2);
   if ss > 0, r2 = 1 - (u' * u) / ss; end
end

% =========================================================================
function st = cand_stats(EA, EB, n_b)
   % Band ratio, the two endpoint columns, and the share of band cells won.
   RA = reshape(sqrt(mean(EA .^ 2, 1, "omitnan")), [], n_b);
   RB = reshape(sqrt(mean(EB .^ 2, 1, "omitnan")), [], n_b);
   mA = median(RA, 1, "omitnan");
   mB = median(RB, 1, "omitnan");
   p = mA ./ mB;
   st.band = median(p, "omitnan");
   st.c6h = p(1);
   st.c24h = p(end);
   ok = isfinite(EA) & isfinite(EB);
   st.win = 100 * mean(abs(EA(ok)) < abs(EB(ok)));
   st.n = nnz(ok);
end

% =========================================================================
function ratio = band_ratio(EA, EB, n_b)
   % Median over the band columns of the per-column ratio of column medians.
   RA = reshape(sqrt(mean(EA .^ 2, 1, "omitnan")), [], n_b);
   RB = reshape(sqrt(mean(EB .^ 2, 1, "omitnan")), [], n_b);
   mA = median(RA, 1, "omitnan");
   mB = median(RB, 1, "omitnan");
   ratio = median(mA ./ mB, "omitnan");
end

% =========================================================================
function a = acf_ok(x, L)
   x = x(isfinite(x));
   x = x - mean(x);
   v = mean(x .^ 2);
   a = nan(L + 1, 1);
   for l = 0:L
      if numel(x) > l + 2
         a(l + 1) = mean(x(1 + l:end) .* x(1:end - l)) / v;
      end
   end
end

% =========================================================================
function [r2, b] = r2_lag(x, lag)
   x = x(:);
   a = x(1:end - lag);
   c = x(1 + lag:end);
   ok = isfinite(a) & isfinite(c);
   a = a(ok);
   c = c(ok);
   X = [ones(numel(a), 1), a];
   bv = X \ c;
   b = bv(2);
   u = c - X * bv;
   r2 = 1 - (u' * u) / sum((c - mean(c)) .^ 2);
end

% =========================================================================
function [r2, b] = r2_win(x, w)
   x = x(:);
   n = numel(x);
   a = nan(n, 1);
   for i = 1:n
      lo = max(1, i - w + 1);
      a(i) = mean(x(lo:i), "omitnan");
   end
   xx = a(1:end - 1);
   cc = x(2:end);
   ok = isfinite(xx) & isfinite(cc);
   X = [ones(nnz(ok), 1), xx(ok)];
   bv = X \ cc(ok);
   b = bv(2);
   u = cc(ok) - X * bv;
   r2 = 1 - (u' * u) / sum((cc(ok) - mean(cc(ok))) .^ 2);
end

% =========================================================================
function [s, sd] = one_share(E)
   % Share of the band error that a per-target-day signed offset can remove.
   e = E;
   ok = isfinite(e);
   tot = mean((e(ok) - mean(e(ok))) .^ 2);
   m = nan(size(e, 1), 1);
   for dd = 1:size(e, 1)
      v = reshape(e(dd, :, :), [], 1);
      m(dd) = mean(v(isfinite(v)));
   end
   s = var(m) / tot;
   sd = sqrt(var(m));
end

% =========================================================================
function [n_better, n_worse] = dm_cells(EA, EB)
   D = EA .^ 2 - EB .^ 2;
   [n_s, n_b, n_d] = size(D);
   D = reshape(D, n_s * n_b, n_d);
   ok = all(isfinite(D), 2);
   D = D(ok, :);
   mu = mean(D, 2);
   L = min(10, n_d - 1);
   vh = mean(D .^ 2, 2) - mu .^ 2;
   for l = 1:L
      gl = mean(D(:, 1 + l:end) .* D(:, 1:end - l), 2) - mu .^ 2;
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

% =========================================================================
function plot_d02(out_dir, lead_b, d02, Yc, Pa, r_base)
   f = figure("Visible", "off", "Position", [60 60 1500 950]);
   col = [0.12 0.31 0.47; 0.75 0.10 0.10];

   subplot(2, 2, 1);
   hold on;
   for k = 1:2
      lo = d02.lo_glob(k, :);
      hi = d02.hi_glob(k, :);
      ok = isfinite(lo) & isfinite(hi);
      fill([lead_b(ok), fliplr(lead_b(ok))] / 60, [lo(ok), fliplr(hi(ok))], col(k, :), ...
         "FaceAlpha", 0.13, "EdgeColor", "none");
      plot(lead_b / 60, d02.b_glob(k, :), "-", "Color", col(k, :), "LineWidth", 1.8);
   end
   plot([6 24], [1 1], "k--", "LineWidth", 0.9);
   hold off;  grid on;
   xlabel("lead, hours");  ylabel("slope of the settled price on the forecast");
   title("a. a slope below one is an over-dispersed forecast", "FontSize", 11);
   legend({"ours", "", "official", ""}, "Location", "southeast", "Box", "off", "FontSize", 8);

   subplot(2, 2, 2);
   hold on;
   for k = 1:2
      plot(lead_b / 60, d02.b_within(k, :), "-o", "Color", col(k, :), ...
         "LineWidth", 1.6, "MarkerSize", 3);
   end
   plot([6 24], [1 1], "k--", "LineWidth", 0.9);
   hold off;  grid on;
   xlabel("lead, hours");  ylabel("slope within the slot, day to day");
   title("b. the same slope after removing the diurnal profile", "FontSize", 11);
   legend({"ours", "official"}, "Location", "southeast", "Box", "off", "FontSize", 8);

   subplot(2, 2, 3);
   jj = 19;
   x = reshape(Pa(:, :, jj), [], 1);
   y = reshape(Yc(:, :, jj), [], 1);
   ok = isfinite(x) & isfinite(y);
   hold on;
   plot([-50 250], [-50 250], "k-", "LineWidth", 0.9);
   scatter(x(ok), y(ok), 2.2, col(1, :), "filled", "MarkerFaceAlpha", 0.08);
   xx = linspace(-50, 250, 50);
   plot(xx, mean(y(ok)) + d02.b_glob(1, jj) * (xx - mean(x(ok))), "-", ...
      "Color", [0.95 0.55 0.10], "LineWidth", 2.0);
   hold off;  grid on;  axis equal;
   xlim([-50 250]);  ylim([-50 250]);
   xlabel("our forecast, $/MWh");  ylabel("settled price, $/MWh");
   title(sprintf("c. %.1f h column, slope %.3f", lead_b(jj) / 60, d02.b_glob(1, jj)), "FontSize", 11);

   subplot(2, 2, 4);
   bars = [r_base, d02.ratio_col, d02.ratio_prof, d02.ratio_amp, d02.st_oracle_own.band];
   bar(bars, 0.55, "FaceColor", [0.45 0.55 0.65]);
   hold on;
   plot([0.4 5.6], [1 1] * r_base, "k--", "LineWidth", 1.0);
   for i = 1:numel(bars)
      text(i, bars(i) + 0.002, sprintf("%.4f", bars(i)), "HorizontalAlignment", "center", ...
         "FontSize", 8, "Rotation", 90);
   end
   hold off;  grid on;
   set(gca, "XTick", 1:5, "XTickLabel", {"as measured", "to column mean", ...
      "to target profile", "our own amplitude", "a perfect day level"});
   ylim([min(bars) - 0.08, max(bars) + 0.02]);
   ylabel("band ratio, lower is better");
   title("d. three shrink forms, and the bound on knowing the day's level", "FontSize", 10);

   sgtitle("D02: over-dispersion of the forecast", "FontSize", 12);
   exportgraphics(f, fullfile(out_dir, "fig_d02.png"), "Resolution", 140);
   close(f);
end

% =========================================================================
function plot_d03(out_dir, lead_b, d03, Pa, PoC, Yc, n_b)
   f = figure("Visible", "off", "Position", [60 60 1500 950]);
   col = [0.12 0.31 0.47; 0.75 0.10 0.10];
   lb = lead_b(1:end - 1) / 60;

   subplot(2, 2, 1);
   hold on;
   for k = 1:2
      plot(lb, abs(d03.c11(k, :)), "-", "Color", col(k, :), "LineWidth", 1.8);
   end
   plot([6 24], [0.1 0.1], "k:", "LineWidth", 1.2);
   hold off;  grid on;
   xlabel("lead, hours");  ylabel("|corr(revision, the one before it)|");
   title("a. consecutive revisions of one target", "FontSize", 11);
   legend({"ours", "official"}, "Location", "northwest", "Box", "off", "FontSize", 8);

   subplot(2, 2, 2);
   hold on;
   for k = 1:2
      plot(lb, d03.eff(k, :), "-", "Color", col(k, :), "LineWidth", 1.8);
   end
   plot([6 24], [0 0], "k--", "LineWidth", 0.9);
   hold off;  grid on;
   xlabel("lead, hours");  ylabel("error removed per unit revision variance");
   title("b. one is a revision landing on the truth, zero is noise", "FontSize", 11);
   legend({"ours", "official"}, "Location", "southeast", "Box", "off", "FontSize", 8);

   subplot(2, 2, 3);
   hold on;
   pick_dd = [7 15 23];
   pick_s = [60 140 220];
   for i = 1:numel(pick_dd)
      dd = pick_dd(i);
      s0 = pick_s(i);
      va = squeeze(Pa(dd, s0, :));
      vo = squeeze(PoC(dd, s0, :));
      plot(lead_b / 60, va, "-o", "Color", col(1, :) * (1 - 0.22 * (i - 1)), ...
         "LineWidth", 1.2, "MarkerSize", 2.5);
      plot(lead_b / 60, vo, "--", "Color", col(2, :) * (1 - 0.22 * (i - 1)), "LineWidth", 1.1);
      y0 = Yc(dd, s0, 1);
      plot(lead_b([1 end]) / 60, [y0, y0], ":", "Color", [0.35 0.35 0.35] * (1 - 0.2 * (i - 1)));
   end
   hold off;  grid on;
   xlabel("lead, hours");  ylabel("forecast for one fixed target, $/MWh");
   title("c. three targets, every vintage that described them", "FontSize", 11);

   subplot(2, 2, 4);
   bars = [d03.st_base.band, d03.st_ant.band];
   bar(bars, 0.5, "FaceColor", [0.45 0.55 0.65]);
   hold on;
   plot([0.4 2.6], [1 1] * bars(1), "k--", "LineWidth", 1.0);
   for i = 1:2
      text(i, bars(i) + (max(bars) - min(bars)) * 0.12, sprintf("%.4f", bars(i)), ...
         "HorizontalAlignment", "center", "FontSize", 10);
   end
   hold off;  grid on;
   set(gca, "XTick", 1:2, "XTickLabel", {"as measured", "revision anticipated"});
   span = max(bars) - min(bars);
   ylim([min(bars) - 2 * span, max(bars) + 2 * span]);
   ylabel("band ratio, lower is better");
   title("d. what anticipating the next revision is worth", "FontSize", 11);

   sgtitle("D03: the revision sequence", "FontSize", 12);
   exportgraphics(f, fullfile(out_dir, "fig_d03.png"), "Resolution", 140);
   close(f);
end

% =========================================================================
function plot_d06(out_dir, d06, Eb, Ebo, uk, dmean, dmed)
   f = figure("Visible", "off", "Position", [60 60 1500 950]);
   col = [0.12 0.31 0.47; 0.75 0.10 0.10];

   subplot(2, 2, 1);
   plot(uk, dmean, "-", "Color", col(1, :), "LineWidth", 0.9);
   hold on;
   plot(uk, dmed, "-", "Color", [0.55 0.70 0.35], "LineWidth", 0.9);
   hold off;  grid on;
   xlabel("day");  ylabel("$/MWh");
   title("a. daily mean and daily median of the settled price", "FontSize", 11);
   legend({"mean", "median"}, "Location", "northwest", "Box", "off", "FontSize", 8);

   subplot(2, 2, 2);
   L = numel(d06.acf) - 1;
   n = numel(dmean);
   hold on;
   plot([0.4 L + 0.6], [1 1] * 1.96 / sqrt(n), "k:", "LineWidth", 1.0);
   plot([0.4 L + 0.6], -[1 1] * 1.96 / sqrt(n), "k:", "LineWidth", 1.0);
   bar((0:L) - 0.2, d06.acf, 0.36, "FaceColor", col(1, :));
   bar((0:L) + 0.2, d06.acf_eval, 0.36, "FaceColor", col(2, :));
   hold off;  grid on;
   xlabel("lag, days");  ylabel("autocorrelation of the daily mean");
   title(sprintf("b. lag one %.3f, prediction R squared %.3f", d06.acf(2), d06.r2_lag1), ...
      "FontSize", 11);
   legend({"95% band", "", "whole history", "evaluation window"}, "Location", "northeast", ...
      "Box", "off", "FontSize", 8);

   subplot(2, 2, 3);
   x = dmean(1:end - 1);
   y = dmean(2:end);
   lo = min([x; y]);
   hi = max([x; y]);
   plot([lo hi], [lo hi], "k-", "LineWidth", 0.9);
   hold on;
   scatter(x, y, 14, col(1, :), "filled", "MarkerFaceAlpha", 0.5);
   plot([lo hi], mean(y) + d06.b_lag1 * ([lo hi] - mean(x)), "-", ...
      "Color", [0.95 0.55 0.10], "LineWidth", 2.0);
   hold off;  grid on;
   xlabel("today, $/MWh");  ylabel("tomorrow, $/MWh");
   title(sprintf("c. slope %.3f, R squared %.3f", d06.b_lag1, d06.r2_lag1), "FontSize", 11);

   subplot(2, 2, 4);
   ma = day_means(Eb);
   mo = day_means(Ebo);
   lo = prctile([ma; mo], 0.5);
   hi = prctile([ma; mo], 99.5);
   edges = linspace(lo, hi, 29);
   hold on;
   histogram(ma, edges, "Normalization", "probability", "DisplayStyle", "stairs", ...
      "EdgeColor", col(1, :), "LineWidth", 1.6);
   histogram(mo, edges, "Normalization", "probability", "DisplayStyle", "stairs", ...
      "EdgeColor", col(2, :), "LineWidth", 1.6);
   hold off;  grid on;
   xlabel("mean signed band error on one target day, $/MWh");
   ylabel("share of days");
   title(sprintf("d. the day offset carries %.1f%% of our error, %.1f%% of theirs", ...
      100 * d06.day_share_own, 100 * d06.day_share_off), "FontSize", 10);
   legend({"ours", "official"}, "Location", "northwest", "Box", "off", "FontSize", 8);

   sgtitle("D06: the daily level", "FontSize", 12);
   exportgraphics(f, fullfile(out_dir, "fig_d06.png"), "Resolution", 140);
   close(f);
end

% =========================================================================
function m = day_means(E)
   m = nan(size(E, 1), 1);
   for dd = 1:size(E, 1)
      v = reshape(E(dd, :, :), [], 1);
      m(dd) = mean(v(isfinite(v)));
   end
end
