function tracker = update_theta_tracker(tracker, slot, y_true)
   % UPDATE_THETA_TRACKER  One slot update of the yesterday-tracking gain
   %
   %    Called when the true price of `slot` arrives. The RLS target is
   %    today's value y_true and the regressor is the same slot's value
   %    from yesterday (tracker.y_prev(slot)). Afterwards y_prev(slot) is
   %    overwritten with y_true, so the regressor always lags one day and
   %    theta(s) is updated at most once per day per slot.
   %
   %    The update is skipped on the very first pass of a slot, when no
   %    previous-day value exists yet.

   arguments
      tracker struct
      slot (1,1) double
      y_true (1,1) double
   end

   if tracker.has_prev(slot)
      x = tracker.y_prev(slot);
      [th, P, ~] = rls_scalar_step(y_true, x, tracker.theta(slot), tracker.P(slot), tracker.lambda);
      tracker.theta(slot) = th;
      tracker.P(slot) = P;
   end

   tracker.y_prev(slot) = y_true;
   tracker.has_prev(slot) = true;
end