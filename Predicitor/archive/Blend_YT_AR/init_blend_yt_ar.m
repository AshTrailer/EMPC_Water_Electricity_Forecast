function bl = init_blend_yt_ar(n_slots, rls_lambda, rls_delta)
   % INIT_BLEND_YT_AR  Initialize blend B: w*[theta*y_yesterday] + (1-w)*rhat
   %
   %    Same convex per-slot structure as blend A, but the first component
   %    is the yesterday-tracking forecast theta(s)*y(s, -1 day) instead
   %    of the template. Component 2 is the per-slot cross-day AR residual
   %    forecast rhat. w = theta_1, theta_2 = 1 - w, clipped to [0, 1].

   arguments
      n_slots (1,1) double
      rls_lambda (1,1) double = 0.98
      rls_delta (1,1) double = 100
   end

   bl.n_slots = n_slots;
   bl.lambda = rls_lambda;
   bl.w = 0.5 * ones(n_slots, 1);
   bl.P = rls_delta * ones(n_slots, 1);
end