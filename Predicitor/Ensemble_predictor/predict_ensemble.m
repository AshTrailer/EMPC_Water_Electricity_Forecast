function y_hat = predict_ensemble(F, W)
   % PREDICT_ENSEMBLE  Convex combination of the sub-model forecasts
   %
   %    y_hat(p) = sum_m W(p,m) F(m,p)
   %
   %    The same call also gives the combined error, because for any weights
   %    summing to one the error of the combination is the same combination of
   %    the errors:
   %       e_c = y - sum_m w_m f_m = sum_m w_m (y - f_m) = sum_m w_m e_m
   %    so a caller that holds errors instead of forecasts may pass those.
   %
   %    Input:
   %       F - (n_models x n_point) sub-model forecasts
   %       W - either a vector of n_models weights, applied to every point, or
   %           (n_point x n_models), a row of weights per point, which is what
   %           the selective equal-weight rule produces because it chooses the
   %           models separately for every lead
   %    Output:
   %       y_hat - (1 x n_point) combined value

   arguments
      F (:,:) double
      W (:,:) double
   end

   n_m = size(F,1);
   n_p = size(F,2);

   if numel(W) == n_m
      % one weight per sub-model, same for every point
      w = W(:);
      assert(abs(sum(w) - 1) < 1e-9, 'weights must sum to one, they sum to %.6f', sum(w));
      y_hat = w' * F;
      return
   end

   assert(size(W,2) == n_m, ...
      'weights have %d columns but there are %d sub-models', size(W,2), n_m);
   assert(size(W,1) == n_p, ...
      'weights have %d rows, expected one row per point, %d', size(W,1), n_p);
   rs = sum(W, 2);
   assert(max(abs(rs - 1)) < 1e-9, 'every weight row must sum to one');
   y_hat = sum(W' .* F, 1);
end
