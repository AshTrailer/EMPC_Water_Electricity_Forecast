function C = fit_anchor_mix(y_series, d_series, r_series, T_snap, day_of, k_last, L, p, convex, shrink)
   % FIT_ANCHOR_MIX  Direct multi-step fit of the anchor-mix price predictor
   %
   %    Free form (convex = false), for every lead h independently:
   %
   %       y(k+h) = c_h + a_h*y(k) + b_h*T + sum_j phi_hj*r(k-j+1)
   %                                         + sum_j psi_hj*Dy(k-j+1)
   %
   %    Convex form (convex = true) imposes the anchor weights to be a
   %    convex combination, first algebraically and then by projection:
   %
   %       b_h = 1 - a_h,   a_h in [0, 1]
   %       y(k+h) - T = c_h + a_h*(y(k) - T) + sum_j phi*r + sum_j psi*Dy
   %       a_h <- clip(a_h, 0, 1)
   %
   %    without the constraint, unconstrained least squares on 11 collinear
   %    regressors drives a_h + b_h to 1.117 at the 6 h lead and b_h negative
   %    at 24 h, which is what makes the forecast look like a shifted copy of
   %    the actual.  The convex form removes both.
   %
   %    shrink scales a ridge penalty on the lag coefficients only (the two
   %    anchors and the intercept are left free), expressed as a fraction of
   %    the mean column energy so it does not depend on the price units.
   %
   %    Input:
   %       y_series - clamped price series over the whole stream
   %       d_series - first difference of that series
   %       r_series - residual series y - T (NaN before a slot is first seen)
   %       T_snap   - (n_slots x n_cols) template snapshot per stream position
   %       day_of   - (n_seq x 1) column of T_snap that applies to each position
   %       k_last   - index of the last observed point (the fit origin)
   %       L        - fit window length in samples (14 days)
   %       p        - number of residual and difference lags
   %       convex   - impose b = 1 - a with a in [0, 1]
   %       shrink   - ridge weight on the lag coefficients (0 = no penalty)
   %    Output:
   %       C - (288 x (2*p+3)) coefficient rows, one per lead

   arguments
      y_series (:,1) double
      d_series (:,1) double
      r_series (:,1) double
      T_snap (:,:) double
      day_of (:,1) double
      k_last (1,1) double
      L (1,1) double
      p (1,1) double = 4
      convex (1,1) logical = false
      shrink (1,1) double = 0
   end

   n_h = 288;
   k_lo = max(p+2, k_last - L + 1);
   k = (k_lo:k_last)';
   n_base = 2*p + 3;
   C = zeros(n_h, n_base);

   for h = 1:n_h
      m = k <= (k_last - h);
      kk = k(m);
      if numel(kk) < 50
         continue
      end
      tgt_slot = mod(mod(kk - 1, 288) + h - 1, 288) + 1;
      tpl_val = T_snap(sub2ind(size(T_snap), tgt_slot, day_of(kk)));

      X = zeros(numel(kk), n_base);
      X(:,1) = 1;
      X(:,2) = y_series(kk);
      X(:,3) = tpl_val;
      for j = 1:p
         X(:,3+j)   = r_series(kk - j + 1);
         X(:,3+p+j) = d_series(kk - j + 1);
      end
      tgt = y_series(kk + h);
      good = all(isfinite(X),2) & isfinite(tgt);
      if sum(good) < 50
         continue
      end
      X = X(good,:);  tgt = tgt(good);  tpl = tpl_val(good);

      if convex
         % target and anchor gap are taken relative to the target template
         Xc = [ones(size(X,1),1), y_series(kk(good)) - tpl, X(:,4:end)];
         yc = tgt - tpl;
         if shrink > 0
            lam = shrink * mean(sum(Xc(:,3:end).^2, 1));
            n_extra = size(Xc,2) - 2;
            Xc = [Xc; [zeros(n_extra,2), sqrt(lam)*eye(n_extra)]];
            yc = [yc; zeros(n_extra,1)];
         end
         cf = Xc \ yc;
         cf(2) = min(max(cf(2), 0), 1);
         C(h,1)   = cf(1);
         C(h,2)   = cf(2);
         C(h,3)   = 1 - cf(2);
         C(h,4:end) = cf(3:end);
      else
         C(h,:) = (X \ tgt)';
      end
   end
end
