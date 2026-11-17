function [value, src, age_min, target_min, src_name, allv] = official_composite(origin, lead_min, cfg)
   % OFFICIAL_COMPOSITE  The official forecast as it stood at one origin
   %
   %    One origin in, one forecast vector out, using only runs published at or
   %    before that origin. This is the callable form; BUILD_OFFICIAL_ATLAS
   %    evaluates it on every origin of a window and stores the cube.
   %
   %    Product order is fixed: P5MIN up to its horizon, then PREDISPATCH, then
   %    PD7DAY. The first product whose newest run at or before the origin
   %    contains the target interval supplies the value, and the product that
   %    supplied it is returned alongside.
   %
   %    Target convention. Official timestamps are the END of the interval they
   %    describe, and so is the actual price series. Inside the first hour the
   %    target is the origin plus the lead, straight through. From one hour out
   %    both 30-minute products live on the :00/:30 grid, so the target is
   %    folded UP onto it, which selects the half-hour interval the target
   %    sits inside. Folding down would return the interval that closes before
   %    the target, which is not the interval the target belongs to.
   %
   %    Input:
   %       origin   - one NEM timestamp, datetime or 'yyyy-mm-dd HH:MM:SS'
   %       lead_min - (n x 1) forecast lead in minutes, from OFFICIAL_LEAD_AXIS
   %       cfg      - from OFFICIAL_COMPOSITE_LOAD
   %    Output:
   %       value      (n x 1) $/MWh, NaN where no run reached that target
   %       src        (n x 1) index into cfg.names, 0 where no run reached it
   %       age_min    (n x 1) age of the supplying run at the origin, minutes
   %       target_min (n x 1) int64, the target interval end in NEM minutes
   %       src_name   (n x 1) string, cfg.names(src) or "" where none
   %       allv       (n x n_prod) the same target priced by EVERY product that
   %                  reaches it, not only the one that won. The sixth output
   %                  exists for one question: whether two products agree where
   %                  their horizons overlap. The chosen value alone cannot
   %                  answer it, because the selection never keeps both.
   %
   %    See also OFFICIAL_COMPOSITE_LOAD, OFFICIAL_LEAD_AXIS, NEM_MINUTES.

   arguments
      origin
      lead_min (:,1) double
      cfg struct
   end

   O = nem_minutes(origin);
   assert(isscalar(O), 'official_composite:origin', ...
      'origin must be a single timestamp, got %d', numel(O));

   L = int64(round(lead_min(:)));
   assert(all(L > 0), 'official_composite:lead', 'every lead must be positive');

   T = O + L;
   band = L >= 60;
   T(band) = T(band) + mod(-T(band), int64(30));

   n = numel(L);
   value = nan(n, 1);
   src = zeros(n, 1);
   age_min = nan(n, 1);
   allv = nan(n, numel(cfg.products));

   for p = 1:numel(cfg.products)
      todo = find(src == 0);
      pr = cfg.products(p);
      k = find(pr.eff <= O, 1, 'last');
      if isempty(k), continue; end

      d = T - pr.eff(k);
      ok = (d >= 0) & (d <= pr.leadmax(k)) & (mod(d, pr.step) == 0);
      if ~any(ok), continue; end

      col = double(d(ok)) / double(pr.step) + 1;
      v = pr.vals((k - 1) * pr.n_col + col);
      good = isfinite(v);

      sel = find(ok);
      sel = sel(good);
      allv(sel, p) = v(good);

      if isempty(todo), continue; end
      hit = ismember(sel, todo);
      sel = sel(hit);
      value(sel) = v(hit);
      src(sel) = p;
      % Age is how old the supplying run is AT THE ORIGIN. That is not the
      % row's lead from that run: the two differ by exactly that lead, and
      % reporting the lead instead would make a 24-hour target look like a
      % 24-hour-old run when the run may be minutes old.
      age_min(sel) = double(O - pr.eff(k));
   end

   target_min = T;
   src_name = strings(n, 1);
   hit = src > 0;
   src_name(hit) = cfg.names(src(hit));
end
