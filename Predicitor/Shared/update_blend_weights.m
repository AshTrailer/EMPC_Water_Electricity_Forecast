function bl = update_blend_weights(bl, slot, y_true, x1, x2)
   % UPDATE_BLEND_WEIGHTS  Adapt the convex-blend weight of one slot
   %
   %    Model:   yhat = w*x1 + (1-w)*x2,   w in [0, 1]
   %    Rewritten as  yhat - x2 = w * (x1 - x2), so a scalar RLS with
   %    regressor d = x1 - x2 and target y_true - x2 directly tracks the
   %    single free parameter; clipping w to [0, 1] keeps the combination
   %    convex (theta_1 + theta_2 = 1 exactly).
   %
   %    x1/x2 are the two component forecasts that were available one
   %    step before the slot's true value arrived (the 1-step-ahead pair
   %    issued by the previous forecast origin).
   %
   %    Shared by blend A (x1 = template, x2 = residual AR forecast) and
   %    blend B (x1 = theta-tracker forecast, x2 = residual AR forecast).

   arguments
      bl struct
      slot (1,1) double
      y_true (1,1) double
      x1 (1,1) double
      x2 (1,1) double
   end

   d = x1 - x2;
   if abs(d) < 1e-9
      return;   % components identical -> no information about w
   end

   [w, P, ~] = rls_scalar_step(y_true - x2, d, bl.w(slot), bl.P(slot), bl.lambda);
   bl.w(slot) = min(max(w, 0), 1);
   bl.P(slot) = P;
end