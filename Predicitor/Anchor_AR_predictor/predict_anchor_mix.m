function y_hat = predict_anchor_mix(D, y_now, T_tgt, r_hist, dy_hist)
   % PREDICT_ANCHOR_MIX  One n_s-step forecast from the anchor-mix coefficients
   %
   %    y_hat(h) = D(h,:) * [1, y_now, T_tgt(h), r_hist', dy_hist']'
   %
   %    Notation follows section 2 of
   %    Weekly/2026-10-13/HANDOVER_预测器整理与全跨度比较_20261013.md.
   %       D        coefficient rows from fit_anchor_mix, written D_h there
   %       y_now    y(k), the clamped price of the newest observed interval
   %       T_tgt    (n_s x 1) T(u(k,h)), the template at the 288 target slots
   %       r_hist   (p x 1) newest-first residuals, [r(k), r(k-1), ...]
   %       dy_hist  (p x 1) newest-first differences, [Dy(k), Dy(k-1), ...]
   %
   %    Direct multi-step: no recursion is propagated, so a misspecified
   %    residual model cannot diverge over the horizon.

   arguments
      D (:,:) double
      y_now (1,1) double
      T_tgt (:,1) double
      r_hist (:,1) double
      dy_hist (:,1) double
   end

   p = numel(r_hist);
   assert(numel(dy_hist) == p, 'r_hist and dy_hist must have equal length');
   assert(size(D,2) == 2*p + 3, 'coefficient row width does not match lag count');
   h = size(D,1);
   X = [ones(h,1), repmat(y_now,h,1), T_tgt, ...
        repmat(r_hist(:)', h, 1), repmat(dy_hist(:)', h, 1)];
   y_hat = sum(D .* X, 2);
end
