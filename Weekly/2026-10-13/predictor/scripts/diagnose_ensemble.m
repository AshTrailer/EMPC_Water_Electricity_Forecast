function diagnose_ensemble()
   % DIAGNOSE_ENSEMBLE  Two measurements, both on the cubes that already exist.
   %
   % ensemble  The error of an equal-weight average of predictors is the average of
   %           their error cubes, because the average forecast is the price minus the
   %           average error. So the equal-weight ensemble needs no re-run and no new
   %           model, only mean(E4, 4). The width of the average is what matters here:
   %           picking the best model per cell does not shrink variance, averaging
   %           does, and at 6 to 24 h the pool has almost no skill to lose.
   %
   % revision  For a fixed target the error at lead h is the sum of the revisions made
   %           on the way in. With r(h) = e(h-1) - e(h) and e(0) = 0,
   %              MSE(h) - MSE(h-1) = mean(r(h)^2) + 2 mean(e(h-1) r(h)).
   %           The first term is how far the forecast moves, the second is whether the
   %           move is toward the price. A predictor that stops moving has a first term
   %           near zero. A predictor that keeps moving with the second term near zero
   %           is adding noise.
   %
   % Writes Weekly/2026-10-13/deck/diagnose_ensemble.json. Reads both cubes through
   % matfile one model slice at a time, because a full load of E4 is 830 MB.
   %
   % Run: runs\run_diagnose_ensemble.bat <new log name>

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   out_json = fullfile(root, "Weekly", "2026-10-13", "deck", "diagnose_ensemble.json");
   addpath(genpath(fullfile(root, "Predicitor")));

   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   fprintf("opened both cubes\n");

   n_s = 288;
   n_h = 376;
   d_score = double(A.d_score);
   d_score = d_score(:)';
   n_day = numel(d_score);
   names = string(A.names);
   n_m = numel(names);
   lead_min = official_lead_axis();
   lead_min = lead_min(:)';
   assert(numel(lead_min) == n_h, "axis %d vs %d columns", numel(lead_min), n_h);
   fprintf("scored days %d, models %d\n", n_day, n_m);

   dyn_names = ["T28 + AR4", "Carry-forward", "T28 + DMS4", "CF + DMS4", ...
      "Anchor-mix", "MW + level (run state)", "Kalman harmonic SS", ...
      "T28 + AR(n per cell)"];
   is_dyn = ismember(names, dyn_names);
   fprintf("dynamic models %d of %d: %s\n", sum(is_dyn), n_m, ...
      strjoin(names(is_dyn), " | "));

   c_1h = find(lead_min == 60, 1);
   c_24h = find(lead_min == 1440, 1);

   % ------------------------------------------------------------ model slices
   Esum = zeros(n_s, n_h, n_day);
   Esum_dyn = zeros(n_s, n_h, n_day);
   mse = zeros(n_m, n_h);
   inc = zeros(n_m, n_h);
   rv = zeros(n_m, n_h);
   E24 = zeros(n_s, n_day, n_m);
   prof_mod = zeros(n_m, n_h);
   for m = 1:n_m
      Em = double(A.E4(1:n_s, 1:n_h, d_score, m));
      Esum = Esum + Em;
      if is_dyn(m)
         Esum_dyn = Esum_dyn + Em;
      end
      [mse(m, :), inc(m, :), rv(m, :)] = spectrum(Em);
      prof_mod(m, :) = median(sqrt(mean(Em .^ 2, 3, "omitnan")), 1, "omitnan");
      E24(:, :, m) = reshape(Em(:, c_24h, :), n_s, n_day);
      fprintf("  %2d %-24s pooled 1h %7.3f  24h %7.3f\n", m, names(m), ...
         sqrt(mse(m, c_1h)), sqrt(mse(m, c_24h)));
      clear Em
   end

   Eens = Esum / n_m;
   Eens_dyn = Esum_dyn / sum(is_dyn);
   [mse_ens, inc_ens, rv_ens] = spectrum(Eens);
   [mse_dyn, inc_dyn, rv_dyn] = spectrum(Eens_dyn);

   % --------------------------------------------------------- official slices
   Eo = double(O.E4_off(1:n_s, 1:n_h, d_score));
   [mse_off, inc_off, rv_off] = spectrum(Eo);
   R_off = double(O.R_off);

   % -------------------------------------------------------------- profiles
   R_ens = sqrt(mean(Eens .^ 2, 3));
   R_dyn = sqrt(mean(Eens_dyn .^ 2, 3));
   prof_ens = median(R_ens, 1, "omitnan");
   prof_dyn = median(R_dyn, 1, "omitnan");
   prof_off = median(R_off, 1, "omitnan");
   win_ens = sum(R_ens <= R_off, 1);
   win_dyn = sum(R_dyn <= R_off, 1);

   band = find(lead_min >= 360 & lead_min <= 1440);
   fprintf("\nband %d columns, %.1f to %.1f h\n", numel(band), ...
      lead_min(band(1)) / 60, lead_min(band(end)) / 60);
   bm_off = median(reshape(R_off(:, band), [], 1), "omitnan");
   bm_ens = median(reshape(R_ens(:, band), [], 1), "omitnan");
   bm_dyn = median(reshape(R_dyn(:, band), [], 1), "omitnan");
   fprintf("band median: official %.3f  ensemble %.3f  dynamic %.3f\n", ...
      bm_off, bm_ens, bm_dyn);
   for c = [c_1h, c_24h]
      fprintf("col %3d %6.1f h: official %.3f  ensemble %.3f  dynamic %.3f\n", ...
         c, lead_min(c) / 60, prof_off(c), prof_ens(c), prof_dyn(c));
   end

   % ------------------------------------------------- error correlation at 24 h
   X = reshape(E24, n_s * n_day, n_m);
   X = X - mean(X, 1);
   C = corrcoef(X);
   off_diag = C(~eye(n_m, "logical"));
   corr_med = median(off_diag);
   corr_min = min(off_diag);
   corr_max = max(off_diag);
   fprintf("error correlation at 24 h: median %.3f  min %.3f  max %.3f\n", ...
      corr_med, corr_min, corr_max);

   % -------------------------------------- band error split by day and by slot
   Eb = Eens(:, band, :);
   ct_day_ens = reshape(mean(mean(Eb .^ 2, 1), 2), 1, n_day);
   ct_slot_ens = reshape(mean(mean(Eb .^ 2, 2), 3), 1, n_s);
   Eb_o = Eo(:, band, :);
   ct_day_off = reshape(mean(mean(Eb_o .^ 2, 1, "omitnan"), 2, "omitnan"), 1, n_day);
   ct_slot_off = reshape(mean(mean(Eb_o .^ 2, 2, "omitnan"), 3, "omitnan"), 1, n_s);

   [srt, ord] = sort(ct_day_ens, "descend");
   top3 = srt(1:3) / sum(srt);
   fprintf("band error, top 3 days share %.3f %.3f %.3f (total %.3f)\n", ...
      top3(1), top3(2), top3(3), sum(top3));
   keep = setdiff(1:n_day, ord(1:3));
   fprintf("band median without the 3 worst days: ensemble %.3f  official %.3f\n", ...
      median(reshape(sqrt(mean(Eens(:, band, keep) .^ 2, 3)), [], 1), "omitnan"), ...
      median(reshape(R_off(:, band), [], 1), "omitnan"));

   % ------------------------------------------------------------ revision share
   c_6h = find(lead_min == 360, 1);
   fprintf("share of MSE(24 h) accumulated up to 6 h: ensemble %.3f official %.3f\n", ...
      sum(inc_ens(1:c_6h)) / mse_ens(c_24h), sum(inc_off(1:c_6h)) / mse_off(c_24h));
   fprintf("share accumulated between 6 and 24 h: ensemble %.3f official %.3f\n", ...
      sum(inc_ens(c_6h + 1:c_24h)) / mse_ens(c_24h), ...
      sum(inc_off(c_6h + 1:c_24h)) / mse_off(c_24h));
   fprintf("revision variance between 6 and 24 h: ensemble %.3f official %.3f\n", ...
      mean(rv_ens(c_6h + 1:c_24h)), mean(rv_off(c_6h + 1:c_24h)));

   % ------------------------------------------------------------------- write
   out = struct();
   out.lead_min = lead_min;
   out.names = names;
   out.d_score = d_score;
   out.band = band;
   out.profile_ens = prof_ens;
   out.profile_dyn = prof_dyn;
   out.profile_off = prof_off;
   out.profile_models = prof_mod;
   out.win_ens = win_ens;
   out.win_dyn = win_dyn;
   out.band_med = [bm_off, bm_ens, bm_dyn];
   out.mse = mse;
   out.inc = inc;
   out.rev2 = rv;
   out.mse_ens = mse_ens;
   out.inc_ens = inc_ens;
   out.rev2_ens = rv_ens;
   out.mse_dyn = mse_dyn;
   out.mse_off = mse_off;
   out.inc_off = inc_off;
   out.rev2_off = rv_off;
   out.corr24 = [corr_med, corr_min, corr_max];
   out.contrib_day_ens = ct_day_ens;
   out.contrib_day_off = ct_day_off;
   out.contrib_slot_ens = ct_slot_ens;
   out.contrib_slot_off = ct_slot_off;
   out.top3_days = ord(1:3);
   out.top3_share = top3;
   txt = jsonencode(out);
   fid = fopen(out_json, "w");
   fwrite(fid, txt, "char");
   fclose(fid);
   fprintf("\nwrote %s (%d bytes)\n", out_json, numel(txt));
end


function [ms, inc, rv] = spectrum(E)
   % Per-column pooled MSE, its increment, and the revision variance that drives it.
   [n_s, n_h, n_d] = size(E);
   ms = zeros(1, n_h);
   inc = zeros(1, n_h);
   rv = zeros(1, n_h);
   prev = zeros(n_s, 1, n_d);
   for h = 1:n_h
      cur = reshape(E(:, h, :), n_s, 1, n_d);
      r = prev - cur;
      ms(h) = mean(cur(:) .^ 2, "omitnan");
      rv(h) = mean(r(:) .^ 2, "omitnan");
      if h == 1
         inc(h) = ms(h);
      else
         inc(h) = ms(h) - ms(h - 1);
      end
      prev = cur;
   end
end
