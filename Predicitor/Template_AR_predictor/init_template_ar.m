function st = init_template_ar(n_slots, p, tpl_window, rls_lambda, rls_delta)
   % INIT_TEMPLATE_AR  Initialize "rolling template + per-slot cross-day AR(p)"
   %
   %    Template T(s): pointwise rolling mean of the same slot over the
   %    last `tpl_window` days. Every time slot s arrives, T(s) is updated
   %    with the new observation and the oldest one is evicted.
   %
   %    Residual AR: each slot s owns an independent AR(p) whose
   %    regressors are the same slot's residuals on the previous p days
   %    (cross-day, NOT consecutive intraday lags):
   %        r(s, d) = phi(s)' * [r(s, d-1); ...; r(s, d-p)] + e
   %    Coefficients are updated by RLS (forgetting factor rls_lambda)
   %    once per day, when slot s's true value arrives.
   %
   %    st.r_hist(s, k) holds the residual of slot s k days ago (k=1..p).

   arguments
      n_slots (1,1) double
      p (1,1) double = 4
      tpl_window (1,1) double = 28
      rls_lambda (1,1) double = 0.98
      rls_delta (1,1) double = 100
   end

   st.n_slots = n_slots;
   st.p = p;
   st.window = tpl_window;
   st.lambda = rls_lambda;

   st.sum = zeros(n_slots, 1);
   st.cnt = zeros(n_slots, 1);
   st.win = zeros(n_slots, tpl_window);

   st.r_hist = zeros(n_slots, p);
   st.r_cnt  = zeros(n_slots, 1);
   st.theta  = zeros(n_slots, p);
   st.theta(:, 1) = 1;                % prior: r(d) ~ r(d-1)
   st.P = cell(n_slots, 1);
   for s = 1:n_slots
      st.P{s} = rls_delta * eye(p);
   end
end