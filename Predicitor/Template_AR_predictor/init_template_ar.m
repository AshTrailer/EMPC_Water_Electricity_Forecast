function st = init_template_ar(n_slots, p, tpl_window, rls_lambda, rls_delta)
   % INIT_TEMPLATE_AR  Initialize "rolling template + intraday AR(p)" predictor
   %
   %    Template T(s): pointwise rolling mean of the same slot over the
   %    last `tpl_window` days. Each time slot s's true value arrives,
   %    T(s) is updated pointwise (evict the oldest sample, insert the
   %    new one), so the template always reflects the most recent days.
   %
   %    Residual AR: ONE intraday AR(p) on the residual series
   %        r(t) = y(t) - T_t(s_t),   T_t = template value before update
   %    with CONSECUTIVE regressors (short-term tracking):
   %        r(t) = phi' * [r(t-1); r(t-2); ...; r(t-p)] + e
   %    phi is updated by vector RLS (forgetting factor rls_lambda) at
   %    every 5-min step, i.e. every time a new observation arrives.
   %
   %    Design rationale: same-slot values 24 h apart are nearly
   %    uncorrelated (tested: the cross-day per-slot AR added no skill),
   %    so cross-day regressors were removed. All cross-day memory lives
   %    in the template; the AR only chases the current intraday level.
   %
   %    Recursive 288-step forecasts start from st.hist (newest first)
   %    and decay toward 0, so yhat = T + rhat converges to the pure
   %    template as the lead time grows.
   %
   %    st.phi    - AR coefficients (p x 1)
   %    st.hist   - last p residuals [r(t-1); ...; r(t-p)], newest first
   %    st.n_hist - number of residuals stored so far (0..p)

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

   % rolling per-slot template state
   st.sum = zeros(n_slots, 1);
   st.cnt = zeros(n_slots, 1);
   st.win = zeros(n_slots, tpl_window);

   % intraday residual AR state (consecutive lags)
   st.phi    = zeros(p, 1);
   st.hist   = zeros(p, 1);
   st.n_hist = 0;
   st.P      = rls_delta * eye(p);
end