function probe_demand_trace()
   % PROBE_DEMAND_TRACE  Print the demand lookup step by step for a few cells
   %
   %    The availability of a demand forecast at the origin has to fall as the
   %    lead grows, because the run at the origin must reach further. The full
   %    script reports the opposite, so the intermediate quantities are printed
   %    here instead of inferred.
   %
   % Run: runs\run_probe_demand_trace.bat

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   win = fullfile(root, "AEMO_Data", "window_60d_20260811_20261009_vic1");
   addpath(genpath(fullfile(root, "Predicitor")));

   [DEM, eff_r, n_col, ~] = predispatch_demand_load(fullfile(win, ...
      "predispatch_30min_VIC1.csv"));
   eff_d = double(eff_r(:))';
   n_s = 288;
   t0 = double(nem_minutes("2026-08-11 00:00:00"));
   n_col_dem = size(DEM, 2);

   fprintf("\neff_r: %d values, class %s, first %s last %s, spaced %.1f min\n", ...
      numel(eff_d), class(eff_r), stamp(eff_d(1), t0), stamp(eff_d(end), t0), ...
      median(diff(eff_d)));

   % the horizon each run reaches, by hour of the effective time
   hz = zeros(numel(eff_d), 1);
   for k = 1:numel(eff_d)
      hz(k) = sum(isfinite(DEM(k, :)));
   end
   hod = floor(mod(eff_d - t0, 1440) / 60);
   fprintf("\nhour  runs  horizon columns min/median/max\n");
   for h = 0:23
      v = hz(hod == h);
      if isempty(v), continue; end
      fprintf("  %2d  %4d   %3d / %3d / %3d\n", h, numel(v), min(v), median(v), max(v));
   end

   % a few cells, traced
   cases = [217 31 360; 217 31 1440; 100 31 360; 100 31 1440; 10 31 720];
   fprintf("\n slot day  lead   target            origin            k   run               colf    c0  base      next\n");
   for c = 1:size(cases, 1)
      s = cases(c, 1); d = cases(c, 2); L = cases(c, 3);
      tgt = t0 + (d - 1) * 1440 + 5 * (s - 1);
      org = tgt - L;
      k = sum(eff_d <= org);
      if k == 0
         fprintf("  %3d %3d %5d   %s   %s   no run\n", s, d, L, stamp(tgt, t0), stamp(org, t0));
         continue;
      end
      colf = (tgt - eff_d(k)) / 30;
      c0 = floor(colf);
      base = NaN; nxt = NaN;
      if c0 + 1 <= n_col_dem, base = DEM(k, c0 + 1); end
      if c0 + 2 <= n_col_dem, nxt = DEM(k, c0 + 2); end
      fprintf("  %3d %3d %5d   %s   %s   %4d  %s  %6.2f  %3d  %8.2f  %8.2f\n", ...
         s, d, L, stamp(tgt, t0), stamp(org, t0), k, stamp(eff_d(k), t0), colf, c0, base, nxt);
   end

   % availability of the base column by lead, computed here and not in the helper
   leads = [360 540 720 1080 1440];
   fprintf("\nlead   cells   base present\n");
   for L = leads
      n_ok = 0; n_tot = 0;
      for d = 1:60
         tgt = t0 + (d - 1) * 1440 + 5 * (0:n_s-1)';
         org = tgt - L;
         k = sum(eff_d <= org, 2);
         ok = k > 0;
         if ~any(ok), continue; end
         kk = k(ok);
         c0 = floor((tgt(ok) - eff_d(kk)) / 30);
         lin = sub2ind(size(DEM), kk, min(c0 + 1, n_col_dem));
         v = DEM(lin);
         n_ok = n_ok + sum(isfinite(v));
         n_tot = n_tot + numel(v);
      end
      fprintf("  %5d  %6d   %5.1f%%\n", L, n_tot, 100 * n_ok / n_tot);
   end
end

function s = stamp(m, t0)
   s = datestr((double(m) - t0) / 1440 + datenum(2026, 8, 11), "mm-dd HH:MM");
end
