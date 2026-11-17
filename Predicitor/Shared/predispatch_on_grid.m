function [X, info] = predispatch_on_grid(V, eff_r, t0, days, cols, lead, n_s)
   % PREDISPATCH_ON_GRID  What the run published at the origin carried for a target
   %
   %    A cube cell is addressed by its target, so the run that supplies it is
   %    the last one published at or before the origin, with origin = target
   %    minus lead. Targets sit on the 5-minute grid and PREDISPATCH products on
   %    the 30-minute one, so the two bracketing horizon columns are interpolated.
   %    V carries one value per (run, horizon column), so it may be a price, a
   %    demand, or anything derived from a completed run by horizon matrix.
   %
   %    The next column is used only when it exists. Writing the blend as
   %    base + frac * (next - base) would poison the cell with NaN whenever the
   %    run stops one column short, including the frac = 0 case, because zero
   %    times NaN is NaN. That is why the blend is masked here.
   %
   %    Input:
   %       V     - (n_run x n_col) values, NaN where the run does not reach
   %       eff_r - (n_run x 1) effective times in NEM minutes, ascending
   %       t0    - NEM minutes at 00:00 of day 1
   %       days  - day indices into the window, 1-based
   %       cols  - which lead columns are wanted
   %       lead  - full lead axis in minutes
   %       n_s   - slots per day
   %    Output:
   %       X     - (n_s x numel(cols) x numel(days)), NaN where no run reaches
   %       info  - counts that explain the missing cells
   %
   %    See also PREDISPATCH_DEMAND_LOAD, PREDISPATCH_SENS_LOAD.

   arguments
      V double
      eff_r
      t0 double
      days double
      cols double
      lead double
      n_s double
   end

   eff_r = double(eff_r(:));
   n_c = numel(cols);
   n_d = numel(days);
   n_col = size(V, 2);
   X = nan(n_s, n_c, n_d);
   info = struct("no_run", 0, "no_base", 0, "no_next_frac", 0, "held_frac0", 0, ...
      "filled", 0, "total", n_s * n_c * n_d);

   for j = 1:n_c
      L = lead(cols(j));
      for i = 1:n_d
         tgt = t0 + (days(i) - 1) * 1440 + 5 * (0:n_s-1)';
         org = tgt - L;
         k = sum(eff_r' <= org, 2);              % last run at or before the origin
         ok = k > 0;
         info.no_run = info.no_run + sum(~ok);
         if ~any(ok), continue; end
         kk = k(ok);
         colf = (tgt(ok) - eff_r(kk)) / 30;
         c0 = floor(colf);
         fr = colf - c0;
         base = V(sub2ind(size(V), kk, c0 + 1));
         nxt = nan(size(base));
         in2 = (c0 + 2) <= n_col;
         nxt(in2) = V(sub2ind(size(V), kk(in2), c0(in2) + 2));

         v = base;
         use2 = isfinite(nxt) & (fr > 0);
         v(use2) = base(use2) + fr(use2) .* (nxt(use2) - base(use2));
         info.no_base = info.no_base + sum(~isfinite(base));
         info.no_next_frac = info.no_next_frac + sum(~isfinite(nxt) & (fr > 0) & isfinite(base));
         info.held_frac0 = info.held_frac0 + sum(~isfinite(nxt) & (fr == 0) & isfinite(base));
         X(ok, j, i) = v;
      end
   end
   info.filled = sum(isfinite(X), "all");
end
