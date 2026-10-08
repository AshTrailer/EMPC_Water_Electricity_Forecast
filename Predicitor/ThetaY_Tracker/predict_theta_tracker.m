function y_hat = predict_theta_tracker(tracker, origin_slot, horizon)
   % PREDICT_THETA_TRACKER  Per-slot theta-y forecast of the next `horizon` points
   %
   %    y_hat(u) = theta(u) * y_prev(u)
   %
   %    theta(u) is the scalar RLS gain of the target slot, y_prev(u) the same
   %    slot's value from the previous day. The forecast is lead-time
   %    independent: every target point uses its own slot's gain and its own
   %    yesterday value.
   %
   %    Input:
   %       tracker     - state from init_theta_tracker
   %       origin_slot - slot of the forecast origin (1..n_slots)
   %       horizon     - number of steps to forecast (288)
   %    Output:
   %       y_hat - (horizon x 1); y_hat(h) belongs to target slot u(h)

   arguments
      tracker struct
      origin_slot (1,1) double
      horizon (1,1) double
   end

   u = target_slots(origin_slot, horizon, tracker.n_slots);
   y_hat = tracker.theta(u) .* tracker.y_prev(u);
end
