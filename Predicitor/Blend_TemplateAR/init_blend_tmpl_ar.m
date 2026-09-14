function bl = init_blend_tmpl_ar(n_slots, rls_lambda, rls_delta)
   % INIT_BLEND_TMPL_AR  Initialize blend A: w*T + (1-w)*rhat (convex, per slot)
   %
   %    Each slot s owns one free weight w(s) = theta_1(s), with
   %    theta_2(s) = 1 - w(s), so the combination is always convex.
   %    w is adapted by scalar RLS on regressor d = T - rhat and target
   %    y - rhat, then clipped to [0, 1]. The update uses the 1-step-ahead
   %    component pair that was available before the slot's true value
   %    arrived. The idea: when the AR residual struggles mid-day but the
   %    template matches well, w moves toward 1 (trust the template more).

   arguments
      n_slots (1,1) double
      rls_lambda (1,1) double = 0.98
      rls_delta (1,1) double = 100
   end

   bl.n_slots = n_slots;
   bl.lambda = rls_lambda;
   bl.w = 0.5 * ones(n_slots, 1);      % start from an equal blend
   bl.P = rls_delta * ones(n_slots, 1);
end