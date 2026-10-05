function tracker = init_theta_tracker(n_slots, rls_lambda, rls_delta)
   % INIT_THETA_TRACKER  Initialize the per-slot "yesterday-tracking" predictor
   %
   %    Model:  yhat(t+h|t) = theta(s+h) * y(s+h - 288)
   %    where s+h is the target slot and y(s+h-288) is the raw price of
   %    the same slot on the previous day. Each slot keeps its own scalar
   %    gain theta(s), updated by scalar RLS (forgetting factor
   %    rls_lambda) only when the slot's true value arrives, i.e. once
   %    per day per slot with a 24 h lag. The prior theta = 1 recovers
   %    the persistence baseline.
   %
   %    Inputs:
   %       n_slots    - number of 5-min slots per day (288)
   %       rls_lambda - RLS forgetting factor (0.98)
   %       rls_delta  - initial RLS covariance scale
   %    Output:
   %       tracker    - struct: .theta, .P, .y_prev, .has_prev, .lambda

   arguments
      n_slots (1,1) double
      rls_lambda (1,1) double = 0.98
      rls_delta  (1,1) double = 100
   end

   tracker.n_slots = n_slots;
   tracker.lambda  = rls_lambda;
   tracker.theta   = ones(n_slots, 1);        % prior: yesterday's value
   tracker.P       = rls_delta * ones(n_slots, 1);
   tracker.y_prev  = zeros(n_slots, 1);       % yesterday's raw price per slot
   tracker.has_prev = false(n_slots, 1);
end