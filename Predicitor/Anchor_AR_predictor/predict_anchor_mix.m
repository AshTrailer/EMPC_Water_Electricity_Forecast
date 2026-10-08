function y_hat = predict_anchor_mix(C, y_now, t_vec, r_hist, d_hist)
   % PREDICT_ANCHOR_MIX  One 288-step forecast from the anchor-mix coefficients
   %
   %    y_hat(h) = C(h,:) * [1, y_now, t_vec(h), r_hist', d_hist']'
   %
   %    C        - coefficient rows from fit_anchor_mix
   %    y_now    - clamped price of the newest observed interval
   %    t_vec    - (288 x 1) template values of the 288 target slots
   %    r_hist   - (p x 1) newest-first residuals [r(k), r(k-1), ...]
   %    d_hist   - (p x 1) newest-first differences
   %
   %    Direct multi-step: no recursion is propagated, so a misspecified
   %    residual model cannot diverge over the horizon.

   arguments
      C (:,:) double
      y_now (1,1) double
      t_vec (:,1) double
      r_hist (:,1) double
      d_hist (:,1) double
   end

   p = numel(r_hist);
   assert(numel(d_hist) == p, 'r_hist and d_hist must have equal length');
   assert(size(C,2) == 2*p + 3, 'coefficient row width does not match lag count');
   h = size(C,1);
   X = [ones(h,1), repmat(y_now,h,1), t_vec, ...
        repmat(r_hist(:)', h, 1), repmat(d_hist(:)', h, 1)];
   y_hat = sum(C .* X, 2);
end
