function cfg = official_composite_load(data_root)
   % OFFICIAL_COMPOSITE_LOAD  Index the three official AEMO price forecasts
   %
   %    Builds the lookup table OFFICIAL_COMPOSITE reads. Every product is
   %    stored as a rectangular matrix over its own run index, because the
   %    publication identity
   %
   %       target_datetime = effective_time + step * (period_id - 1)
   %
   %    holds row for row in all three files, so the column of a target is a
   %    closed form rather than a search.
   %
   %    Timestamp convention, measured not assumed: the timestamp on an
   %    official row is the END of the interval it describes, the same
   %    convention as SETTLEMENTDATE on the actual price series. The probe
   %    that established this is
   %    Weekly/2026-10-13/predictor/scripts/probe_p5min_phase.mjs; its
   %    two-dimensional error matrix is smallest on the diagonal at every one
   %    of the twelve P5MIN offsets and larger one step out at all twelve.
   %
   %    Input:
   %       data_root - the AEMO_Data folder
   %    Output:
   %       cfg - struct:
   %          products  struct array, one row per product, tried in order:
   %             name      display name
   %             eff       (n_runs x 1) int64, effective times in NEM minutes
   %             vals      (n_runs x n_col) double, RRP, NaN where absent
   %             leadmax   (n_runs x 1) int64, largest lead the run reaches
   %             step      int64, cadence of the product in minutes
   %             n_col     double, columns of vals
   %          names     the three names in trial order
   %          window    two int64 bounds of the data actually indexed
   %
   %    See also OFFICIAL_COMPOSITE, BUILD_OFFICIAL_ATLAS.

   arguments
      data_root (1,1) string
   end

   % The staging step that prepares the VIC1 windows for the remote repository
   % appends the region to the directory name, so the loader accepts either
   % spelling rather than pinning one: a rename must not take the composite
   % offline, and a missing directory has to report which names it tried.
   win = pick_dir(data_root, ["window_60d_20260811_20261009_vic1", ...
                              "window_60d_20260811_20261009"]);
   src = [fullfile(win, "p5min_vic1_partial", "p5min_20260811_20261009.csv"), ...
          fullfile(win, "predispatch_30min_VIC1.csv"), ...
          fullfile(win, "pd7day_30min_VIC1.csv")];
   step = [5 30 30];
   name = ["P5MIN" "PREDISPATCH" "PD7DAY"];

   cfg = struct('products', struct('name', {}, 'eff', {}, 'vals', {}, ...
      'leadmax', {}, 'step', {}, 'n_col', {}), 'names', name, ...
      'window', int64([0 0]));

   lo = int64(inf);  hi = int64(-inf);
   for p = 1:numel(src)
      assert(isfile(src(p)), 'official_composite_load:missing_file', ...
         'no file at %s', src(p));
      [eff, tgt, rrp] = read_product(src(p), name(p));
      step_p = int64(step(p));

      lag = tgt - eff;
      assert(all(mod(lag, step_p) == 0), 'official_composite_load:grid', ...
         '%s carries targets off its own %d-minute grid', name(p), step(p));
      assert(all(lag >= 0), 'official_composite_load:negative_lead', ...
         '%s carries a target before its own effective time', name(p));

      u_eff = unique(eff);
      [~, k] = ismember(eff, u_eff);
      n_run = numel(u_eff);
      n_col = double(max(lag) / step_p) + 1;

      vals = nan(n_run, n_col);
      leadmax = zeros(n_run, 1, 'int64');
      col = double(lag / step_p) + 1;
      lin = (k - 1) * n_col + col;
      assert(numel(unique(lin)) == numel(lin), 'official_composite_load:dup', ...
         '%s repeats a (run, target) pair', name(p));
      vals(lin) = rrp;
      for j = 1:n_run
         leadmax(j) = max(lag(k == j));
      end

      cfg.products(p) = struct('name', name(p), 'eff', u_eff, 'vals', vals, ...
         'leadmax', leadmax, 'step', step_p, 'n_col', n_col);
      fprintf("  %-12s %6d runs, %6d columns, leadmax %5.1f to %5.1f h, %6d rows\n", ...
         name(p), n_run, n_col, double(min(leadmax))/60, double(max(leadmax))/60, numel(rrp));
      lo = min(lo, min(u_eff));  hi = max(hi, max(u_eff));
   end
   cfg.window = [lo hi];

   fprintf("  indexed window %s to %s, NEM time\n", ...
      datestr(double(lo)/1440 + datenum(2025,1,1), 'yyyy-mm-dd HH:MM'), ...
      datestr(double(hi)/1440 + datenum(2025,1,1), 'yyyy-mm-dd HH:MM'));
end

function p = pick_dir(root, names)
   % The first of `names` that exists under `root`. Raises when none does, and
   % says which names it tried, because "no file at ..." on the fourth path is
   % not enough to tell a rename from a missing window.
   for i = 1:numel(names)
      cand = fullfile(root, names(i));
      if isfolder(cand)
         p = cand;
         return;
      end
   end
   error('official_composite_load:no_window', ...
      'no data window under %s; tried %s', root, strjoin(names, ", "));
end


function [eff, tgt, rrp] = read_product(path, name)
   % One product file, three columns only. Column 1 is the effective time and
   % column 3 the target time in all three files; RRP sits in column 4 for
   % P5MIN and column 5 for the two 30-minute products.
   fid = fopen(path, 'r');
   assert(fid > 0, 'official_composite_load:open', 'cannot open %s', path);
   c = textscan(fid, '%s %s %s %s %s %s %s %s %s %s', 'Delimiter', ',', ...
      'HeaderLines', 1, 'ReturnOnError', false);
   fclose(fid);
   if name == "P5MIN"
      rrp_col = 4;
   else
      rrp_col = 5;
   end
   eff = nem_minutes(c{1});
   tgt = nem_minutes(c{3});
   rrp = str2double(c{rrp_col});
   assert(~any(isnan(rrp)), 'official_composite_load:rrp', ...
      '%s has a non-numeric RRP', name);
   fprintf("  read %-12s %8d rows from %s\n", name, numel(rrp), ...
      string(path(strfind(path, "window_60d"):end)));
end
