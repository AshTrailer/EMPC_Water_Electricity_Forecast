function D = fit_anchor_mix(y_series, dy_series, r_series, T_hist, d_col, k_last, n_fit, p, convex, eta, h_step)
   % FIT_ANCHOR_MIX  Direct multi-step fit of the anchor-mix price predictor
   %
   %    Notation follows section 2 of
   %    Weekly/2026-10-13/HANDOVER_预测器整理与全跨度比较_20261013.md.
   %       y_series   clamped price y_c over the whole stream
   %       dy_series  Dy, its first difference
   %       r_series   residual r = y - T, NaN before a slot is first seen
   %       T_hist     (n_s x n_col) template snapshot per stream position
   %       d_col      (n_seq x 1) column of T_hist that applies to each position
   %       k_last     index of the last observed point, the fit origin
   %       n_fit      fit window length in samples
   %       p          number of residual and difference lags
   %       convex     impose b_h = 1 - a_h with a_h in [0, 1]
   %       eta        ridge weight on the lag coefficients, 0 = no penalty
   %    Output:
   %       D  (n_s x (2*p+3)) coefficient rows, one per lead h
   %
   %    Free form, for every lead h independently:
   %
   %       y(k+h) = c_h + a_h*y(k) + b_h*T + sum_j phi_hj*r(k-j+1)
   %                                         + sum_j psi_hj*Dy(k-j+1)
   %
   %    Convex form imposes the anchor weights to be a convex combination,
   %    first algebraically and then by projection:
   %
   %       b_h = 1 - a_h,   a_h in [0, 1]
   %       y(k+h) - T = c_h + a_h*(y(k) - T) + sum_j phi*r + sum_j psi*Dy
   %       a_h <- clip(a_h, 0, 1)
   %
   %    Without the constraint, unconstrained least squares on 11 collinear
   %    regressors drives a_h + b_h to 1.117 at the 6 h lead and b_h negative
   %    at 24 h, which is what makes the forecast look like a shifted copy of
   %    the actual. The convex form removes both.
   %
   %    eta scales a ridge penalty on the lag coefficients only, the two
   %    anchors and the intercept are left free, expressed as a fraction of
   %    the mean column energy so it does not depend on the price units.

   arguments
      y_series (:,1) double
      dy_series (:,1) double
      r_series (:,1) double
      T_hist (:,:) double
      d_col (:,1) double
      k_last (1,1) double
      n_fit (1,1) double
      p (1,1) double = 4
      convex (1,1) logical = false
      eta (1,1) double = 0
      h_step (:,1) double = (1:288)'
   end

   n_h = numel(h_step);
   n_slots = size(T_hist, 1);
   k_lo = max(p+2, k_last - n_fit + 1);
   k = (k_lo:k_last)';
   n_base = 2*p + 3;
   D = zeros(n_h, n_base);

   for hi = 1:n_h
      h = h_step(hi);
      m = k <= (k_last - h);
      kk = k(m);
      if numel(kk) < 50
         continue
      end
      tgt_slot = mod(mod(kk - 1, n_slots) + h - 1, n_slots) + 1;
      tpl_val = T_hist(sub2ind(size(T_hist), tgt_slot, d_col(kk)));

      X = zeros(numel(kk), n_base);
      X(:,1) = 1;
      X(:,2) = y_series(kk);
      X(:,3) = tpl_val;
      for j = 1:p
         X(:,3+j)   = r_series(kk - j + 1);
         X(:,3+p+j) = dy_series(kk - j + 1);
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
         if eta > 0
            ridge = eta * mean(sum(Xc(:,3:end).^2, 1));
            n_extra = size(Xc,2) - 2;
            Xc = [Xc; [zeros(n_extra,2), sqrt(ridge)*eye(n_extra)]];
            yc = [yc; zeros(n_extra,1)];
         end
         cf = Xc \ yc;
         cf(2) = min(max(cf(2), 0), 1);
         D(hi,1)   = cf(1);
         D(hi,2)   = cf(2);
         D(hi,3)   = 1 - cf(2);
         D(hi,4:end) = cf(3:end);
      else
         D(hi,:) = (X \ tgt)';
      end
   end
end
