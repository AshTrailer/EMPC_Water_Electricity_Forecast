function [y_hat, r_hat, t_vec] = predict_template_ar(st, origin_slot, horizon)
   % PREDICT_TEMPLATE_AR  Forecast of "rolling template + per-slot AR(p)"
   %
   %    y_hat(u) = T(u) + r_hat(u)
   %    T(u)     : current rolling per-slot template (same-slot mean)
   %    r_hat(u) : per-slot cross-day AR(p) direct forecast of the residual
   %               r_hat(u) = phi(u)' * r_hist(u, 1:p)
   %    All regressors are already observed (previous days' same-slot
   %    residuals), so no intraday recursion is needed and the estimation
   %    and prediction regressors are exactly the same.
   %
   %    r_hat and t_vec are returned separately so the blend predictors
   %    can reuse the components without recomputing them.

   arguments
      st struct
      origin_slot (1,1) double
      horizon (1,1) double
   end

   u = target_slots(origin_slot, horizon, st.n_slots);
   t_vec = st.sum(u) ./ max(st.cnt(u), 1);
   r_hat = sum(st.theta(u, :) .* st.r_hist(u, :), 2);
   y_hat = t_vec + r_hat;
end