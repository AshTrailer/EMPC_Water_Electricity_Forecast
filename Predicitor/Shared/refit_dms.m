function D = refit_dms(series, last, n_fit, pmax, h_step)
   % REFIT_DMS  Direct multi-step OLS on a trailing window, one row per lead
   %
   %    For every lead h, fits
   %
   %       series(k+h) = D_h * [1, series(k), ..., series(k-pmax+1)]'
   %
   %    over k in the trailing n_fit samples that still have a target available.
   %    No recursion is propagated, so a misspecified model cannot diverge with
   %    the lead; the cost is that a long lead has far fewer usable rows.
   %
   %    The lead list is explicit rather than a count, because the atlas axis
   %    stops being every step once it leaves the first hour: the first eleven
   %    leads are consecutive 5-minute steps, the rest are every sixth step out
   %    to 183 hours. A scalar behaves exactly as a count always did.
   %
   %    Input:
   %       series - (N x 1) the series to regress on, already clamped
   %       last   - index of the fit origin, the newest usable regressor row
   %       n_fit  - fit window length in samples
   %       pmax   - number of lags
   %       h_step - (n_h x 1) leads in steps, default 1..288
   %    Output:
   %       D - (n_h x (pmax+1)) coefficient rows. A row is left at zero when
   %           fewer than 50 usable samples remain, which only happens when the
   %           lead reaches further back than the window is long.
   %
   %    See also FIT_ANCHOR_MIX, OFFICIAL_LEAD_AXIS.

   arguments
      series (:,1) double
      last (1,1) double
      n_fit (1,1) double
      pmax (1,1) double
      h_step (:,1) double = (1:288)'
   end

   n_h = numel(h_step);
   k_lo = max(pmax+2, last - n_fit + 1);
   k = (k_lo:last)';
   B = ones(numel(k), pmax+1);
   for j = 0:pmax-1
      B(:, 2+j) = series(k - j);
   end

   D = zeros(n_h, pmax+1);
   for hi = 1:n_h
      h = h_step(hi);
      m = k <= (last - h);
      X = B(m,:);  tgt = series(k(m) + h);
      good = all(isfinite(X),2) & isfinite(tgt);
      X = X(good,:);  tgt = tgt(good);
      if size(X,1) >= 50
         D(hi,:) = (X \ tgt)';
      end
   end
end
