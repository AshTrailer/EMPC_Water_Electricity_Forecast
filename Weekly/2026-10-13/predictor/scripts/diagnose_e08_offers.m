function diagnose_e08_offers(src)
   % DIAGNOSE_E08_OFFERS  Does the offer stack carry band information the anchor lacks?
   %
   % N23 settled that the stack cannot be read as a price: the regional price is
   % set at the interconnector, so reading the curve at regional demand lands
   % hundreds of dollars away. What survives is the quantity side, which does not
   % depend on where demand sits on the curve. Three such quantities are tested
   % here, each as a gate on the 6 to 24 hour band error.
   %
   %   A  capacity offered at or below 100 $/MWh at the origin, for the target
   %   B  the same quantity minus its value 24 hours earlier, so a withdrawal of
   %      cheap capacity for that target enters as a negative regressor
   %   C  steepness near the money, the MW added between 50 and 200 $/MWh
   %
   % The gate is the one used for E01: within a target day and column, remove the
   % level across the 288 slots, regress the band error on the regressor, read the
   % partial R squared and a day-clustered t. Below 1 per cent the channel goes.
   %
   % Spike capture is the second criterion E08 registered. A spike is a band cell
   % whose actual price is at or above 300 $/MWh. For each regressor the tightest
   % decile is formed and the share of spikes inside it is reported against the
   % base rate.
   %
   % The candidate is fitted on days 9 to 28 and scored on 29 to 60. Day 9 is the
   % first trading day the daily offer archive still holds; days 1 to 8 have rolled
   % out of the sixty file window. The scored window is therefore identical to
   % every earlier entry and only the fitting sample is shorter.
   %
   % Writes research/verify/e08_offers.json and fig_e08_offers.png.
   % Run: runs\run_diagnose_e08_offers.bat <log name>

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   fig_dir = fullfile(root, "AEMO_Data", "level_multiwindow_figs");
   out_dir = fullfile(root, "Weekly", "2026-10-13", "research", "verify");
   addpath(genpath(fullfile(root, "Predicitor")));

   n_s = 288;
   [lead_min, ~] = official_lead_axis();
   lead_min = lead_min(:)';
   band = find(lead_min >= 360 & lead_min <= 1440);
   c_1h = find(lead_min == 60, 1);
   n_b = numel(band);
   jd_score = 29:60;
   jd_fit = 9:28;
   n_day = 60;

   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   names = string(A.names);
   k_a = find(names == "Anchor-mix", 1);
   assert(~isempty(k_a), "e08:anchor", "Anchor-mix is not in the atlas");

   R_off = double(O.R_off);
   Yb = double(O.O4(:, band, jd_score)) + double(O.E4_off(:, band, jd_score));
   Ebo = double(O.E4_off(:, band, jd_score));
   Eb_all = double(A.E4(:, band, :, k_a));
   Eb_anc = Eb_all(:, :, jd_score);
   E1a = reshape(double(A.E4(:, c_1h, jd_score, k_a)), n_s, 1, numel(jd_score));

   colR_off = median(R_off(:, band), 1, "omitnan");
   colR_anc = median(sqrt(mean(Eb_anc .^ 2, 3, "omitnan")), 1, "omitnan");
   R1_anc = median(sqrt(mean(E1a .^ 2, 3, "omitnan")));
   fprintf("official  column-median R, band: %8.3f  (registered 29.395)\n", median(colR_off));
   fprintf("anchor    column-median R, band: %8.3f  (registered 41.430)\n", median(colR_anc));
   fprintf("anchor    band ratio %6.4f  (registered 1.333), ratio of medians %6.4f\n", ...
      median(colR_anc ./ colR_off), median(colR_anc) / median(colR_off));
   fprintf("           one hour %7.3f, twenty four hours %7.3f\n", R1_anc, ...
      median(sqrt(mean(Eb_anc(:, end, :) .^ 2, 3, "omitnan"))));

   % ======================================================================
   % 1) the stack on the cube grid
   % ======================================================================
   fprintf("\n=== 1) offer stack features on the cube grid ===\n");
   t0 = double(nem_minutes("2026-08-11 00:00:00"));
   tz = datetime(2025, 1, 1) + minutes(t0);
   assert(abs(tz - datetime(2026, 8, 11)) < minutes(1), "e08:epoch", ...
      "day 1 of the 60-day window is not 2026-08-11");

   cols_need = unique([c_1h, band]);
   j_band = find(ismember(cols_need, band));
   j_1h = find(cols_need == c_1h);

   if nargin >= 1 && strlength(string(src)) > 0, offer_dir = string(src); else, offer_dir = out_dir; end
   [F, T, meta] = load_offer_features(offer_dir);
   fprintf("  %d rows, %d features: %s\n", size(F, 1), numel(meta.feats), strjoin(meta.feats, " "));

   [X100, inf1] = offer_on_grid(F(:, col_of(meta.feats, "mwb_100")), T, t0, n_day, cols_need, lead_min, n_s, 0);
   [X50, ~] = offer_on_grid(F(:, col_of(meta.feats, "mwb_50")), T, t0, n_day, cols_need, lead_min, n_s, 0);
   [X200, ~] = offer_on_grid(F(:, col_of(meta.feats, "mwb_200")), T, t0, n_day, cols_need, lead_min, n_s, 0);
   [X300, ~] = offer_on_grid(F(:, col_of(meta.feats, "mwb_300")), T, t0, n_day, cols_need, lead_min, n_s, 0);
   [Xtot, ~] = offer_on_grid(F(:, col_of(meta.feats, "mw_total")), T, t0, n_day, cols_need, lead_min, n_s, 0);
   [X100p, infp] = offer_on_grid(F(:, col_of(meta.feats, "mwb_100")), T, t0, n_day, cols_need, lead_min, n_s, 1440);
   [X300p, ~] = offer_on_grid(F(:, col_of(meta.feats, "mwb_300")), T, t0, n_day, cols_need, lead_min, n_s, 1440);

   fprintf("  cells filled %d of %d (%.2f%%), no row at the origin %d\n", ...
      inf1.filled, inf1.total, 100 * inf1.filled / inf1.total, inf1.none);
   fprintf("  twenty four hours earlier filled %.2f%%\n", 100 * infp.filled / infp.total);

   Xb100 = reshape(X100(:, j_band, :), n_s, n_b, n_day);
   Xbtot = reshape(Xtot(:, j_band, :), n_s, n_b, n_day);
   Xbsteep = reshape(X200(:, j_band, :) - X50(:, j_band, :), n_s, n_b, n_day);
   Xbd24 = reshape(X100(:, j_band, :) - X100p(:, j_band, :), n_s, n_b, n_day);
   Xbd24h = reshape(X300(:, j_band, :) - X300p(:, j_band, :), n_s, n_b, n_day);
   Xb1h = reshape(X100(:, j_1h, :), n_s, 1, n_day);
   clear X100 X50 X200 X300 Xtot X100p X300p;

   % ======================================================================
   % 2) information gate
   % ======================================================================
   fprintf("\n=== 2) information gate on the 6 to 24 hour band ===\n");
   ch_name = { ...
      "A1 cheap capacity, level"; ...
      "A2 total capacity, level"; ...
      "B1 cheap capacity, change over 24 h"; ...
      "B2 peaking capacity, change over 24 h"; ...
      "C1 steepness near the money"};
   ch_x = {Xb100, Xbtot, Xbd24, Xbd24h, Xbsteep};

   fprintf("  %-36s %9s %11s %8s %9s\n", "regressor", "R sq", "slope", "t", "cols > 1%");
   gates = struct([]);
   for i = 1:numel(ch_name)
      [r2, b, tt] = gate_pooled(Eb_anc, ch_x{i}, 1:n_b, 1:numel(jd_score));
      n_over = 0;  r2col = nan(1, n_b);
      for j = 1:n_b
         [r2c, ~, ~] = gate_pooled(Eb_anc, ch_x{i}, j, 1:numel(jd_score));
         r2col(j) = r2c;
         if isfinite(r2c) && r2c > 0.01, n_over = n_over + 1; end
      end
      fprintf("  %-36s %9.5f %11.3f %8.2f %6d of %d\n", ch_name{i}, r2, b, tt, n_over, n_b);
      gates(i).name = ch_name{i};
      gates(i).r2 = r2;
      gates(i).slope = b;
      gates(i).t = tt;
      gates(i).cols_over_1pct = n_over;
      gates(i).cols = n_b;
      gates(i).r2_max_column = max(r2col);
      gates(i).r2_median_column = median(r2col, "omitnan");
   end

   % ======================================================================
   % 3) spike capture
   % ======================================================================
   fprintf("\n=== 3) spike capture, a spike is an actual price at or above 300 ===\n");
   spike = Yb >= 300;
   base_rate = 100 * sum(spike(:)) / numel(spike);
   fprintf("  %d spike cells of %d, base rate %.2f%%\n", sum(spike(:)), numel(spike), base_rate);

   sp_name = {"A1 cheap capacity, level", "C1 steepness near the money", "B1 cheap capacity, change over 24 h"};
   sp_x = {Xb100, Xbsteep, Xbd24};
   spikes = struct([]);
   for i = 1:numel(sp_name)
      x = sp_x{i}(:, :, jd_score);
      xv = double(x(:));
      sv = spike(:);
      ok = isfinite(xv);
      r = nan(size(xv));
      idx = find(ok);
      [~, ord] = sort(xv(idx));
      rk = zeros(numel(idx), 1);
      rk(ord) = (1:numel(idx))';
      r(idx) = rk;
      cut = tie_cut(r(idx), 0.10);
      tight = false(size(xv));
      tight(idx) = r(idx) <= cut;
      % only cells that carry the feature can be classified, so the base for
      % both shares is the finite subset rather than every band cell
      capture = 100 * sum(sv(ok) & tight(ok)) / max(sum(sv(ok)), 1);
      share = 100 * sum(tight(ok)) / numel(sv(ok));
      fprintf("  %-36s tight share %5.1f%%  spikes inside %5.1f%%  lift %5.2f\n", ...
         sp_name{i}, share, capture, capture / share);
      spikes(i).name = sp_name{i};
      spikes(i).tight_share = share;
      spikes(i).spike_inside = capture;
      spikes(i).lift = capture / share;
   end

   % ======================================================================
   % 4) candidate
   % ======================================================================
   fprintf("\n=== 4) candidate, per column slope fitted on days 9 to 28 ===\n");
   cd_name = {"A1 cheap capacity, level", "B1 cheap capacity, change over 24 h", "C1 steepness"};
   cd_x = {Xb100, Xbd24, Xbsteep};
   cands = struct([]);
   keep = [];
   for i = 1:numel(cd_name)
      xf = cd_x{i};
      b = nan(1, n_b);
      for j = 1:n_b
         [~, bb] = gate_pooled(Eb_all, reshape(xf(:, j, :), n_s, 1, n_day), 1, jd_fit);
         b(j) = bb;
      end
      corr = zeros(size(Eb_anc));
      for j = 1:n_b
         x = reshape(xf(:, j, jd_score), n_s, 1, numel(jd_score));
         corr(:, j, :) = b(j) * (x - mean(x, 1, "omitnan"));
      end
      Ec = Eb_anc - corr;
      colR = median(sqrt(mean(Ec .^ 2, 3, "omitnan")), 1, "omitnan");
      [nb, nw] = dm_cells(Eb_anc, Ec);
      cell_win = 100 * mean(Ec(:) .^ 2 < Ebo(:) .^ 2);
      fprintf("  %-36s band R %8.3f  ratio %6.4f  24 h %7.3f  cells ahead of official %5.1f%%  DM %d better %d worse\n", ...
         cd_name{i}, median(colR), median(colR ./ colR_off), ...
         median(sqrt(mean(Ec(:, end, :) .^ 2, 3, "omitnan"))), cell_win, nb, nw);
      cands(i).name = cd_name{i};
      cands(i).band_R = median(colR);
      cands(i).ratio = median(colR ./ colR_off);
      cands(i).one_hour = R1_anc;
      cands(i).twenty_four_hour = median(sqrt(mean(Ec(:, end, :) .^ 2, 3, "omitnan")));
      cands(i).cells_ahead_of_official = cell_win;
      cands(i).dm_better = nb;
      cands(i).dm_worse = nw;
      if i == 1
         keep.Ec = Ec;
         keep.colR = colR;
      end
   end
   fprintf("  reference: anchor cells ahead of official %.1f%%\n", ...
      100 * mean(Eb_anc(:) .^ 2 < Ebo(:) .^ 2));

   % ======================================================================
   % 5) output
   % ======================================================================
   S = struct();
   S.baseline = struct("official_band_R", median(colR_off), "anchor_band_R", median(colR_anc), ...
      "anchor_ratio", median(colR_anc ./ colR_off), "anchor_one_hour", R1_anc, ...
      "anchor_cells_ahead_of_official", 100 * mean(Eb_anc(:) .^ 2 < Ebo(:) .^ 2), ...
      "cols", n_b);
   S.coverage = struct("filled", inf1.filled, "total", inf1.total, ...
      "none", inf1.none, "prev_day_filled", infp.filled);
   S.gates = gates;
   S.spikes = spikes;
   S.spike_base_rate = base_rate;
   S.candidates = cands;
   S.fit_days = jd_fit;
   S.score_days = jd_score;
   fid = fopen(fullfile(out_dir, "e08_offers.json"), "w");
   fprintf(fid, "%s", jsonencode(S, "PrettyPrint", true));
   fclose(fid);

   colR_ref = median(sqrt(mean(Eb_anc .^ 2, 3, "omitnan")), 1, "omitnan");
   plot_all(out_dir, colR_off, colR_ref, keep.colR, Eb_anc, keep.Ec, spikes, base_rate);
   fprintf("\nwrote e08_offers.json and fig_e08_offers.png\n");
end

% =========================================================================
function i = col_of(feats, name)
   i = find(string(feats) == name, 1);
   assert(~isempty(i), "e08:feature", "feature %s is not in the file", name);
end

% =========================================================================
function [F, T, meta] = load_offer_features(out_dir)
   meta = jsondecode(fileread(fullfile(out_dir, "offer_curve.json")));
   nf = numel(meta.feats);
   fd = fopen(fullfile(out_dir, "offer_curve_times.bin"), "r");
   T = fread(fd, [2, Inf], "double")';
   fclose(fd);
   fd = fopen(fullfile(out_dir, "offer_curve_feat.bin"), "r");
   F = fread(fd, [nf, Inf], "single")';
   fclose(fd);
   assert(size(T, 1) == size(F, 1), "e08:size", "times and features disagree on row count");
   assert(size(T, 1) == meta.rows, "e08:rows", "row count %d does not match the header %d", ...
      size(T, 1), meta.rows);
   % the writer stamps minutes since 1970; nem_minutes counts from 2025-01-01
   T = T + double(nem_minutes("1970-01-01 00:00:00"));
end

% =========================================================================
function [X, info] = offer_on_grid(v, T, t0, n_day, cols, lead_min, n_s, shift)
   % One feature on the cube grid. Cell (slot, column, day) asks for the state at
   % target minus lead, taken at the last publication at or before that origin.
   u = unique(T(:, 1));
   j = discretize(T(:, 1), [u; Inf]);
   tkey = round((T(:, 2) - t0) / 5) + 1;
   mult = n_day * n_s + 10;
   data_key = j * mult + tkey;

   n_c = numel(cols);
   X = nan(n_s, n_c, n_day);
   info.total = n_s * n_c * n_day;
   info.none = 0;
   slot = (0:n_s - 1)' * 5;
   dayoff = (0:n_day - 1) * 1440;
   for c = 1:n_c
      target = t0 + dayoff + slot;
      origin = target - lead_min(cols(c)) - shift;
      jq = discretize(origin, [u; Inf]);
      qkey = jq * mult + (round((target - t0) / 5) + 1);
      [tf, loc] = ismember(qkey, data_key);
      block = nan(n_s, n_day);
      block(tf) = v(loc(tf));
      X(:, c, :) = reshape(block, n_s, 1, n_day);
      info.none = info.none + sum(~tf(:));
   end
   info.filled = sum(isfinite(X(:)));
end

% =========================================================================
function [r2, b, t] = gate_pooled(E, X, cols, days)
   y = [];  v = [];  g = [];
   for i = 1:numel(cols)
      for k = 1:numel(days)
         e = E(:, cols(i), days(k));
         x = X(:, cols(i), days(k));
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
function cut = tie_cut(r, f)
   s = sort(r(:));
   cut = s(max(1, min(numel(s), round(f * numel(s)))));
end

% =========================================================================
function [n_better, n_worse] = dm_cells(EA, EB)
   % A positive loss differential means A has the larger error, so B is better.
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

% =========================================================================
function plot_all(out_dir, colR_off, colR_ref, colR_c, Eb_anc, Ec, spikes, base_rate)
   f = figure("Visible", "off", "Position", [60 60 1540 470]);

   subplot(1, 3, 1);
   hold on;
   plot(colR_off, "-", "Color", [0.75 0.10 0.10], "LineWidth", 1.8);
   plot(colR_c, "-", "Color", [0.12 0.31 0.47], "LineWidth", 1.5);
   plot(colR_ref, "--", "Color", [0.45 0.45 0.45], "LineWidth", 1.1);
   hold off;  grid on;
   xlabel("band column, 6 h to 24 h");  ylabel("column median R, $/MWh");
   title("a. the profile barely moves");
   legend({"official", "candidate A1", "anchor"}, "Location", "northwest", "Box", "off");

   subplot(1, 3, 2);
   ok = isfinite(Eb_anc(:)) & isfinite(Ec(:));
   lim = [min([Eb_anc(ok); Ec(ok)]) max([Eb_anc(ok); Ec(ok)])];
   if numel(lim) ~= 2 || any(~isfinite(lim)) || lim(1) >= lim(2), lim = [-400 400]; end
   hold on;
   plot(lim, lim, "k-", "LineWidth", 0.8);
   scatter(Eb_anc(ok), Ec(ok), 2.5, [0.12 0.31 0.47], "filled", "MarkerFaceAlpha", 0.12);
   hold off;  grid on;  axis equal;  xlim(lim);  ylim(lim);
   xlabel("anchor error, $/MWh");  ylabel("candidate error, $/MWh");
   title("b. cell by cell on the scored days");

   subplot(1, 3, 3);
   n = numel(spikes);
   vals = zeros(n, 2);
   for i = 1:n
      vals(i, 1) = spikes(i).spike_inside;
      vals(i, 2) = spikes(i).tight_share;
   end
   bar(vals, "grouped");
   grid on;
   set(gca, "XTick", 1:n, "XTickLabel", {"cheap level", "steepness", "cheap, 24 h"});
   ylabel("per cent");
   title(sprintf("c. spikes at or above 300, base rate %.1f per cent", base_rate));
   legend({"spikes inside the tight decile", "share of cells in it"}, ...
      "Location", "northwest", "Box", "off");

   sgtitle("E08: none of the five level free stack quantities explains the 6 to 24 hour error", ...
      "FontSize", 11);
   exportgraphics(f, fullfile(out_dir, "fig_e08_offers.png"), "Resolution", 140);
   close(f);
end
