function [DEM, eff_r, n_col, same] = predispatch_demand_load(path)
   % PREDISPATCH_DEMAND_LOAD  The demand forecast column as a run by horizon matrix
   %
   %    Uses the publication identity
   %       target_datetime = effective_time + 30 * (column - 1)
   %    that OFFICIAL_COMPOSITE_LOAD relies on for the same file, so the demand
   %    forecast lands on exactly the grid the price forecast does.
   %
   %    Column 7 of the file is total_demand. It is a forecast and not the
   %    realised series, which is checked rather than assumed: the same target
   %    seen from different runs must move.
   %
   %    Input:
   %       path - predispatch_30min_<REGION>.csv
   %    Output:
   %       DEM   - (n_run x n_col) demand in MW, NaN where the run does not reach
   %       eff_r - (n_run x 1) int64 effective times in NEM minutes, ascending
   %       n_col - horizon columns, 30 minutes each
   %       same  - [targets carrying one value across runs, targets with more
   %               than five runs]
   %
   %    See also PREDISPATCH_DEMAND_ON_GRID, OFFICIAL_COMPOSITE_LOAD.

   arguments
      path (1,1) string
   end

   fid = fopen(path, "r");
   assert(fid > 0, "predispatch_demand_load:open", "cannot open %s", path);
   c = textscan(fid, "%s %s %s %s %s %s %s %s %s %s", "Delimiter", ",", ...
      "HeaderLines", 1, "ReturnOnError", false);
   fclose(fid);
   eff = nem_minutes(c{1});
   tgt = nem_minutes(c{3});
   dem = str2double(c{7});
   assert(~all(isnan(dem)), "predispatch_demand_load:column", ...
      "column 7 carries no numbers, the layout has changed");

   lag = tgt - eff;
   assert(all(lag >= 0), "predispatch_demand_load:lag", ...
      "a target precedes its own effective time");
   assert(all(mod(lag, 30) == 0), "predispatch_demand_load:grid", ...
      "a target is off the 30-minute grid");

   eff_r = unique(eff);
   n_run = numel(eff_r);
   n_col = double(max(lag) / 30) + 1;
   [~, k] = ismember(eff, eff_r);
   col = double(lag / 30) + 1;
   lin = sub2ind([n_run, n_col], double(k), col);
   assert(numel(unique(lin)) == numel(lin), "predispatch_demand_load:dup", ...
      "a (run, target) pair repeats");
   DEM = nan(n_run, n_col);
   DEM(lin) = dem;

   [~, ~, jt] = unique(tgt);
   cnt = accumarray(jt, 1);
   vr = accumarray(jt, dem, [max(jt) 1], @range_of_finite);
   same = [sum(vr == 0 & cnt > 5), sum(cnt > 5)];

   % A run fills horizon columns 1 to its own last period with no gap. A linear
   % index written as (run - 1) * n_col + column maps to a row only when the
   % matrix has n_col rows, so a transposed index passes every size check and
   % still scatters values across rows. This assertion is what fails then.
   last = accumarray(double(k), col, [n_run 1], @max);
   nrow_p = accumarray(double(k), 1, [n_run 1]);
   fill_p = sum(isfinite(DEM), 2);
   target_cnt = last;
   gap = fill_p ~= target_cnt;
   fprintf("  demand  %6d rows, %4d runs, %3d horizon columns (%.1f h), matrix %.1f%% filled\n", ...
      numel(dem), n_run, n_col, (n_col - 1) * 0.5, 100 * mean(isfinite(DEM), "all"));
   fprintf("          rows per run %d to %d, filled columns per run %d to %d, " + ...
      "runs where they differ %d\n", min(nrow_p), max(nrow_p), min(fill_p), ...
      max(fill_p), sum(gap));
   fprintf("          targets whose value never moves across runs: %d of %d\n", ...
      same(1), same(2));
   assert(~any(gap), "predispatch_demand_load:layout", ...
      "%d runs hold a different number of values than their own horizon length", sum(gap));
end

function r = range_of_finite(v)
   v = v(isfinite(v));
   if isempty(v)
      r = NaN;
   else
      r = max(v) - min(v);
   end
end
