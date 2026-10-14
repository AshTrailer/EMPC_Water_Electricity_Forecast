function [y_hat, r_hat, t_vec] = predict_template_ar(st, origin_slot, horizon)
   % PREDICT_TEMPLATE_AR  Forecast of "rolling template + intraday AR(p)"
   %
   %    y_hat(u) = T(u) + r_hat(u)
   %    T(u)     : current rolling per-slot template of target slot u
   %    r_hat(u) : recursive (iterated) AR(p) forecast of the residual,
   %               started from st.hist = [r(t-1); ...; r(t-p)]
   %               (CONSECUTIVE intraday lags). At short leads the AR
   %               chases the current residual level; at long leads the
   %               recursion decays toward 0 and y_hat converges to the
   %               pure template.
   %
   %    r_hat and t_vec are returned separately so the blend predictors
   %    can reuse the components without recomputing them.
   %
   %    Before st.n_hist reaches p there are not enough regressors, so
   %    r_hat = 0 (pure template forecast).

   arguments
      st struct
      origin_slot (1,1) double
      horizon (:,1) double
   end

   if isscalar(horizon)
      steps = (1:horizon)';
   else
      steps = horizon(:);
   end

   u = target_slots(origin_slot, steps, st.n_slots);
   t_vec = st.sum(u) ./ max(st.cnt(u), 1);

   r_hat = zeros(numel(steps), 1);
   if st.n_hist >= st.p
      buf = st.hist;                 % newest first
      full = zeros(max(steps), 1);
      for k = 1:max(steps)
         full(k) = st.phi' * buf;
         buf = [full(k); buf(1:end-1)];
      end
      r_hat = full(steps);
   end
   y_hat = t_vec + r_hat;
end