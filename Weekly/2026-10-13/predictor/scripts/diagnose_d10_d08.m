function diagnose_d10_d08()
   % DIAGNOSE_D10_D08  Alignment audit of the official benchmark, and the night bias.
   %
   % D10  Does the official column describe the interval it is scored against, and
   %      could any of it be published after the origin?
   %
   %      a) The fold offset. From one hour out OFFICIAL_COMPOSITE rounds the
   %         target up onto the :00/:30 grid, while the actual price is read at
   %         exactly origin plus lead. The gap depends only on the origin's phase,
   %         so it is reported as a distribution, and the handicap it imposes is
   %         measured as the error at the half hour the value actually describes.
   %      b) The P5MIN band against the raw file, through a run-by-offset matrix
   %         built here instead of through OFFICIAL_COMPOSITE.
   %      c) The timestamp convention, as a (row offset, actual offset) error
   %         surface. A naive version compares two rows of the SAME run against one
   %         actual, which mixes lead with phase and reports a one-step shift that
   %         is not there. Holding the row and moving the actual is the form that
   %         isolates phase, and it is the reason the diagonal is the answer.
   %
   %      The leak question is NOT answered by asserting AGE4 >= 0. AGE4 is
   %      O - eff(k) with k the last run at or before O, so it is non-negative by
   %      construction and the assertion is empty. What is reported instead is the
   %      staleness of each product at the origin, which is the quantity that
   %      decides how much of its own information a product really brings.
   %
   % D08  Is the night error a bias an anchor change could remove, or noise?
   %      Signed error per target slot over the 6 to 24 hour band.
   %
   % Cube addressing, which is the easy thing to get wrong: a cell is indexed by
   % its TARGET, not by its origin. Slot is the target's time of day and day is
   % the target's day, so a late origin with a short lead belongs to the next day.
   %
   % Writes Weekly/2026-10-13/research/verify/d10_d08.json.
   % Run: runs\run_diagnose_d10_d08.bat <log name>

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   out_dir = fullfile(root, "Weekly", "2026-10-13", "research", "verify");
   if ~exist(out_dir, "dir"), mkdir(out_dir); end
   addpath(genpath(fullfile(root, "Predicitor")));

   n_s = 288;  n_h = 376;
   [lead_min, lead_step] = official_lead_axis();
   lead_min = lead_min(:)';  lead_step = lead_step(:)';
   band = find(lead_min >= 360 & lead_min <= 1440);
   bp = @(L) find(lead_min(band) == L, 1);          % position inside the band
   n_b = numel(band);

   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   o_score = double(O.d_score);  o_score = o_score(:)';
   a_score = double(A.d_score);  a_score = a_score(:)';
   assert(isequal(o_score, a_score), "d10:days", "the two cubes score different days");
   n_day = numel(o_score);
   n_win = 60;
   names = string(A.names);
   t_test = O.t_test;
   R_off = double(O.R_off);
   fprintf("scored days %d, models %d, band %d columns, window %d days\n", ...
      n_day, numel(names), n_b, n_win);

   O4 = double(O.O4(:, :, o_score));
   E_off = double(O.E4_off(:, :, o_score));
   SRC = O.SRC4(:, :, o_score);
   AGE = double(O.AGE4(:, :, o_score));

   % ======================================================================
   % D10 a1) staleness of the supplying run at the origin, per product
   % ======================================================================
   fprintf("\n=== D10 a1) staleness of the supplying run at the origin ===\n");
   have = SRC > 0;
   n_name = ["P5MIN", "PREDISPATCH", "PD7DAY"];
   for p = 1:3
      a = AGE(SRC == p);
      a = a(isfinite(a)) / 60;
      fprintf("  %-12s n %7d  min %5.2f h  median %5.2f h  max %6.2f h\n", ...
         n_name(p), numel(a), min(a), median(a), max(a));
   end
   fprintf("  cells with no source: %d of %d (%.2f%%)\n", ...
      sum(~have, "all"), numel(have), 100 * mean(~have, "all"));
   % What the assertion would have tested, and why it cannot fail.
   fprintf("  AGE4 non-negative everywhere: %d (by construction, O - eff with eff <= O)\n", ...
      all(AGE(have) >= 0));

   % ======================================================================
   % D10 a2) the fold offset, and the error at the half hour actually described
   % ======================================================================
   fprintf("\n=== D10 a2) fold offset on the 30-minute columns ===\n");
   % The origin of slot s sits at 5*s minutes past midnight, so the amount the
   % target is pushed later is a function of the slot alone.
   off_of_slot = mod(-5 * (0:n_s-1), 30);
   fprintf("  fold offset values, minutes: %s\n", mat2str(unique(off_of_slot)));
   fprintf("  slots with offset 0: %d of %d (%.1f%%)\n", sum(off_of_slot == 0), ...
      n_s, 100 * mean(off_of_slot == 0));

   [t_y, y_all] = load_price_months(fullfile(root, "AEMO_Data"), ...
      ["202608", "202609", "202610"]);
   m_y = double(nem_minutes(t_y));
   m_t0 = double(nem_minutes(t_test(1)));
   m0 = min([m_t0, min(m_y)]);  m1 = max([double(nem_minutes(t_test(end))), max(m_y)]);
   n_grid = (m1 - m0) / 5 + 1;
   Y = nan(n_grid, 1);
   Y((m_y - m0) / 5 + 1) = y_all;
   fprintf("  price grid %d samples, %.1f%% filled, %.2f to %.2f $/MWh\n", ...
      n_grid, 100 * mean(isfinite(Y)), min(y_all), max(y_all));

   ob = O4(:, band, :);  ob = sort(ob(:));  ob = ob(isfinite(ob));
   fx = @(p) ob(max(1, min(numel(ob), round(p * numel(ob)))));
   fprintf("  official value, band cells: n %d  min %.1f  p0.1 %.1f  median %.1f  p99.9 %.1f  max %.1f\n", ...
      numel(ob), ob(1), fx(0.001), fx(0.5), fx(0.999), ob(end));
   fprintf("  |official| above 5000 $/MWh: %d of %d cells (%.3f%%)\n", ...
      sum(abs(ob) > 5000), numel(ob), 100 * mean(abs(ob) > 5000));
   eb = E_off(:, band, :);  eb = sort(eb(:));  eb = eb(isfinite(eb));
   fprintf("  stored clamped error, band cells: min %.1f  median %.1f  max %.1f  rms %.1f\n", ...
      eb(1), eb(round(numel(eb) / 2)), eb(end), sqrt(mean(eb .^ 2)));
   SS_pt = zeros(n_s, n_h);  N_pt = zeros(n_s, n_h);
   SS_pd = zeros(n_s, n_h);  N_pd = zeros(n_s, n_h);
   SS_x = zeros(1, n_h);  SS_o = zeros(1, n_h);  SS_m = zeros(1, n_h);
   N_m = zeros(1, n_h);
   d0 = o_score(1);                                   % first scored day of the window
   n_skip_day = 0;  n_skip_y = 0;  n_ext = 0;
   for d = 1:n_day
      for s = 1:n_s
         j = (o_score(d) - 1) * n_s + s;              % origin sample in the window
         jt = j + lead_step;                          % target sample, 1 x n_h
         u_t = mod(s - 1 + lead_step, n_s) + 1;       % target slot
         dc = floor((jt - 1) / n_s) + 1 - d0 + 1;     % target day, as a cube index
         iy = (m_t0 + 5 * (jt - 1) - m0) / 5 + 1;
         ok = dc >= 1 & dc <= n_day & iy >= 1 & iy <= n_grid;
         n_skip_day = n_skip_day + sum(dc >= n_day + 1 | dc < 1);
         n_skip_y = n_skip_y + sum(iy < 1 | iy > n_grid);
         if ~any(ok), continue; end
         lin = nan(1, n_h);
         lin(ok) = u_t(ok) + n_s * (find(ok) - 1) + n_s * n_h * (dc(ok) - 1);
         v = nan(1, n_h);
         v(ok) = O4(lin(ok));
         yp = nan(1, n_h);
         yp(ok) = Y(iy(ok));
         ep = yp - v;
         % A handful of official values sit orders of magnitude outside the price
         % range, and the clamp in the stored surface is what keeps them from
         % taking the benchmark over. Nothing that wide is a price forecast, so it
         % is counted and excluded instead of being allowed to set the scale.
         gp = isfinite(ep) & abs(v) <= 5000;
         n_ext = n_ext + sum(isfinite(ep) & abs(v) > 5000);
         % Mask by indexing, not by multiplying with the flag: NaN times false is
         % NaN, not zero, and one poisoned sample would take the whole column out
         % of the median without any warning.
         t2 = zeros(1, n_h);  t2(gp) = ep(gp) .^ 2;
         SS_pt(s, :) = SS_pt(s, :) + t2;
         N_pt(s, :) = N_pt(s, :) + gp;

         % Address check. The stored error is clamped and the one here is not, so
         % the levels must differ, but the two must track cell for cell. A low
         % correlation would mean this path reads a different cell than the cube.
         eo = nan(1, n_h);
         eo(ok) = E_off(lin(ok));
         % Restricted to the bulk of the cells: the stored error has a tail wide
         % enough to set the scale of any squared statistic computed over it.
         gm = gp & isfinite(eo) & abs(eo) <= 200;
         SS_x = SS_x + sum(ep(gm) .* eo(gm));
         SS_o = SS_o + sum(eo(gm) .^ 2);
         SS_m = SS_m + sum(ep(gm) .^ 2);
         N_m = N_m + gm;

         % the half hour the official value describes ends at the folded target
         jq = jt(band) + off_of_slot(s) / 5;
         jq6 = jq(:) + (-5:0);
         iq = (m_t0 + 5 * (jq6 - 1) - m0) / 5 + 1;
         gq = iq >= 1 & iq <= n_grid;
         iq(~gq) = 1;
         yq = mean(reshape(Y(iq), size(jq6)), 2, "omitnan");
         yq(any(~gq, 2)) = NaN;
         eq = (yq - v(band)')';
         gq2 = isfinite(eq) & abs(v(band)) <= 5000;
         tq = zeros(1, n_b);  tq(gq2) = eq(gq2) .^ 2;
         SS_pd(s, band) = SS_pd(s, band) + tq;
         N_pd(s, band) = N_pd(s, band) + gq2;
      end
   end

   R_pt = sqrt(SS_pt ./ max(N_pt, 1));                 % 288 slots x 376 leads
   R_pd = sqrt(SS_pd ./ max(N_pd, 1));
   R_pt(N_pt == 0) = NaN;  R_pd(N_pd == 0) = NaN;
   fprintf("  excluded cells: %d past the last scored day, %d outside the price grid,\n", ...
      n_skip_day, n_skip_y);
   fprintf("    %d with an official value beyond 5000 $/MWh\n", n_ext);
   fprintf("  band columns with no usable slot: %d of %d, slots used min %d median %d\n", ...
      sum(all(isnan(R_pt(:, band)), 1)), n_b, ...
      min(sum(isfinite(R_pt(:, band)), 1)), median(sum(isfinite(R_pt(:, band)), 1)));
   prof_pt = median(R_pt(:, band), 1, "omitnan");
   prof_pd = median(R_pd(:, band), 1, "omitnan");
   fprintf("  period against point, unclamped, NOT usable as a correction:\n");
   rr = prof_pd ./ prof_pt;
   fprintf("    band median point %.3f, period %.3f, per-column ratio median %.3f range %.3f to %.3f\n", ...
      median(prof_pt), median(prof_pd), median(rr), min(rr), max(rr));
   fprintf("    the official value carries a tail this path does not clamp, so the level is\n");
   fprintf("    set by that tail. The correction needs the clamped series and stays open.\n");
   fprintf("  reference, stored clamped surface: pooled over band cells %.3f, ", ...
      median(reshape(R_off(:, band), [], 1), "omitnan"));
   fprintf("median over slots then columns %.3f\n", ...
      median(median(R_off(:, band), 1, "omitnan")));
   corr_ok = SS_x ./ sqrt(SS_m .* SS_o);
   fprintf("  address check, correlation of this path against the stored surface:\n");
   for L = [360, 480, 720, 1080, 1440]
      kk = band(bp(L));
      fprintf("    %5.1f h  corr %.4f  rms_here %7.2f  rms_stored %7.2f  n %d\n", ...
         lead_min(kk) / 60, corr_ok(kk), sqrt(SS_m(kk) / N_m(kk)), ...
         sqrt(SS_o(kk) / N_m(kk)), N_m(kk));
   end
   cmin = min(corr_ok(band));
   fprintf("    min correlation over the band: %.4f at %.1f h\n", cmin, ...
      lead_min(band(find(corr_ok(band) == cmin, 1))) / 60);
   fprintf("    lead    point   period    ratio   n_period\n");
   for k = [bp(360), bp(480), bp(720), bp(1080), bp(1440)]
      kk = band(k);
      fprintf("  %6.1f h %8.3f %8.3f %8.3f %10d\n", lead_min(kk) / 60, ...
         prof_pt(k), prof_pd(k), prof_pd(k) / prof_pt(k), sum(N_pd(:, kk), "all"));
   end

   % ======================================================================
   % D10 b) the P5MIN band rebuilt from the raw file
   % ======================================================================
   fprintf("\n=== D10 b) P5MIN band against the raw file ===\n");
   p5_path = fullfile(root, "AEMO_Data", ...
      "window_60d_20260811_20261009_vic1", "p5min_vic1_partial", ...
      "p5min_20260811_20261009.csv");
   fid = fopen(p5_path, "r");
   assert(fid > 0, "d10:p5", "cannot open %s", p5_path);
   c = textscan(fid, "%s %s %s %f %f %f", "Delimiter", ",", "HeaderLines", 1, ...
      "ReturnOnError", false);
   fclose(fid);
   eff = nem_minutes(c{1});  tgt = nem_minutes(c{3});  rrp = c{4};
   lag = tgt - eff;
   assert(all(mod(lag, 5) == 0) && all(lag >= 0) && all(lag <= 55), ...
      "d10:p5lag", "P5MIN carries an offset outside 0 to 55 minutes");
   u_eff = unique(eff);
   n_run = numel(u_eff);
   [~, kr] = ismember(eff, u_eff);
   P5 = nan(n_run, 12);
   P5(sub2ind([n_run, 12], kr, double(lag / 5) + 1)) = rrp;
   fprintf("  %d rows, %d runs, %.1f%% of the run-by-offset matrix filled, lags %d to %d min\n", ...
      numel(rrp), n_run, 100 * numel(rrp) / numel(P5), min(lag), max(lag));

   worst = 0;  n_cmp = 0;  n_pres = 0;  n_abs = 0;
   ss_raw = 0;  n_raw = 0;
   nb1 = find(lead_min <= 55);
   for d = 1:n_day
      for s = 1:n_s
         j = (o_score(d) - 1) * n_s + s;
         m = m_t0 + 5 * (j - 1);
         r = (m - double(u_eff(1))) / 5 + 1;
         if r < 1 || r > n_run || double(u_eff(r)) ~= m, n_abs = n_abs + 1; continue; end
         v = P5(r, 2:12);                                % offsets 5 to 55 minutes
         jt = j + lead_step(nb1);
         u_t = mod(s - 1 + lead_step(nb1), n_s) + 1;
         dc = floor((jt - 1) / n_s) + 1 - d0 + 1;
         okd = dc >= 1 & dc <= n_day;
         lin = nan(1, numel(nb1));
         lin(okd) = u_t(okd) + n_s * (nb1(okd) - 1) + n_s * n_h * (dc(okd) - 1);
         g = nan(1, numel(nb1));
         g(okd) = O4(lin(okd));
         both = isfinite(v) & isfinite(g);
         n_cmp = n_cmp + sum(both);
         if any(both), worst = max(worst, max(abs(v(both) - g(both)))); end
         n_pres = n_pres + sum(isfinite(v) ~= isfinite(g));
         % Only the 5-minute column: that is the cell the cube stores as column 1.
         iy1 = (m_t0 + 5 * (j + lead_step(1) - 1) - m0) / 5 + 1;
         if isfinite(v(1)) && iy1 >= 1 && iy1 <= n_grid && isfinite(Y(iy1))
            ss_raw = ss_raw + (Y(iy1) - v(1)) ^ 2;
            n_raw = n_raw + 1;
         end
      end
   end
   fprintf("  cube against raw: %d cells compared, worst |diff| %.4g, presence mismatches %d\n", ...
      n_cmp, worst, n_pres);
   fprintf("  origins with no P5MIN run at that exact timestamp: %d\n", n_abs);
   e1 = E_off(:, 1, :);  e1 = e1(isfinite(e1));
   fprintf("  5-minute column pooled RMSE: cube %.3f (clamped), raw %.3f (unclamped), n %d\n", ...
      sqrt(mean(e1 .^ 2)), sqrt(ss_raw / n_raw), n_raw);
   fprintf("    the clamp caps the actual price, so the cube figure is the smaller one by\n");
   fprintf("    construction; what the pair shows is that neither is near zero\n");

   % timestamp convention, measured on this project's own series
   fprintf("\n  phase surface, P5MIN row offset j against actual offset l\n");
   offs = 0:5:55;
   idx_eff = (double(u_eff) - m0) / 5 + 1;
   S2 = zeros(numel(offs));  N2 = zeros(numel(offs));
   for a = 1:numel(offs)
      pred = P5(:, offs(a) / 5 + 1);
      for b = 1:numel(offs)
         ii = idx_eff + offs(b) / 5;
         good = isfinite(pred) & ii >= 1 & ii <= n_grid;
         act = nan(size(pred));
         act(good) = Y(ii(good));
         good = good & isfinite(act);
         S2(a, b) = sum((pred(good) - act(good)) .^ 2);
         N2(a, b) = sum(good);
      end
   end
   PH = sqrt(S2 ./ N2);
   fprintf("    j\\l  %s\n", sprintf("%8d", offs));
   for a = 1:numel(offs)
      fprintf("    %3d  %s\n", offs(a), sprintf("%8.2f", PH(a, :)));
   end
   dg = diag(PH)';
   fprintf("    diagonal wins %d of %d against the one-step-later column, median %.2f vs %.2f\n", ...
      sum(dg(1:end-1) < PH(sub2ind(size(PH), 1:numel(offs)-1, 2:numel(offs)))), ...
      numel(offs) - 1, median(dg(1:end-1)), ...
      median(PH(sub2ind(size(PH), 1:numel(offs)-1, 2:numel(offs)))));

   % ======================================================================
   % D08  signed error by target slot over the band
   % ======================================================================
   fprintf("\n=== D08 signed error by target slot, band %.1f to %.1f h ===\n", ...
      lead_min(band(1)) / 60, lead_min(band(end)) / 60);
   hour = ((1:n_s) - 1) * 5 / 60;                      % clock hour of the slot end
   blk = struct();
   blk.night = hour < 6;      blk.morn = hour >= 6 & hour < 12;
   blk.aft = hour >= 12 & hour < 17;
   blk.eve = hour >= 17 & hour < 20;  blk.late = hour >= 20;
   fn = ["night", "morn", "aft", "eve", "late"];

   want = ["Anchor-mix", "T28 + AR4", "Carry-forward"];
   bias_off = squeeze(mean(mean(E_off(:, band, :), 2, "omitnan"), 3, "omitnan"))';
   bias_mod = nan(numel(want), n_s);
   rms_mod = nan(numel(want), n_s);
   for i = 1:numel(want)
      mm = find(names == want(i), 1);
      assert(~isempty(mm), "d08:model", "no model called %s", want(i));
      Em = double(A.E4(1:n_s, band, a_score, mm));
      bias_mod(i, :) = squeeze(mean(mean(Em, 2, "omitnan"), 3, "omitnan"))';
      rms_mod(i, :) = squeeze(sqrt(mean(mean(Em .^ 2, 2, "omitnan"), 3, "omitnan")))';
      clear Em
   end

   fprintf("  %-14s %8s %8s %8s %8s %8s %10s\n", ...
      "source", fn, "night_max");
   bsel = struct();
   for i = 0:numel(want)
      if i == 0
         v = bias_off;  lab = "official";
      else
         v = bias_mod(i, :);  lab = want(i);
      end
      vals = arrayfun(@(b) mean(v(blk.(fn(b))), "omitnan"), 1:numel(fn));
      bsel.(matlab.lang.makeValidName(lab)) = vals;
      fprintf("  %-14s %8.2f %8.2f %8.2f %8.2f %8.2f %10.2f\n", lab, vals, ...
         max(abs(v(blk.night))));
   end
   fprintf("  (mean signed error, actual minus forecast, $/MWh, then the largest\n");
   fprintf("   single-slot night bias in absolute value)\n");

   night_bias = nan(1, n_b);  night_rms = nan(1, n_b);
   Em = double(A.E4(1:n_s, band, a_score, find(names == "Anchor-mix", 1)));
   for kk = 1:n_b
      sub = Em(blk.night, kk, :);
      night_bias(kk) = mean(sub(:), "omitnan");
      night_rms(kk) = sqrt(mean(sub(:) .^ 2, "omitnan"));
   end
   clear Em
   fprintf("  anchor-mix night bias by lead:\n");
   for L = [360, 720, 1080, 1440]
      kk = bp(L);
      fprintf("    %5.1f h  bias %7.2f  rms %7.2f  bias over rms %5.3f\n", ...
         lead_min(band(kk)) / 60, night_bias(kk), night_rms(kk), ...
         night_bias(kk) / night_rms(kk));
   end
   fprintf("  night RMS if the bias were removed, band median: %.2f of %.2f\n", ...
      median(sqrt(max(night_rms .^ 2 - night_bias .^ 2, 0))), median(night_rms));

   % ======================================================================
   % write
   % ======================================================================
   out = struct();
   out.lead_min = lead_min;
   out.band = band;
   out.d_score = o_score;
   out.fold_offset_by_slot = off_of_slot;
   out.prof_point_band = prof_pt;
   out.prof_period_band = prof_pd;
   out.band_median_point = median(prof_pt);
   out.band_median_period = median(prof_pd);
   out.period_compare_status = "unresolved, unclamped tail sets the level";
   out.R_off_band_median = median(reshape(R_off(:, band), [], 1), "omitnan");
   out.R_repro_band_median = median(reshape(R_pt(:, band), [], 1), "omitnan");
   out.p5_cells_compared = n_cmp;
   out.p5_worst_diff = worst;
   out.p5_presence_mismatch = n_pres;
   out.p5_origins_without_run = n_abs;
   out.p5_raw_runs = n_run;
   out.rmse_5min_cube = sqrt(mean(e1 .^ 2));
   out.rmse_5min_raw = sqrt(ss_raw / n_raw);
   out.phase_offsets = offs;
   out.phase_surface = PH;
   out.bias_slot_official = bias_off;
   out.bias_slot_models = bias_mod;
   out.rms_slot_models = rms_mod;
   out.bias_model_names = want;
   out.clock_hour = hour;
   out.bias_block = bsel;
   out.night_bias_by_lead = night_bias;
   out.night_rms_by_lead = night_rms;
   out.night_band = band;
   txt = jsonencode(out);
   f = fullfile(out_dir, "d10_d08.json");
   fid = fopen(f, "w");
   fwrite(fid, txt, "char");
   fclose(fid);
   fprintf("\nwrote %s (%d bytes)\n", f, numel(txt));
end


function [t, y] = load_price_months(data_dir, months)
   % Three months of the 5-minute price series, read with a fixed format.
   % LOAD_AEMO_DATA globs every month present and runs detectImportOptions on
   % each, which is minutes of work for a diagnostic that needs three files.
   T = strings(0, 1);  V = zeros(0, 1);
   for m = months
      p = fullfile(data_dir, "PRICE_AND_DEMAND_" + m + "_VIC1.csv");
      fid = fopen(p, "r");
      assert(fid > 0, "d10:price", "cannot open %s", p);
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
end
