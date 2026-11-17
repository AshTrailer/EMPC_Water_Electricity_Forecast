function diagnose_e09_stack(mode)
   % DIAGNOSE_E09_STACK  Does the scheduled stack, read at the cleared generation, price the region?
   %
   % N23 read the stack at regional demand and landed 900 $/MWh away. N25 showed
   % the gap is capacity the stack counts and the dispatch never uses: the semi
   % scheduled offers, whose bid curve is not availability. The fix is not to cap
   % them but to leave them out and to read the scheduled stack at the quantity the
   % scheduled fleet actually serves, which the predispatch report publishes as
   % DISPATCHABLEGENERATION.
   %
   % This scores that reading against the settled price. The predispatch report
   % gives, for every origin and every thirty minute target, the published price,
   % the demand, the dispatchable generation and the two semi scheduled
   % availabilities, so the same stack can be read three ways at every lead:
   %
   %   A  at the dispatchable generation, the scheduled fleet's own output
   %   B  at regional demand, which is what N23 did
   %   C  at demand plus the net interchange, the total generation
   %
   % The lead profile from five minutes to forty hours is the validity test. A
   % structural read that cannot reproduce the settled price at thirty minutes
   % cannot produce a forecast at twenty four hours either.
   %
   % Writes research/verify/e09_stack.json and fig_e09_stack.png.
   % Run: runs\run_diagnose_e09_stack.bat <mode>

   if nargin < 1 || strlength(string(mode)) == 0, mode = "aligned"; end
   mode = string(mode);
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
   jd = 29:60;
   n_day = 60;
   % nem_minutes counts from 2025-01-01, the candidate file counts from 1970
   t0n = double(nem_minutes("2026-08-11 00:00:00"));
   t0 = t0n - double(nem_minutes("1970-01-01 00:00:00"));

   O = matfile(fullfile(fig_dir, "official_60d.mat"));
   A = matfile(fullfile(fig_dir, "atlas_60d.mat"));
   names = string(A.names);
   k_a = find(names == "Anchor-mix", 1);
   assert(~isempty(k_a), "e09:anchor", "Anchor-mix is not in the atlas");

   % ======================================================================
   % 1) the settled price, on the atlas target grid
   % ======================================================================
   T = table();
   for m = ["202608", "202609", "202610"]
      X = readtable(fullfile(root, "AEMO_Data", sprintf("PRICE_AND_DEMAND_%s_VIC1.csv", m)), ...
         "Delimiter", ",", "TextType", "string");
      T = [T; X];
   end
   T.SETTLEMENTDATE = datetime(T.SETTLEMENTDATE, "InputFormat", "yyyy/MM/dd HH:mm:ss");
   slot = (0:n_s - 1)';
   P = nan(n_s, n_day);
   for d = 1:n_day
      tt = datetime(2025, 1, 1) + minutes(t0n + (d - 1) * 1440 + slot * 5 + 5);
      P(:, d) = interp1(T.SETTLEMENTDATE, T.RRP, tt, "nearest", NaN);
   end
   fprintf("settled price %d of %d cells, median %.3f, share at or above 300 %.3f%%\n", ...
      sum(isfinite(P(:))), numel(P), median(P(:), "omitnan"), 100 * mean(P(:) >= 300, "omitnan"));

   % ======================================================================
   % 2) the structural readings
   % ======================================================================
   meta = jsondecode(fileread(fullfile(out_dir, "e09_candidate.json")));
   n_col = numel(meta.cols);
   fd = fopen(fullfile(out_dir, "e09_candidate.bin"), "r");
   C = fread(fd, [n_col, Inf], "double")';
   fclose(fd);
   assert(size(C, 1) == meta.rows, "e09:rows", "candidate rows %d against header %d", ...
      size(C, 1), meta.rows);
   ci = @(name) find(string(meta.cols) == name, 1);
   fprintf("candidate rows %d, columns %s\n", size(C, 1), strjoin(string(meta.cols), " "));

   key_cand = C(:, ci("origin")) * 1e8 + C(:, ci("target"));
   [key_cand, ord] = sort(key_cand);
   C = C(ord, :);

   % target and origin of every cell, then the predispatch grid it belongs to
   [ss, hh, dd] = ndgrid(1:n_s, 1:numel(lead_min), jd);
   % a slot is the five minutes starting at its stamp, and the price that lands
   % on it is the interval ending five minutes later, which is the reference the
   % forecast lead and the thirty minute publication grid are both measured from
   t_ref = t0 + (dd - 1) * 1440 + ss * 5;
   target = t_ref - 5;
   origin = t_ref - lead_min(hh);
   % the publication grid: out of the half hour for the origin, into the half
   % hour for the target
   o_pd = 30 * floor(origin / 30);
   t_pd = 30 * ceil(t_ref / 30);
   aligned = mod(origin, 30) == 0 & mod(t_ref, 30) == 0;
   fprintf("cells %d, %d on the half hour grid (%.1f%%)\n", numel(target), sum(aligned(:)), ...
      100 * mean(aligned(:)));

   qkey = o_pd(:) * 1e8 + t_pd(:);
   [tf, loc] = ismember(qkey, key_cand);
   p_cand = nan(size(qkey));
   p_dem = nan(size(qkey));
   age = nan(size(qkey));
   p_cand(tf) = C(loc(tf), ci("price_at_dispatchable"));
   p_dem(tf) = C(loc(tf), ci("price_at_demand"));
   age(tf) = C(loc(tf), ci("lodge_age_min"));
   p_cand = reshape(p_cand, n_s, numel(lead_min), numel(jd));
   p_dem = reshape(p_dem, n_s, numel(lead_min), numel(jd));
   age = reshape(age, n_s, numel(lead_min), numel(jd));
   aligned = reshape(aligned, n_s, numel(lead_min), numel(jd));

   Pg = reshape(P(:, jd), n_s, 1, numel(jd));
   E_cand = p_cand - Pg;
   E_dem = p_dem - Pg;
   E_off = double(O.E4_off);
   E_anc = double(A.E4(:, :, :, k_a));

   % ======================================================================
   % 3) the validity test: error by lead
   % ======================================================================
   fprintf("\n=== 3) median absolute error by lead, days %d to %d ===\n", jd(1), jd(end));
   fprintf("  %8s %10s %10s %10s %10s\n", "lead min", "stack@gen", "stack@dem", "official", "anchor");
   lead_show = [5 30 60 120 360 720 1440 2880 5760 10980];
   prof = struct([]);
   for i = 1:numel(lead_min)
      a = abs(E_cand(:, i, :));
      b = abs(E_dem(:, i, :));
      o = abs(E_off(:, i, jd));
      n = abs(E_anc(:, i, jd));
      prof(i).lead = lead_min(i);
      prof(i).gen = median(a(:), "omitnan");
      prof(i).dem = median(b(:), "omitnan");
      prof(i).off = median(o(:), "omitnan");
      prof(i).anc = median(n(:), "omitnan");
   end
   for L = lead_show
      i = find(lead_min == L, 1);
      if isempty(i), continue; end
      fprintf("  %8d %10.2f %10.2f %10.2f %10.2f\n", L, prof(i).gen, prof(i).dem, ...
         prof(i).off, prof(i).anc);
   end

   % ======================================================================
   % 4) the band score
   % ======================================================================
   fprintf("\n=== 4) band score, mode %s ===\n", mode);
   if mode == "aligned"
      use = aligned(:, band, :);
   else
      use = true(n_s, n_b, numel(jd));
   end
   Ea = E_anc(:, band, jd);
   Eb = E_cand(:, band, :);
   Ed = E_dem(:, band, :);
   Eo = E_off(:, band, jd);
   Ea(~use) = NaN;  Eb(~use) = NaN;  Ed(~use) = NaN;  Eo(~use) = NaN;

   R_off = median(sqrt(mean(Eo .^ 2, 3, "omitnan")), 1, "omitnan");
   R_anc = median(sqrt(mean(Ea .^ 2, 3, "omitnan")), 1, "omitnan");
   R_gen = median(sqrt(mean(Eb .^ 2, 3, "omitnan")), 1, "omitnan");
   R_dem = median(sqrt(mean(Ed .^ 2, 3, "omitnan")), 1, "omitnan");
   fprintf("  official  band column median R %8.3f  ratio 1.0000\n", median(R_off));
   fprintf("  anchor    band column median R %8.3f  ratio %6.4f\n", median(R_anc), median(R_anc ./ R_off));
   fprintf("  stack@gen band column median R %8.3f  ratio %6.4f\n", median(R_gen), median(R_gen ./ R_off));
   fprintf("  stack@dem band column median R %8.3f  ratio %6.4f\n", median(R_dem), median(R_dem ./ R_off));

   nan_gen = 100 * mean(~isfinite(Eb(use)));
   fprintf("  cells without a reading %0.1f%%, median age of the lodgement used %0.0f min\n", ...
      nan_gen, median(age(:, band, :), "all", "omitnan"));

   [nb, nw] = dm_cells(Ea, Eb);
   win = 100 * mean(abs(Eb(:)) < abs(Ea(:)), "omitnan");
   fprintf("  cells ahead of the anchor %0.1f%%, DM better %d worse %d\n", win, nb, nw);
   [nb2, nw2] = dm_cells(Ea, Ed);
   fprintf("  stack@dem, DM better %d worse %d\n", nb2, nw2);

   for L = [30 360 1440]
      i = find(lead_min == L, 1);
      if isempty(i), continue; end
      e = E_cand(:, i, :);  e = e(isfinite(e));
      if isempty(e), continue; end
      fprintf("  lead %5d signed median %8.2f, median abs %8.2f, within 5 $ %5.1f%%, within 20 $ %5.1f%%\n", ...
         L, median(e), median(abs(e)), 100 * mean(abs(e) <= 5), 100 * mean(abs(e) <= 20));
   end
   eb = Eb(isfinite(Eb));
   if ~isempty(eb)
      fprintf("  band signed median %8.2f, median abs %8.2f, within 5 $ %5.1f%%, within 20 $ %5.1f%%\n", ...
         median(eb), median(abs(eb)), 100 * mean(abs(eb) <= 5), 100 * mean(abs(eb) <= 20));
   end
   R1_gen = median(sqrt(mean(E_cand(:, c_1h, :) .^ 2, 3, "omitnan")));
   R24_gen = median(sqrt(mean(E_cand(:, band(end), :) .^ 2, 3, "omitnan")));
   R1_anc = median(sqrt(mean(A.E4(:, c_1h, jd, k_a) .^ 2, 3, "omitnan")));
   R24_anc = median(sqrt(mean(A.E4(:, band(end), jd, k_a) .^ 2, 3, "omitnan")));
   fprintf("  stack@gen one hour %7.3f twenty four hours %7.3f\n", R1_gen, R24_gen);
   fprintf("  anchor    one hour %7.3f twenty four hours %7.3f\n", R1_anc, R24_anc);

   % ======================================================================
   % 5) figure
   % ======================================================================
   plot_all(out_dir, prof, Ea, Eb, Ed, lead_min);

   json = struct();
   json.mode = mode;
   json.cells = numel(Eb);
   json.aligned_share = 100 * mean(aligned(:));
   json.official_band = median(R_off);
   json.anchor_band = median(R_anc);
   json.gen_band = median(R_gen);
   json.dem_band = median(R_dem);
   json.gen_ratio = median(R_gen ./ R_off);
   json.dem_ratio = median(R_dem ./ R_off);
   json.gen_one_hour = R1_gen;
   json.gen_twentyfour = R24_gen;
   json.anchor_one_hour = R1_anc;
   json.anchor_twentyfour = R24_anc;
   json.win_vs_anchor = win;
   json.dm_better = nb;
   json.dm_worse = nw;
   json.cells_missing = nan_gen;
   json.lodge_age_median = median(age(:, band, :), "all", "omitnan");
   json.profile = prof;
   fid = fopen(fullfile(out_dir, "e09_stack.json"), "w");
   fprintf(fid, "%s", jsonencode(json));
   fclose(fid);
   fprintf("\nwrote %s\n", fullfile(out_dir, "e09_stack.json"));
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
      gl = mean(D(:, 1+l:end) .* D(:, 1:end-l), 2) - mu .^ 2;
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
function plot_all(out_dir, prof, Ea, Eb, Ed, lead_min)
   f = figure("Visible", "off", "Position", [60 60 1500 900]);
   leads = [prof.lead];

   subplot(2, 2, 1);
   hold on;
   plot(leads, [prof.off], "-", "Color", [0.75 0.10 0.10], "LineWidth", 1.8);
   plot(leads, [prof.anc], "--", "Color", [0.45 0.45 0.45], "LineWidth", 1.2);
   plot(leads, [prof.gen], "-", "Color", [0.12 0.31 0.47], "LineWidth", 1.9);
   plot(leads, [prof.dem], ":", "Color", [0.55 0.70 0.35], "LineWidth", 1.4);
   hold off;  grid on;  set(gca, "XScale", "log");
   xlim([5 2400]);   % the report horizon is thirty nine hours
   xlabel("lead, minutes");  ylabel("median absolute error, $/MWh");
   title(sprintf("a. the stack read at the cleared generation is further from\nthe price than the official forecast, at every lead"), "Fontsize", 11);
   legend({"official", "anchor", "stack at dispatchable generation", "stack at demand"}, ...
      "Location", "northwest", "Box", "off", "FontSize", 8);

   subplot(2, 2, 2);
   hold on;
   lim = [-100 420];
   plot(lim, lim, "k-", "LineWidth", 0.9);
   ok = isfinite(Ea) & isfinite(Eb);
   scatter(Ea(ok), Eb(ok), 2.2, [0.12 0.31 0.47], "filled", "MarkerFaceAlpha", 0.10);
   hold off;  grid on;  axis equal;  xlim(lim);  ylim(lim);
   xlabel("anchor error, $/MWh");  ylabel("structural error, $/MWh");
   title("b. cell by cell on the scored days", "Fontsize", 11);

   subplot(2, 2, 3);
   ok = isfinite(Ed) & isfinite(Eb);
   scatter(Ed(ok), Eb(ok), 2.2, [0.55 0.70 0.35], "filled", "MarkerFaceAlpha", 0.10);
   grid on;  axis equal;
   xlim([-1000 420]);  ylim([-1000 420]);
   xlabel("stack at demand error, $/MWh");  ylabel("stack at generation error, $/MWh");
   title("c. the same stack, two quantities", "Fontsize", 11);

   subplot(2, 2, 4);
   ok = isfinite(Ea);
   m = 60;
   edges = linspace(-500, 500, m + 1);
   ctr = edges(1:end-1) + diff(edges) / 2;
   hold on;
   histogram(Ea(ok), edges, "Normalization", "probability", "DisplayStyle", "stairs", ...
      "EdgeColor", [0.45 0.45 0.45], "LineWidth", 1.2);
   histogram(Eb(ok), edges, "Normalization", "probability", "DisplayStyle", "stairs", ...
      "EdgeColor", [0.12 0.31 0.47], "LineWidth", 1.6);
   hold off;  grid on;
   xlabel("signed error, $/MWh");  ylabel("share of cells");
   title("d. signed error, anchor and structural", "Fontsize", 11);
   legend({"anchor", "stack at generation"}, "Location", "northwest", "Box", "off", "FontSize", 8);

   sgtitle("E09: the scheduled stack, read at the cleared generation", "FontSize", 11);
   exportgraphics(f, fullfile(out_dir, "fig_e09_stack.png"), "Resolution", 140);
   close(f);
end
