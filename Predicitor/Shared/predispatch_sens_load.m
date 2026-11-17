function [P, eff_r, scen_mw, ref] = predispatch_sens_load(path)
   % PREDISPATCH_SENS_LOAD  The VIC1 price sensitivity ladder as a run by horizon matrix
   %
   %    PRICESENSITIVITIES carries, for every pre-dispatch run and every target
   %    period, the price the dispatch engine would produce if VIC1 demand moved
   %    by a fixed offset. The offsets are documented in AEMO's Pre-Dispatch
   %    Sensitivities, NER 3.13.4(h), version 7.0, and for VIC1 they are
   %    scenarios 8 to 14 at +100, -100, +200, -200, +500, -500, +1000 MW.
   %    Scenarios 21 to 24 no longer exist, they belonged to the abolished
   %    SNOWY1 region, which is why the file jumps from 20 to 25.
   %
   %    The effective time is not in the file. Each row carries its target and a
   %    period number, and the publication identity used everywhere else in this
   %    project gives effective_time = target - 30 * (period - 1).
   %
   %    Input:
   %       path - sens_vic1.csv, VIC1 rows only, columns located by name
   %    Output:
   %       P       - (n_run x n_col x 7) price in $/MWh, scenario order as scen_mw
   %       eff_r   - (n_run x 1) int64 effective times in NEM minutes, ascending
   %       scen_mw - (1 x 7) VIC1 demand offset per scenario, MW
   %       ref     - struct with the row census
   %
   %    See also PREDISPATCH_ON_GRID, PREDISPATCH_DEMAND_LOAD.

   arguments
      path (1,1) string
   end

   scen_mw = [100 -100 200 -200 500 -500 1000];
   cols = 8:14;
   name = strings(1, numel(cols));
   for i = 1:numel(cols), name(i) = sprintf("RRPEEP%d", cols(i)); end

   fid = fopen(path, "r");
   assert(fid > 0, "sens_load:open", "cannot open %s", path);
   c = textscan(fid, "%f %f %f %f %s %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f", ...
      "Delimiter", ",", "HeaderLines", 1, "ReturnOnError", false);
   fclose(fid);
   hdr = read_header(path);
   assert(isequal(hdr(7 + (cols - 1)), name(:)), "sens_load:columns", ...
      "the file does not carry %s in the expected order", strjoin(name, ", "));

   % Timestamps are quoted and written with slashes here, unlike the PREDISPATCH
   % export, so both are normalised before parsing.
   ts = strrep(strrep(c{5}, """", ""), "/", "-");
   tgt = double(nem_minutes(ts));
   per = c{3};
   V = [c{7:20}];
   assert(~all(isnan(V), "all"), "sens_load:values", "no prices parsed");

   % Intervention runs sit off the 30 minute grid and would both add rows and
   % split a publication into two runs. Only the non-intervention schedule is
   % the one the price forecast is built from.
   iv = c{4};
   keep = (iv == 0);
   n_iv = sum(~keep);
   tgt = tgt(keep);  per = per(keep);  V = V(keep, :);
   assert(all(per >= 1), "sens_load:period", "a period number below 1");
   eff = tgt - 30 * (per - 1);

   [eff_r, ~, k] = unique(eff);
   n_run = numel(eff_r);
   col = per;
   n_col = max(col);
   lin = sub2ind([n_run, n_col], double(k), double(col));
   assert(numel(unique(lin)) == numel(lin), "sens_load:dup", ...
      "a (run, target) pair repeats");

   P = nan(n_run, n_col, numel(cols));
   for i = 1:numel(cols)
      v = nan(n_run, n_col);
      v(lin) = V(:, i);
      P(:, :, i) = v;
   end

   last = accumarray(double(k), double(col), [n_run 1], @max);
   fill_p = squeeze(sum(isfinite(P(:, :, 1)), 2));
   assert(isequal(fill_p(:), last(:)), "sens_load:layout", ...
      "%d runs hold a different number of prices than their own horizon length", ...
      sum(fill_p(:) ~= last(:)));

   % The effective times say the first period of a run is its own issue time, so
   % the derived times must be strictly increasing with the period number.
   assert(all(diff(double(eff_r)) > 0), "sens_load:order", "effective times are not ascending");

   ref = struct("rows", numel(tgt), "runs", n_run, "n_col", n_col, ...
      "max_h", (n_col - 1) * 0.5, "fill", mean(isfinite(P(:, :, 1)), "all"), ...
      "per_run_min", min(last), "per_run_max", max(last), "intervention_rows", n_iv);
   fprintf("  sens    %6d rows, %4d runs, %3d horizon columns (%.1f h), matrix %.1f%% filled\n", ...
      ref.rows, n_run, n_col, ref.max_h, 100 * ref.fill);
   fprintf("          periods per run %d to %d, intervention rows dropped %d, ladder %s MW\n", ...
      ref.per_run_min, ref.per_run_max, n_iv, strjoin(string(scen_mw), " "));
end

% =========================================================================
function h = read_header(path)
   fid = fopen(path, "r");
   line = fgetl(fid);
   fclose(fid);
   h = strip(split(string(line), ","));
end
