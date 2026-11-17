function diagnose_official_gap()
   % DIAGNOSE_OFFICIAL_GAP  Where the official composite beats the bench, and why.
   %
   % Writes Weekly/2026-10-13/deck/diagnose_official_gap.json. Three measurements,
   % each on one of the four admissible objects:
   %
   %   profile   the median of R over the 288 times of day, column by column, for
   %             the official composite and for each of the sixteen models. This is
   %             a fixed-lead profile: the object that says where on the lead axis
   %             the ordering changes hands.
   %   census    per column, how many of the 288 times of day each candidate wins,
   %             with the official and the sixteen models competing together.
   %   ahead     how far ahead of the price each forecast is, measured as the shift
   %             of its five-minute change that lines it up best with the official
   %             one-step forecast. The official one-step forecast is the best
   %             available stand-in for the price that is about to print: it has a
   %             median absolute error under 10 $/MWh against the revealed price.
   %             A positive shift means the forecast has to be moved FORWARD to
   %             match, so it is that many steps behind; a negative shift means it
   %             moves before the price does.
   %
   % Why not measure against the actual: the composite is scored on the CLAMPED
   % price and neither cube stores that series on its own, so a lag against it would
   % need a reconstruction with the clamp inside it. The one-step forecast carries
   % the same timing information without the reconstruction.
   %
   % Run: runs\run_diagnose_gap.bat <new log name>

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   out_json = fullfile(root, "Weekly", "2026-10-13", "deck", ...
      "diagnose_official_gap.json");
   addpath(genpath(fullfile(root, "Predicitor")));

   A = load(fullfile(fig_dir, "atlas_60d.mat"), "E4", "keys", "names", "d_score");
   O = load(fullfile(fig_dir, "official_60d.mat"), ...
      "R_off", "O4", "E4_off", "d_score", "lead_min");
   [lead_min, ~, ~] = official_lead_axis();
   n_s = size(A.E4, 1); n_h = size(A.E4, 2); n_d = size(A.E4, 3);
   d_score = double(A.d_score);
   n_day = numel(d_score);
   n_m = numel(A.keys);
   assert(numel(lead_min) == n_h, "axis %d vs %d columns", numel(lead_min), n_h);
   assert(isequal(double(O.d_score), d_score), "the two files score different days");
   fprintf("atlas %d x %d x %d, scored days %d, models %d\n", ...
      n_s, n_h, n_d, n_day, n_m);

   % ---------------------------------------------------------------- profile
   R = zeros(n_s, n_h, n_m);
   for m = 1:n_m
      R(:, :, m) = sqrt(mean(double(A.E4(:, :, d_score, m)).^2, 3));
   end
   R_off = double(O.R_off);
   has_off = isfinite(R_off);
   fprintf("comparable cells %d of %d (%.2f%%)\n", sum(has_off(:)), n_s * n_h, ...
      100 * sum(has_off(:)) / (n_s * n_h));
   prof_off = median(R_off, 1, "omitnan");
   prof_mod = zeros(n_m, n_h);
   for m = 1:n_m
      prof_mod(m, :) = median(R(:, :, m), 1, "omitnan");
   end
   band = find(lead_min >= 360 & lead_min <= 1440);
   band_med = zeros(n_m, 1);
   for m = 1:n_m
      band_med(m) = median(reshape(R(:, band, m), [], 1), "omitnan");
   end
   [~, mb] = min(band_med);
   fprintf("best model over the 6 to 24 h band: %s at %.3f, official %.3f\n", ...
      A.names(mb), band_med(mb), median(prof_off(band)));

   % ----------------------------------------------------------------- census
   best = R_off;
   for m = 1:n_m
      cand = R(:, :, m);
      take = cand < best;
      best(take) = cand(take);
   end
   wins_off = zeros(1, n_h);
   wins_mod = zeros(n_m, n_h);
   for c = 1:n_h
      wins_off(c) = sum(isfinite(R_off(:, c)) & R_off(:, c) <= best(:, c));
      for m = 1:n_m
         v = R(:, c, m);
         wins_mod(m, c) = sum(isfinite(v) & v <= best(:, c));
      end
   end
   fprintf("census with the official present: official %d cells of %d comparable\n", ...
      sum(wins_off), sum(has_off(:)));

   % ------------------------------------------------------------------ ahead
   %
   % The reference is the official forecast at the first column, which names the
   % interval that is one five-minute step away. Both sides are differenced first,
   % so the level cancels and only the timing is left.
   shifts = -6:6;
   names = [{"Official AEMO composite"}; cellstr(A.names(:))];
   ahead = NaN(numel(names), n_h);
   for a = 1:numel(names)
      for c = 1:n_h
         if a == 1
            F = double(O.O4(:, c, d_score));
         else
            % the model forecast at day k is the revealed price minus the model
            % error, and the revealed price is O4 plus the official error
            F = double(O.O4(:, c, d_score)) ...
               + double(O.E4_off(:, c, d_score)) ...
               - double(A.E4(:, c, d_score, a - 1));
         end
         ref = double(O.O4(:, 1, d_score));
         if c == 1 && a == 1
            ahead(a, c) = 0;
            continue;
         end
         df = diff(F, 1, 1);
         dr = diff(ref, 1, 1);
         bestr = -Inf; bestk = NaN;
         for k = shifts
            if k >= 0
               x = dr(1:(end - k), :);
               z = df((1 + k):end, :);
            else
               x = dr((1 - k):end, :);
               z = df(1:(end + k), :);
            end
            ok = isfinite(x) & isfinite(z);
            if sum(ok(:)) < 500, continue; end
            r = corr(x(ok), z(ok));
            if r > bestr, bestr = r; bestk = k; end
         end
         ahead(a, c) = bestk;
      end
      fprintf("  %-26s steps ahead of the one-step forecast: median %+.2f, mean %+.2f\n", ...
         names{a}, median(ahead(a, :), "omitnan"), mean(ahead(a, :), "omitnan"));
   end

   % ------------------------------------------------------------------ bands
   edges_min = [5 60 360 1440 4320 10980];
   edges_lab = {"5 min", "1 h", "6 h", "24 h", "3 d", "7.6 d"};
   bands = {};
   for b = 1:(numel(edges_min) - 1)
      idx = find(lead_min > edges_min(b) & lead_min <= edges_min(b + 1));
      if isempty(idx), continue; end
      share = 100 * sum(wins_off(idx)) / (numel(idx) * n_s);
      bands{end + 1} = struct("label", edges_lab{b + 1}, ...
         "from_col", idx(1), "to_col", idx(end), ...
         "from_min", lead_min(idx(1)), "to_min", lead_min(idx(end)), ...
         "official_share_pct", share); %#ok<AGROW>
      fprintf("  band %-6s columns %3d to %3d (%.2f to %.2f h): official wins %5.1f%%\n", ...
         edges_lab{b + 1}, idx(1), idx(end), lead_min(idx(1)) / 60, ...
         lead_min(idx(end)) / 60, share);
   end

   out = struct();
   out.scored_days = n_day;
   out.n_slot = n_s;
   out.lead_min = lead_min(:)';
   out.official_profile = prof_off;
   out.model_profile = prof_mod;
   out.model_keys = cellstr(A.keys(:)');
   out.model_names = cellstr(A.names(:)');
   out.wins_official = wins_off;
   out.wins_model = wins_mod;
   out.bands = bands;
   out.band_6_24h = band(:)';
   out.band_median_official = median(prof_off(band));
   out.band_median_model = band_med(:)';
   out.best_band_model = A.names(mb);
   out.ahead_names = names;
   out.ahead_median_steps = median(ahead, 2, "omitnan")';
   out.ahead_mean_steps = mean(ahead, 2, "omitnan")';
   out.ahead_by_column = ahead;
   out.ahead_shifts = shifts;

   fid = fopen(out_json, "w");
   fprintf(fid, "%s", jsonencode(out));
   fclose(fid);
   fprintf("wrote %s\n", out_json);
end
