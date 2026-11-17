function diagnose_m02_m05(tag)
   % DIAGNOSE_M02_M05  Two candidates from the price-history set, on the scored surface.
   %
   %    M02  take the k models with the smallest error in each column and weight
   %         them equally. The hypothesis is that the winner depends on the lead.
   %         Selection must come from one sample and scoring from another, so a
   %         strict first-half fit and a two-fold cross fit are both run. The in
   %         sample per-column winner is the ceiling, and the distance between it
   %         and the cross fit is the cost of selection noise.
   %
   %    M05  project each day profile onto the first few principal components of
   %         the settled daily profile. A projection is a contraction onto a linear
   %         subspace, so the residual of the settled profile nearest that subspace
   %         bounds every candidate living in it. That bound is scored directly. It
   %         needs no fitting and cannot be beaten by a better estimator, only by
   %         leaving the subspace.
   %
   % Both are measured on the same reconstruction as the other diagnostics: the
   % clamp is rebuilt from the price series and checked against the official cube
   % before anything is scored. The 1 hour column is carried alongside the 37 band
   % columns because both candidates act on it as well.
   %
   % Run: runs\run_diagnose_m02_m05.bat

   if nargin < 1 || strlength(string(tag)) == 0
      tag = "m02_m05";
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
   assert(n_b == 37, "m02:band", "band is %d columns, expected 37", n_b);
   c_1h = find(lead_min == 60, 1);
   assert(~isempty(c_1h), "m02:1h", "no 60 minute column");
   % Every column from one hour to twenty four hours, so the boundary of the
   % projection is measured and not guessed. The band is eleven to forty seven.
   raw_c = c_1h:band(end);
   sel_c = 1:numel(raw_c);
   cols = raw_c;
   n_c = numel(cols);
   ib = band - (c_1h - 1);
   assert(n_c == 47, "m02:cols", "the slab is %d columns, expected 47", n_c);
   lead_c = lead_min(cols);

   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   names = string(A.names);
   names = names(:);
   n_m = numel(names);
   assert(n_m == 16, "m02:pool", "the pool has %d models, expected 16", n_m);
   m_anc = find(names == "Anchor-mix", 1);
   assert(~isempty(m_anc), "m02:anchor", "Anchor-mix is not in the atlas");
   dsc = double(A.d_score);
   dsc = dsc(:)';
   n_day = numel(dsc);
   t_test = A.t_test;
   t_test = t_test(:);
   n_win = 60;
   fprintf("scored days %d, window days %d to %d, %d band columns plus the 1 h column\n", ...
      n_day, dsc(1), dsc(end), n_b);

   % =====================================================================
   % Rebuild the causal [Q1, Q99] clamp exactly as the two builders do
   % =====================================================================
   n_q = 30;
   [tp, yp] = read_vic1(data_dir, ["202607", "202608", "202609", "202610"]);
   y_win0 = yp(tp >= datetime(2026, 7, 12, 0, 5, 0) & tp <= datetime(2026, 8, 11, 0, 0, 0));
   assert(numel(y_win0) == n_q * n_s, "m02:warm", ...
      "warm-up window is %d samples, expected %d", numel(y_win0), n_q * n_s);
   mt = tp >= t_test(1) & tp <= t_test(end);
   y_test = yp(mt);
   assert(numel(y_test) == numel(t_test), "m02:len", ...
      "test window is %d samples, the cube has %d", numel(y_test), numel(t_test));
   assert(numel(y_test) == n_win * n_s, "m02:win", "test window is not 60 whole days");

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
   % Slabs, [target day, target slot, column]. The cube is indexed by the
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
   Yc = repmat(Yg, 1, 1, n_c);

   % A MatFile range must be equally spaced, so the run of columns is read whole
   % and then cut down to the columns that are scored.
   E4b = double(A.E4(1:n_s, raw_c, dsc, :));
   E4b = permute(E4b(:, sel_c, :, :), [3 1 2 4]);
   Ea = E4b(:, :, :, m_anc);
   Eo = double(O.E4_off(1:n_s, raw_c, dsc));
   Eo = permute(Eo(:, sel_c, :), [3 1 2]);
   Ocl = double(O.O4(1:n_s, raw_c, dsc));
   Ocl = permute(Ocl(:, sel_c, :), [3 1 2]);
   assert(isequal(size(Ea), [n_day n_s n_c]), "m02:slab", ...
      "our slab is %s, expected %s", mat2str(size(Ea)), mat2str([n_day n_s n_c]));
   fprintf("band cells %d, ours finite %.2f%%, official finite %.2f%%\n", ...
      n_day * n_s * n_b, 100 * mean(isfinite(Ea(:, :, ib)), "all"), ...
      100 * mean(isfinite(Eo(:, :, ib)), "all"));

   % The official forecast is stored unclamped, so this is a hard address check.
   PoC = Yc - Eo;
   Ochk = min(max(Ocl, repmat(Q1g, 1, 1, n_c)), repmat(Q2g, 1, 1, n_c));
   dc_ = abs(PoC - Ochk);
   dc_ = dc_(isfinite(dc_));
   fprintf("clamp check against the official cube: %d cells, max |diff| %.3g\n", ...
      numel(dc_), max(dc_));
   assert(max(dc_) < 1e-3, "m02:clamp", "the rebuilt clamp does not reproduce E4_off");
   clear Ocl Ochk PoC

   % =====================================================================
   % Baseline and M01 on this reconstruction
   % =====================================================================
   r_base = band_ratio(Ea(:, :, ib), Eo(:, :, ib), n_b);
   r_base_1h = one_ratio(Ea, Eo, 1);
   r_off_med = column_median_R(Eo, n_s, n_c);
   Rcol = column_median_R(E4b, n_s, n_c);
   Em01 = mean(E4b, 4, "omitnan");
   st_start = cand_stats(Ea(:, :, ib), Eo(:, :, ib), n_b);
   st_m01 = cand_stats(Em01(:, :, ib), Eo(:, :, ib), n_b);
   r_m01 = st_m01.band;
   r_m01_1h = one_ratio(Em01, Eo, 1);
   [nb_s, nw_s] = dm_band(Ea(:, :, ib), Eo(:, :, ib));
   [nb_1, nw_1] = dm_band(Em01(:, :, ib), Eo(:, :, ib));
   fprintf("\nbaseline on this reconstruction\n");
   fprintf("  %-10s band %.4f  1 h %.4f  6 h %.4f  24 h %.4f  win %.2f%%  RMS %.3f  q90 %.2f\n", ...
      "Anchor-mix", st_start.band, r_base_1h, st_start.c6h, st_start.c24h, st_start.win, ...
      st_start.rms, st_start.q90);
   fprintf("  against the official, day-clustered DM: %d cells significantly better, %d worse\n", ...
      nb_s, nw_s);
   fprintf("  %-10s band %.4f  1 h %.4f  6 h %.4f  24 h %.4f  win %.2f%%  RMS %.3f  q90 %.2f\n", ...
      "M01", st_m01.band, r_m01_1h, st_m01.c6h, st_m01.c24h, st_m01.win, st_m01.rms, ...
      st_m01.q90);
   fprintf("  against the official, day-clustered DM: %d cells significantly better, %d worse\n", ...
      nb_1, nw_1);
   fprintf("  M01 against the incumbent: %+.2f%%\n", 100 * (r_m01 / st_start.band - 1));

   % =====================================================================
   % M02  per-column selection
   % =====================================================================
   fprintf("\n=== M02: per-column model selection ===\n");
   [rmin, imin] = min(Rcol(:, ib), [], 1);
   [uwin, ~, iw] = unique(imin);
   fprintf("  in-sample winners: %d distinct models over %d band columns\n", numel(uwin), n_b);
   for i = 1:numel(uwin)
      fprintf("    %-22s %2d columns, column-median R %.2f to %.2f\n", names(uwin(i)), ...
         nnz(iw == i), min(rmin(iw == i)), max(rmin(iw == i)));
   end
   fprintf("  lead ranges of one winner:\n");
   s0 = 1;
   for j = 2:n_b + 1
      if j > n_b || imin(j) ~= imin(s0)
         fprintf("    %.1f to %.1f h  %s\n", lead_b(s0) / 60, lead_b(j - 1) / 60, ...
            names(imin(s0)));
         s0 = j;
      end
   end
   fprintf("  criterion: gain against M01 above 2%%, with k fitted on one sample\n");

   k_list = [1 2 3 4 6 8 12 16];
   nk = numel(k_list);
   half = floor(n_day / 2);
   fitd = 1:half;
   evd = half + 1:n_day;

   % Strict split: fit on the first half, score on the second.
   Rf = column_median_R(E4b(fitd, :, :, :), n_s, n_c);
   [~, ord] = sort(Rf, 1, "ascend");
   ratio_strict = nan(nk, 1);
   for ii = 1:nk
      Ek = blend_topk(E4b, ord, evd, n_s, n_c, k_list(ii));
      ratio_strict(ii) = band_ratio(Ek(:, :, ib), Eo(evd, :, ib), n_b);
   end
   st_half = cand_stats(Ea(evd, :, ib), Eo(evd, :, ib), n_b);
   st_m01_half = cand_stats(Em01(evd, :, ib), Eo(evd, :, ib), n_b);
   fprintf("  second half only: Anchor-mix %.4f, M01 %.4f\n", st_half.band, st_m01_half.band);

   % Two-fold cross fit: every day is scored by a rule fitted on the other half.
   ratio_cross = nan(nk, 1);
   st_cross = cell(nk, 1);
   dm_cross = nan(nk, 2);
   ratio_cross_1h = nan(nk, 1);
   k_best = 0;
   for ii = 1:nk
      Ek = nan(n_day, n_s, n_c);
      for fold = 1:2
         if fold == 1
            fd = 1:half;  ed = half + 1:n_day;
         else
            fd = half + 1:n_day;  ed = 1:half;
         end
         Rf = column_median_R(E4b(fd, :, :, :), n_s, n_c);
         [~, ord] = sort(Rf, 1, "ascend");
         Ek(ed, :, :) = blend_topk(E4b, ord, ed, n_s, n_c, k_list(ii));
      end
      ratio_cross(ii) = band_ratio(Ek(:, :, ib), Eo(:, :, ib), n_b);
      ratio_cross_1h(ii) = one_ratio(Ek, Eo, 1);
      st_cross{ii} = cand_stats(Ek(:, :, ib), Eo(:, :, ib), n_b);
      [nb_, nw_] = dm_band(Ek(:, :, ib), Eo(:, :, ib));
      dm_cross(ii, :) = [nb_, nw_];
      if ratio_cross(ii) == min(ratio_cross)
         k_best = k_list(ii);
      end
      fprintf("  k=%2d  cross fit band %.4f  1 h %.4f  6 h %.4f  24 h %.4f  win %.2f%%" + ...
         "  RMS %.3f  DM %d better %d worse\n", k_list(ii), ratio_cross(ii), ...
         ratio_cross_1h(ii), st_cross{ii}.c6h, st_cross{ii}.c24h, st_cross{ii}.win, ...
         st_cross{ii}.rms, nb_, nw_);
   end

   % k chosen per column on the fit fold, then applied to the other half. The
   % first-half choice is reported; the ratio comes from both folds.
   kad = zeros(1, n_c);
   for jj = 1:n_c
      b = inf;
      for ii = 1:nk
         sel = ord(1:k_list(ii), jj);
         e = mean(E4b(fitd, :, jj, sel), 4, "omitnan");
         r = median(sqrt(mean(reshape(e, half, n_s) .^ 2, 1, "omitnan")), "omitnan");
         if r < b
            b = r;
            kad(jj) = k_list(ii);
         end
      end
   end
   Ek = nan(n_day, n_s, n_c);
   for fold = 1:2
      if fold == 1
         fd = 1:half;  ed = half + 1:n_day;
      else
         fd = half + 1:n_day;  ed = 1:half;
      end
      Rf = column_median_R(E4b(fd, :, :, :), n_s, n_c);
      [~, ordf] = sort(Rf, 1, "ascend");
      kk_f = zeros(1, n_c);
      for jj = 1:n_c
         b = inf;
         for ii = 1:nk
            sel = ordf(1:k_list(ii), jj);
            e = mean(E4b(fd, :, jj, sel), 4, "omitnan");
            r = median(sqrt(mean(reshape(e, numel(fd), n_s) .^ 2, 1, "omitnan")), "omitnan");
            if r < b
               b = r;
               kk_f(jj) = k_list(ii);
            end
         end
      end
      Ek(ed, :, :) = blend_topk(E4b, ordf, ed, n_s, n_c, kk_f);
   end
   r_kad = band_ratio(Ek(:, :, ib), Eo(:, :, ib), n_b);
   st_kad = cand_stats(Ek(:, :, ib), Eo(:, :, ib), n_b);
   fprintf("  k fitted per column: band %.4f, first-half k values %s\n", r_kad, ...
      mat2str(unique(kad)));

   % In-sample greedy ceiling: the best per-column subset, chosen with hindsight.
   kmax = max(k_list);
   Rg = nan(kmax, n_c);
   for jj = 1:n_c
      sel = [];
      for kk = 1:kmax
         b = inf;
         bi = 0;
         for i = 1:n_m
            if any(sel == i)
               continue;
            end
            e = mean(E4b(:, :, jj, [sel, i]), 4, "omitnan");
            r = median(sqrt(mean(e .^ 2, 1, "omitnan")), "omitnan");
            if r < b
               b = r;
               bi = i;
            end
         end
         sel(end + 1) = bi;
         Rg(kk, jj) = b;
      end
   end
   ratio_orc = nan(nk, 1);
   ratio_orc_1h = nan(nk, 1);
   for ii = 1:nk
      ratio_orc(ii) = median(Rg(k_list(ii), ib) ./ r_off_med(ib), "omitnan");
      ratio_orc_1h(ii) = Rg(k_list(ii), 1) / r_off_med(1);
   end
   fprintf("  in-sample ceiling: k=1 %.4f, k=3 %.4f, k=%d %.4f\n", ratio_orc(1), ...
      ratio_orc(3), k_list(nk), ratio_orc(nk));
   fprintf("  cost of selection: cross fit at k=%d %.4f against the ceiling %.4f\n", ...
      k_best, ratio_cross(k_list == k_best), ratio_orc(k_list == k_best));

   m02 = struct();
   m02.k_list = k_list;
   m02.Rcol = Rcol(:, ib);
   m02.Rcol_1h = Rcol(:, 1);
   m02.Rcol_off = r_off_med(ib);
   m02.winner = imin;
   m02.ratio_cross = ratio_cross;
   m02.ratio_cross_1h = ratio_cross_1h;
   m02.ratio_strict = ratio_strict;
   m02.ratio_orc = ratio_orc;
   m02.ratio_orc_1h = ratio_orc_1h;
   m02.ratio_kad = r_kad;
   m02.st_cross = st_cross;
   m02.dm_cross = dm_cross;
   m02.st_kad = st_kad;
   m02.st_half = st_half;
   m02.st_m01_half = st_m01_half;
   m02.base_half = st_half.band;
   m02.k_best = k_best;
   m02.kad = kad;

   % =====================================================================
   % M05  principal component projection of the day profile
   % =====================================================================
   fprintf("\n=== M05: principal component projection of the day profile ===\n");
   months = discover_months(data_dir);
   [td, yd] = read_vic1(data_dir, months);
   dkey = dateshift(td - minutes(5), "start", "day");
   [uk, ~, gk] = unique(dkey);
   n_per = accumarray(gk, 1);
   st_idx = [1; cumsum(n_per(1:end - 1)) + 1];
   dok = find(n_per == n_s);
   n_full = numel(dok);
   Yd = zeros(n_full, n_s);
   for i = 1:n_full
      k0 = dok(i);
      Yd(i, :) = yd(st_idx(k0):st_idx(k0) + n_s - 1)';
   end
   dday = uk(dok);
   fprintf("  settled series %s to %s, %d whole days of %d samples\n", ...
      string(dday(1)), string(dday(end)), n_full, n_s);

   cs = init_price_clamp(Yd(1:n_q, :));
   cl_day = nan(n_full, 2);
   cl_day(n_q + 1, :) = cs.q;
   for i = n_q + 1:n_full - 1
      cs = update_price_clamp(cs, Yd(i, :)');
      cl_day(i + 1, :) = cs.q;
   end
   Ycf = min(max(Yd, cl_day(:, 1)), cl_day(:, 2));
   % The same recursion over the whole history must agree with the short build.
   dd_c = 0;
   idx_day = zeros(n_day, 1);
   for dd = 1:n_day
      d0 = dateshift(t_test((dsc(dd) - 1) * n_s + 1) - minutes(5), "start", "day");
      i0 = find(dday == d0, 1);
      assert(~isempty(i0), "m05:day", "day %s is missing from the history", string(d0));
      idx_day(dd) = i0;
      dd_c = max(dd_c, max(abs(Ycf(i0, :) - Yg(dd, :))));
   end
   fprintf("  long clamp against the window clamp: max |diff| %.3g\n", dd_c);
   assert(dd_c < 1e-6, "m05:clamp", "the long clamp disagrees with the window clamp");

   kp = [1 2 4 6 8 10 12 16 20 24];
   np_ = numel(kp);
   kpmax = max(kp);
   n_hist = 180;
   mu_all = nan(n_day, n_s);
   V_all = cell(n_day, 1);
   Vs_all = cell(n_day, 1);
   ev_act = nan(n_day, kpmax);
   ev_own = nan(n_day, kpmax);
   for dd = 1:n_day
      i0 = idx_day(dd);
      h0 = i0 - 1;
      hi = max(1, h0 - n_hist + 1);
      assert(h0 - hi + 1 >= 120, "m05:hist", "only %d days of history on day %d", ...
         h0 - hi + 1, dd);
      X = Ycf(hi:h0, :);
      mu_all(dd, :) = mean(X, 1);
      Xc = X - mu_all(dd, :);
      [~, S, V] = svd(Xc, "econ");
      V_all{dd} = V(:, 1:kpmax);
      sv = diag(S) .^ 2;
      cv = cumsum(sv) / sum(sv);
      ev_act(dd, 1:kpmax) = cv(1:kpmax)';
      Xs = X - mean(X, 2);
      [~, ~, Vs] = svd(Xs, "econ");
      Vs_all{dd} = Vs(:, 1:kpmax);
      % the same question for our own forecast profiles of that day
      Xp = reshape(Yg(dd, :) - Ea(dd, :, :), n_s, n_c)';
      Xpc = Xp - mu_all(dd, :);
      [~, Sp, ~] = svd(Xpc, "econ");
      svp = diag(Sp) .^ 2;
      cvp = cumsum(svp) / sum(svp);
      ev_own(dd, 1:min(kpmax, numel(cvp))) = cvp(1:min(kpmax, numel(cvp)))';
   end
   fprintf("  the settled profile: median %d components reach 90%%, worst day %d\n", ...
      median_n(ev_act, 0.90), max_n(ev_act, 0.90));
   fprintf("  the settled profile: median %d components reach 95%%, worst day %d\n", ...
      median_n(ev_act, 0.95), max_n(ev_act, 0.95));
   fprintf("  our forecast profile: median %d reach 90%%, median %d reach 95%%\n", ...
      median_n(ev_own, 0.90), median_n(ev_own, 0.95));

   Efull = nan(n_day, n_s, n_c, np_);
   Eshap = nan(n_day, n_s, n_c, np_);
   Eorc = nan(n_day, n_s, np_);
   fprintf("  shapes: Ea %s, Yg %s, one slab cell %s, V %s, V shape %s\n", ...
      mat2str(size(Ea)), mat2str(size(Yg)), mat2str(size(Ea(1, :, 1))), ...
      mat2str(size(V_all{1})), mat2str(size(Vs_all{1})));
   n_skip = 0;
   for dd = 1:n_day
      Vf = V_all{dd};
      Vs = Vs_all{dd};
      mu = mu_all(dd, :)';
      y = Yg(dd, :)';
      for jj = 1:n_c
         pf = y(:) - reshape(Ea(dd, :, jj), n_s, 1);
         if any(~isfinite(pf))
            n_skip = n_skip + 1;
            continue;
         end
         cf = Vf' * (pf - mu);
         cy = Vf' * (y - mu);
         cs_ = Vs' * (pf - mean(pf));
         for ii = 1:np_
            kk = kp(ii);
            Efull(dd, :, jj, ii) = (y - (mu + Vf(:, 1:kk) * cf(1:kk)))';
            Eshap(dd, :, jj, ii) = (y - (mean(pf) + Vs(:, 1:kk) * cs_(1:kk)))';
            Eorc(dd, :, ii) = (y - (mu + Vf(:, 1:kk) * cy(1:kk)))';
         end
      end
   end
   fprintf("  profiles skipped for a missing cell: %d\n", n_skip);

   r_full = nan(np_, 1);
   r_shap = nan(np_, 1);
   r_orc = nan(np_, 1);
   r_full_1h = nan(np_, 1);
   r_shap_1h = nan(np_, 1);
   r_orc_1h = nan(np_, 1);
   st_full = cell(np_, 1);
   st_shap = cell(np_, 1);
   dm_full = nan(np_, 2);
   dm_shap = nan(np_, 2);
   orc_rms = nan(np_, 1);
   orc_slot = nan(np_, n_s);
   for ii = 1:np_
      Ef = Efull(:, :, :, ii);
      Es = Eshap(:, :, :, ii);
      Eo_ = repmat(Eorc(:, :, ii), 1, 1, n_c);
      r_full(ii) = band_ratio(Ef(:, :, ib), Eo(:, :, ib), n_b);
      r_shap(ii) = band_ratio(Es(:, :, ib), Eo(:, :, ib), n_b);
      r_orc(ii) = band_ratio(Eo_(:, :, ib), Eo(:, :, ib), n_b);
      r_full_1h(ii) = one_ratio(Ef, Eo, 1);
      r_shap_1h(ii) = one_ratio(Es, Eo, 1);
      r_orc_1h(ii) = one_ratio(Eo_, Eo, 1);
      st_full{ii} = cand_stats(Ef(:, :, ib), Eo(:, :, ib), n_b);
      st_shap{ii} = cand_stats(Es(:, :, ib), Eo(:, :, ib), n_b);
      [nb_, nw_] = dm_band(Ef(:, :, ib), Eo(:, :, ib));
      dm_full(ii, :) = [nb_, nw_];
      [nb_, nw_] = dm_band(Es(:, :, ib), Eo(:, :, ib));
      dm_shap(ii, :) = [nb_, nw_];
      v = Eorc(:, :, ii);
      orc_rms(ii) = sqrt(mean(v(isfinite(v)) .^ 2));
      orc_slot(ii, :) = reshape(sqrt(mean(v .^ 2, 1, "omitnan")), 1, n_s);
      fprintf("  k=%2d  whole %.4f (1 h %5.3f, 6 h %5.3f, 24 h %5.3f, win %5.2f%%, " + ...
         "RMS %6.3f, DM %d / %d)  shape %.4f (1 h %5.3f, RMS %6.3f)  ceiling %.4f, RMS %6.2f\n", ...
         kp(ii), r_full(ii), r_full_1h(ii), st_full{ii}.c6h, st_full{ii}.c24h, ...
         st_full{ii}.win, st_full{ii}.rms, dm_full(ii, 1), dm_full(ii, 2), r_shap(ii), ...
         r_shap_1h(ii), st_shap{ii}.rms, r_orc(ii), orc_rms(ii));
   end
   fprintf("  the ceiling is the error of the nearest point of the subspace, so no\n");
   fprintf("  forecast inside the subspace can score below it\n");

   % k is one choice out of ten, so it has to be made on one sample and scored on
   % the other. Two folds by target day, the same split as M02.
   lab5 = ["whole profile", "shape only"];
   r5_cross = nan(2, 1);
   k5_pick = nan(2, 2);
   st5_cross = cell(2, 1);
   dm5_cross = nan(2, 2);
   r5_cross_1h = nan(2, 1);
   E5 = cell(2, 1);
   for form = 1:2
      Ek = nan(n_day, n_s, n_c);
      for fold = 1:2
         if fold == 1
            fd = 1:half;  ed = half + 1:n_day;
         else
            fd = half + 1:n_day;  ed = 1:half;
         end
         best = inf;
         ibest = 1;
         for ii = 1:np_
            if form == 1
               Ef = Efull(fd, :, :, ii);
            else
               Ef = Eshap(fd, :, :, ii);
            end
            r = band_ratio(Ef(:, :, ib), Eo(fd, :, ib), n_b);
            if r < best
               best = r;
               ibest = ii;
            end
         end
         k5_pick(form, fold) = kp(ibest);
         if form == 1
            Ek(ed, :, :) = Efull(ed, :, :, ibest);
         else
            Ek(ed, :, :) = Eshap(ed, :, :, ibest);
         end
      end
      E5{form} = Ek;
      r5_cross(form) = band_ratio(Ek(:, :, ib), Eo(:, :, ib), n_b);
      r5_cross_1h(form) = one_ratio(Ek, Eo, 1);
      st5_cross{form} = cand_stats(Ek(:, :, ib), Eo(:, :, ib), n_b);
      [nb_, nw_] = dm_band(Ek(:, :, ib), Eo(:, :, ib));
      dm5_cross(form, :) = [nb_, nw_];
      fprintf("  %-14s k %s, cross fit band %.4f  1 h %5.3f  6 h %5.3f  24 h %5.3f" + ...
         "  win %5.2f%%  RMS %.3f  DM %d / %d\n", lab5(form), mat2str(k5_pick(form, :)), ...
         r5_cross(form), r5_cross_1h(form), st5_cross{form}.c6h, st5_cross{form}.c24h, ...
         st5_cross{form}.win, st5_cross{form}.rms, nb_, nw_);
   end

   % Day bootstrap on the paired difference: how large a gain has to be before it
   % is distinguishable from resampling noise.
   ik_full = find(r_full == min(r_full), 1);
   ik_shap = find(r_shap == min(r_shap), 1);
   cand = {Efull(:, :, :, ik_full), Eshap(:, :, :, ik_shap), E5{1}, E5{2}};
   lab_c = ["whole, k=" + string(kp(ik_full)), "shape, k=" + string(kp(ik_shap)), ...
      "whole, cross fit", "shape, cross fit"];
   r_c = [r_full(ik_full); r_shap(ik_shap); r5_cross];
   rng(11);
   B = 300;
   bt = nan(B, numel(cand) + 1);
   for b = 1:B
      idx = randi(n_day, n_day, 1);
      mB = median(reshape(sqrt(mean(Eo(idx, :, ib) .^ 2, 1, "omitnan")), n_s, n_b), 1, ...
         "omitnan");
      mR = median(reshape(sqrt(mean(Ea(idx, :, ib) .^ 2, 1, "omitnan")), n_s, n_b), 1, ...
         "omitnan");
      bt(b, 1) = median(mR ./ mB);
      for c = 1:numel(cand)
         E = cand{c};
         mC = median(reshape(sqrt(mean(E(idx, :, ib) .^ 2, 1, "omitnan")), n_s, n_b), 1, ...
            "omitnan");
         bt(b, 1 + c) = median(mC ./ mB);
      end
   end
   bt_gain = nan(numel(cand), 3);
   fprintf("  paired day bootstrap, %d draws\n", B);
   for c = 1:numel(cand)
      d = bt(:, 1 + c) - bt(:, 1);
      bt_gain(c, :) = [median(d), prctile(d, 5), prctile(d, 95)];
      fprintf("    %-18s ratio %.4f, gain %.2f%%, draw median %+.4f, 5 to 95 %+.4f to %+.4f," + ...
         " better in %.0f%% of draws\n", lab_c(c), r_c(c), 100 * (1 - r_c(c) / r_base), ...
         median(d), prctile(d, 5), prctile(d, 95), 100 * mean(d < 0));
   end

   % Where the gain comes from: the count of target days the candidate improves,
   % and the ratio lead by lead, which is what decides where to switch it on.
   d_base = nan(n_day, 1);
   d_shap = nan(n_day, 1);
   for dd = 1:n_day
      d_base(dd) = band_ratio(Ea(dd, :, ib), Eo(dd, :, ib), n_b);
      d_shap(dd) = band_ratio(Eshap(dd, :, ib, ik_shap), Eo(dd, :, ib), n_b);
   end
   fprintf("  the shape projection is better on %d of %d target days, median day gain %.2f%%\n", ...
      nnz(d_shap < d_base), n_day, 100 * median(1 - d_shap ./ d_base));
   fprintf("  effective dimension: the settled profile needs %d, our forecast needs %d\n", ...
      median_n(ev_act, 0.95), median_n(ev_own, 0.95));
   r_lead_base = nan(n_c, 1);
   r_lead_shap = nan(n_c, 1);
   r_lead_whole = nan(n_c, 1);
   for jj = 1:n_c
      r_lead_base(jj) = cc_ratio(Ea(:, :, jj), Eo(:, :, jj));
      r_lead_shap(jj) = cc_ratio(Eshap(:, :, jj, ik_shap), Eo(:, :, jj));
      r_lead_whole(jj) = cc_ratio(Efull(:, :, jj, ik_full), Eo(:, :, jj));
   end
   fprintf("  per lead, ratio of column medians: baseline, shape k=%d, whole k=%d\n", ...
      kp(ik_shap), kp(ik_full));
   for jj = 1:n_c
      fprintf("    %6.2f h  %7.4f  %7.4f  %7.4f\n", lead_c(jj) / 60, r_lead_base(jj), ...
         r_lead_shap(jj), r_lead_whole(jj));
   end

   m05 = struct();
   m05.kp = kp;
   m05.n_hist = n_hist;
   m05.base_ratio = r_base;
   m05.ratio_full = r_full;
   m05.ratio_shap = r_shap;
   m05.ratio_orc = r_orc;
   m05.ratio_full_1h = r_full_1h;
   m05.ratio_shap_1h = r_shap_1h;
   m05.ratio_orc_1h = r_orc_1h;
   m05.st_full = st_full;
   m05.st_shap = st_shap;
   m05.dm_full = dm_full;
   m05.dm_shap = dm_shap;
   m05.orc_rms = orc_rms;
   m05.orc_slot = orc_slot;
   m05.ev_act = mean(ev_act, 1, "omitnan");
   m05.ev_own = mean(ev_own, 1, "omitnan");
   m05.n_skip = n_skip;
   m05.cross = struct();
   m05.cross.label = lab5;
   m05.cross.ratio = r5_cross;
   m05.cross.ratio_1h = r5_cross_1h;
   m05.cross.k_pick = k5_pick;
   m05.cross.win = [st5_cross{1}.win, st5_cross{2}.win];
   m05.cross.dm = dm5_cross;
   m05.boot = struct();
   m05.boot.label = lab_c;
   m05.boot.ratio = r_c;
   m05.boot.gain_median = bt_gain(:, 1);
   m05.boot.gain_lo = bt_gain(:, 2);
   m05.boot.gain_hi = bt_gain(:, 3);
   m05.boot.draws = B;
   m05.k_fixed_best = [kp(ik_full), kp(ik_shap)];
   m05.day_gain = 100 * (1 - d_shap ./ d_base);
   m05.lead_min = lead_c;
   m05.ratio_lead_base = r_lead_base;
   m05.ratio_lead_shap = r_lead_shap;
   m05.ratio_lead_whole = r_lead_whole;

   % =====================================================================
   % Write
   % =====================================================================
   out = struct();
   out.band_lead_min = lead_b;
   out.notes = "the 1 h column is carried alongside the band, band ratios use the 37 band columns";
   out.baseline = struct();
   out.baseline.ratio = r_base;
   out.baseline.ratio_1h = r_base_1h;
   out.baseline.st = st_start;
   out.baseline.dm = [nb_s, nw_s];
   out.m01 = struct();
   out.m01.ratio = r_m01;
   out.m01.ratio_1h = r_m01_1h;
   out.m01.st = st_m01;
   out.m01.dm = [nb_1, nw_1];
   out.m02 = m02;
   out.m05 = m05;
   txt = jsonencode(out);
   f = fullfile(out_dir, tag + ".json");
   fid = fopen(f, "w");
   fwrite(fid, txt, "char");
   fclose(fid);
   fprintf("\nwrote %s (%d bytes)\n", f, numel(txt));

   plot_m02(out_dir, lead_b, names, m02, r_base, r_m01);
   plot_m05(out_dir, m05, Ea, Eo, Yg, Eshap);
   fprintf("wrote two figures\n");
end

% =========================================================================
function n = median_n(ev, q)
   v = nan(size(ev, 1), 1);
   for i = 1:size(ev, 1)
      j = find(ev(i, :) >= q, 1);
      if ~isempty(j)
         v(i) = j;
      end
   end
   n = median(v, "omitnan");
end

% =========================================================================
function n = max_n(ev, q)
   v = nan(size(ev, 1), 1);
   for i = 1:size(ev, 1)
      j = find(ev(i, :) >= q, 1);
      if ~isempty(j)
         v(i) = j;
      end
   end
   n = max(v, [], "omitnan");
end

% =========================================================================
function months = discover_months(data_dir)
   dd_ = dir(fullfile(data_dir, "PRICE_AND_DEMAND_*_VIC1.csv"));
   months = strings(0, 1);
   for i = 1:numel(dd_)
      tok = regexp(dd_(i).name, "PRICE_AND_DEMAND_(\d{6})_VIC1\.csv", "tokens", "once");
      if ~isempty(tok)
         months(end + 1, 1) = string(tok{1});
      end
   end
   months = sort(unique(months));
end

% =========================================================================
function [tp, yp] = read_vic1(data_dir, months)
   T = strings(0, 1);
   V = zeros(0, 1);
   % Indexed, not `for m = months`: a for loop walks the columns of an array, so a
   % column of month strings would be one iteration holding all of them.
   for i = 1:numel(months)
      p = fullfile(data_dir, "PRICE_AND_DEMAND_" + months(i) + "_VIC1.csv");
      assert(isfile(p), "m02:file", "cannot find %s", p);
      fid = fopen(p, "r");
      assert(fid > 0, "m02:file", "cannot open %s", p);
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
function R = column_median_R(E, n_s, n_c)
   % Median over slots of the per-column RMS, one row per model.
   n_m = size(E, 4);
   R = nan(n_m, n_c);
   for i = 1:n_m
      if n_m == 1
         e = E;
      else
         e = E(:, :, :, i);
      end
      v = sqrt(mean(e .^ 2, 1, "omitnan"));
      R(i, :) = reshape(median(reshape(v, n_s, n_c), 1, "omitnan"), 1, n_c);
   end
end

% =========================================================================
function Ek = blend_topk(E4b, ord, ed, n_s, n_c, ksel)
   % Equal weight over the first k models of each column, scored on the rows ed.
   n_m = size(E4b, 4);
   ne = numel(ed);
   Ek = nan(ne, n_s, n_c);
   for jj = 1:n_c
      if isscalar(ksel)
         kk = min(ksel, n_m);
      else
         kk = min(ksel(jj), n_m);
      end
      sel = ord(1:kk, jj);
      x = mean(E4b(ed, :, jj, sel), 4, "omitnan");
      Ek(:, :, jj) = reshape(x, ne, n_s);
   end
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
   st.rms = sqrt(mean(EA(ok) .^ 2));
   st.q90 = prctile(abs(EA(ok)), 90);
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
function r = cc_ratio(ec, eo)
   % Ratio of column medians for one column of two error slabs.
   r = median(sqrt(mean(ec .^ 2, 1, "omitnan")), "omitnan") / ...
      median(sqrt(mean(eo .^ 2, 1, "omitnan")), "omitnan");
end

% =========================================================================
function r = one_ratio(EA, EB, jj)
   RA = sqrt(mean(EA(:, :, jj) .^ 2, 1, "omitnan"));
   RB = sqrt(mean(EB(:, :, jj) .^ 2, 1, "omitnan"));
   r = median(RA, "omitnan") / median(RB, "omitnan");
end

% =========================================================================
function [n_better, n_worse] = dm_band(Ecand, Eoff)
   % dm_cells clusters over the last axis, so the day has to be last and the
   % baseline first. Both slabs here arrive as [target day, target slot, column].
   [n_better, n_worse] = dm_cells(permute(Eoff, [2 3 1]), permute(Ecand, [2 3 1]));
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
function plot_m02(out_dir, lead_b, names, m02, r_base, r_m01)
   f = figure("Visible", "off", "Position", [60 40 1560 1020]);
   col = [0.12 0.31 0.47; 0.75 0.10 0.10];
   n_m = numel(names);
   [~, ordp] = sort(median(m02.Rcol, 2, "omitnan"), "ascend");
   [~, pos] = ismember(m02.winner, ordp);
   i_anc = find(ordp == find(names == "Anchor-mix", 1), 1);

   subplot(2, 2, 1);
   rel = m02.Rcol(ordp, :) ./ min(m02.Rcol(ordp, :), [], 1);
   imagesc(lead_b / 60, 1:n_m, rel);
   set(gca, "YDir", "reverse");
   hold on;
   plot(lead_b / 60, pos, "wo", "MarkerSize", 4, "MarkerFaceColor", "w");
   hold off;
   cb = colorbar;
   cb.Label.String = "column median R relative to the column winner";
   set(gca, "YTick", 1:n_m, "YTickLabel", names(ordp), "FontSize", 7);
   xlabel("lead, hours");
   title("a. every model relative to the column winner, dot marks the winner", ...
      "FontSize", 11);

   subplot(2, 2, 2);
   stairs(lead_b / 60, pos, "-", "Color", col(1, :), "LineWidth", 1.8);
   hold on;
   plot([6 24], [i_anc i_anc], "k--", "LineWidth", 1.0);
   hold off;  grid on;
   set(gca, "YDir", "reverse", "YTick", 1:n_m, "YTickLabel", names(ordp), "FontSize", 7);
   ylim([0.5 n_m + 0.5]);
   xlabel("lead, hours");
   title(sprintf("b. the in-sample winner, %d distinct models", numel(unique(m02.winner))), ...
      "FontSize", 11);

   subplot(2, 2, 3);
   hold on;
   plot(m02.k_list, m02.ratio_cross, "-o", "Color", col(1, :), "LineWidth", 1.8, ...
      "MarkerSize", 4);
   plot(m02.k_list, m02.ratio_orc, "-^", "Color", col(2, :), "LineWidth", 1.6, ...
      "MarkerSize", 4);
   plot([0.6 16.4], [1 1] * r_m01, "k--", "LineWidth", 1.0);
   plot([0.6 16.4], [1 1] * r_m01 * 0.98, "k:", "LineWidth", 1.2);
   plot([0.6 16.4], [1 1] * r_base, "k-", "LineWidth", 1.0);
   hold off;  grid on;
   set(gca, "XScale", "log", "XTick", m02.k_list);
   xlabel("k, models kept in each column");  ylabel("band ratio, lower is better");
   title("c. selection out of sample, and the in-sample ceiling", "FontSize", 11);
   legend({"cross fit, 32 days", "in-sample ceiling", "M01", "M01 minus 2%", ...
      "Anchor-mix"}, "Location", "northwest", "Box", "off", "FontSize", 8);

   subplot(2, 2, 4);
   kb = m02.k_list == m02.k_best;
   bars = [r_base, r_m01, m02.ratio_cross(kb), m02.ratio_kad, m02.ratio_orc(kb), ...
      m02.ratio_strict(kb)];
   bar(bars, 0.55, "FaceColor", [0.45 0.55 0.65]);
   hold on;
   plot([0.4 5.6], [1 1] * r_base, "k--", "LineWidth", 1.0);
   plot([5.4 6.6], [1 1] * m02.base_half, "k:", "LineWidth", 1.2);
   for i = 1:numel(bars)
      text(i, bars(i) + 0.0015, sprintf("%.4f", bars(i)), "HorizontalAlignment", ...
         "center", "FontSize", 8, "Rotation", 90);
   end
   hold off;  grid on;
   set(gca, "XTick", 1:6, "XTickLabel", {"Anchor-mix", "M01", "cross fit", ...
      "k per column", "in-sample", "16 days"});
   ylim([min(bars) - 0.02, max(bars) + 0.02]);
   ylabel("band ratio, lower is better");
   title(sprintf("d. what it is worth at k=%d, dotted line is the 16 day base %.4f", ...
      m02.k_best, m02.base_half), "FontSize", 9);

   sgtitle("M02: pick the winners of each column", "FontSize", 12);
   exportgraphics(f, fullfile(out_dir, "fig_m02.png"), "Resolution", 140);
   close(f);
end

% =========================================================================
function plot_m05(out_dir, m05, Ea, Eo, Yg, Eshap)
   f = figure("Visible", "off", "Position", [60 40 1560 1020]);
   col = [0.12 0.31 0.47; 0.75 0.10 0.10];
   n_s = size(Ea, 2);
   n_c = size(Ea, 3);

   subplot(2, 2, 1);
   kk = 1:numel(m05.ev_act);
   hold on;
   plot(kk, m05.ev_act * 100, "-o", "Color", col(1, :), "LineWidth", 1.7, "MarkerSize", 3);
   plot(kk, m05.ev_own * 100, "-s", "Color", [0.95 0.55 0.10], "LineWidth", 1.7, ...
      "MarkerSize", 3);
   plot([1 numel(kk)], [95 95], "k:", "LineWidth", 1.1);
   hold off;  grid on;
   xlabel("components kept");  ylabel("variance explained, %");
   title("a. how many components a day profile really needs", "FontSize", 11);
   legend({"the settled profile", "our forecast profile"}, "Location", "southeast", ...
      "Box", "off", "FontSize", 8);

   subplot(2, 2, 2);
   hold on;
   plot(m05.kp, m05.ratio_full, "-o", "Color", col(1, :), "LineWidth", 1.8, "MarkerSize", 4);
   plot(m05.kp, m05.ratio_shap, "-s", "Color", [0.95 0.55 0.10], "LineWidth", 1.6, ...
      "MarkerSize", 4);
   plot([1 24], [1 1] * m05.cross.ratio(1), "-.", "Color", col(1, :), "LineWidth", 1.1);
   plot([1 24], [1 1] * m05.cross.ratio(2), "-.", "Color", [0.95 0.55 0.10], ...
      "LineWidth", 1.1);
   plot(m05.kp, m05.ratio_orc, "-^", "Color", col(2, :), "LineWidth", 1.6, "MarkerSize", 4);
   plot([1 24], [1 1] * m05.base_ratio, "k--", "LineWidth", 1.0);
   hold off;  grid on;
   set(gca, "XTick", m05.kp, "YScale", "log");
   ylim([0.28 1.45]);
   xlabel("components kept");  ylabel("band ratio, log scale, lower is better");
   title("b. projecting our profile, and the floor a projection cannot pass", "FontSize", 10);
   legend({"whole profile", "shape only", "whole, k out of sample", ...
      "shape, k out of sample", "settled, best possible", "as measured"}, ...
      "Location", "southwest", "Box", "off", "FontSize", 7);

   subplot(2, 2, 3);
   lb = m05.lead_min / 60;
   hold on;
   plot(lb, m05.ratio_lead_base, "-", "Color", [0.15 0.15 0.15], "LineWidth", 1.8);
   plot(lb, m05.ratio_lead_shap, "-o", "Color", [0.95 0.55 0.10], "LineWidth", 1.6, ...
      "MarkerSize", 3);
   plot(lb, m05.ratio_lead_whole, "-s", "Color", col(1, :), "LineWidth", 1.3, ...
      "MarkerSize", 3);
   plot([6 6], [0.8 1.6], "k:", "LineWidth", 1.1);
   hold off;  grid on;
   ylim([0.8 1.6]);
   xlabel("lead, hours");  ylabel("ratio of column medians, lower is better");
   title("c. where the projection helps, dotted line is the band edge", "FontSize", 11);
   legend({"as measured", "shape, 2 components", "whole, 10 components"}, ...
      "Location", "southeast", "Box", "off", "FontSize", 8);

   subplot(2, 2, 4);
   dd = 23;
   jj = 22;
   y = Yg(dd, :);
   pf = y - reshape(Ea(dd, :, jj), 1, n_s);
   pj = y - reshape(Eshap(dd, :, jj, m05.k_fixed_best(2)), 1, n_s);
   hold on;
   plot(1:n_s, y, "-", "Color", [0.15 0.15 0.15], "LineWidth", 1.8);
   plot(1:n_s, pf, "-", "Color", col(1, :), "LineWidth", 1.0);
   plot(1:n_s, pj, "-", "Color", [0.95 0.55 0.10], "LineWidth", 1.3);
   hold off;  grid on;
   xlabel("slot of the target day, 5 minutes each");  ylabel("$/MWh");
   title(sprintf("d. one target day at %.1f h, and the 2 component shape", ...
      m05.lead_min(jj) / 60), "FontSize", 11);
   legend({"settled", "our forecast", "its 2 component shape"}, "Location", ...
      "northwest", "Box", "off", "FontSize", 8);

   sgtitle("M05: project the day profile on a few components", "FontSize", 12);
   exportgraphics(f, fullfile(out_dir, "fig_m05.png"), "Resolution", 140);
   close(f);
end
