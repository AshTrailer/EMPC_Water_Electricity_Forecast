function y_hat = predict_blend(w, x1_vec, x2_vec)
   % PREDICT_BLEND  Convex combination of two component forecast vectors
   %
   %    y_hat = w .* x1 + (1 - w) .* x2, with w indexed by target slot.
   %    The caller passes the per-target-slot weight vector w(u).

   arguments
      w (:,1) double
      x1_vec (:,1) double
      x2_vec (:,1) double
   end

   assert(numel(w) == numel(x1_vec) && numel(x1_vec) == numel(x2_vec), ...
      'Weight and component vectors must have equal length');

   y_hat = w .* x1_vec + (1 - w) .* x2_vec;
end