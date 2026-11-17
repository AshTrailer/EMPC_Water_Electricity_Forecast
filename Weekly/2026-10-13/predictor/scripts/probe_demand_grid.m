function probe_demand_grid()
   % PROBE_DEMAND_GRID  One run's matrix row against its own raw rows
   %
   %    The shared loader used to place a value with the linear index that a
   %    column-major matrix of n_col rows would need, while the matrix it filled
   %    had n_run rows. Every size check passed and every row was scattered. This
   %    prints one run's raw rows beside the same row of the matrix, which is the
   %    check that fails on a transposed index.
   %
   %    Reads predispatch_30min_VIC1.csv read-only, writes no file.
   %    Run: runs\run_probe_demand_grid.bat <log name>

   root = "C:\Ash\Projects\EMPC_Water_Electricity_Forecast";
   win = fullfile(root, "AEMO_Data", "window_60d_20260811_20261009_vic1");
   addpath(genpath(fullfile(root, "Predicitor")));

   csv = fullfile(win, "predispatch_30min_VIC1.csv");
   [DEM, eff_r, n_col] = predispatch_demand_load(csv);
   n_run = numel(eff_r);

   fid = fopen(csv, "r");
   c = textscan(fid, "%s %s %s %s %s %s %s %s %s %s", "Delimiter", ",", ...
      "HeaderLines", 1, "ReturnOnError", false);
   fclose(fid);
   eff = nem_minutes(c{1});
   tgt = nem_minutes(c{3});
   dem = str2double(c{7});
   lag = tgt - eff;
   [~, k] = ismember(eff, eff_r);

   fprintf("\nsize(DEM) %s, n_col %d, n_run %d\n", mat2str(size(DEM)), n_col, n_run);

   % ---- every run: raw row count against filled horizon length ----------
   last = accumarray(double(k), double(lag) / 30 + 1, [n_run 1], @max);
   nrow_p = accumarray(double(k), 1, [n_run 1]);
   fill_p = sum(isfinite(DEM), 2);
   fprintf("rows per run %d to %d, filled columns %d to %d, runs where they differ %d\n", ...
      min(nrow_p), max(nrow_p), min(fill_p), max(fill_p), sum(nrow_p ~= fill_p));
   fprintf("runs whose fill is not exactly columns 1 to their own last period: %d\n", ...
      sum(fill_p ~= last));

   % ---- one run, raw beside matrix --------------------------------------
   r = 1885;
   idx = find(k == r);
   fprintf("\nrun %d (%s), %d raw rows\n", r, ...
      char(datetime(2025, 1, 1) + minutes(double(eff_r(r))), "yyyy-MM-dd HH:mm:ss"), numel(idx));
   bad = 0;
   for i = 1:numel(idx)
      j = idx(i);
      col = double(lag(j)) / 30 + 1;
      if abs(DEM(r, col) - dem(j)) > 1e-9, bad = bad + 1; end
   end
   fprintf("  cells of that row disagreeing with the file: %d of %d\n", bad, numel(idx));
   fprintf("  column  raw lag   raw demand   DEM(r,c)\n");
   for i = 1:min(8, numel(idx))
      j = idx(i);
      col = double(lag(j)) / 30 + 1;
      fprintf("  %6.0f  %7.0f   %10.1f   %9.1f\n", col, double(lag(j)), dem(j), DEM(r, col));
   end

   % ---- the whole matrix, every row ------------------------------------
   lin = sub2ind([n_run, n_col], double(k), double(lag) / 30 + 1);
   fprintf("\nall %d rows round trip through the matrix: %d agree\n", numel(dem), ...
      sum(DEM(lin) == dem));

   % ---- what one target now looks like across leads ---------------------
   t0 = double(nem_minutes("2026-08-11 00:00:00"));
   n_s = 288;
   d = 40;
   s = 145;
   T = t0 + (d - 1) * 1440 + 5 * (s - 1);
   sel = (tgt == T);
   fprintf("\ntarget %s carried by %d runs, raw spread %.1f%%\n", ...
      char(datetime(2025, 1, 1) + minutes(T), "yyyy-MM-dd HH:mm:ss"), sum(sel), ...
      100 * (max(dem(sel)) - min(dem(sel))) / mean(dem(sel)));
   lead_min = [360 720 1080 1440];
   fprintf("  lead   run            column   DEM(r,c)   raw lag\n");
   for L = lead_min
      org = T - L;
      kk = sum(double(eff_r) <= org);
      colf = (T - double(eff_r(kk))) / 30;
      col = floor(colf) + 1;
      fprintf("  %4.0f   %s   %6.0f   %9.1f   %7.0f\n", L / 60, ...
         char(datetime(2025, 1, 1) + minutes(double(eff_r(kk))), "MM-dd HH:mm"), ...
         col, DEM(kk, col), floor(colf) * 30);
   end
end
