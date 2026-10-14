function [y_hat, t_mw] = predict_multi_window(st, origin_slot, horizon)
   % PREDICT_MULTI_WINDOW  Forecast from the averaged multi-window template
   %
   %    y_hat(h) = T_mw(u(h))
   %
   %    Independent of the lead time: every target point uses its own slot's
   %    averaged template value, exactly like the single-window template.
   %
   %    Input:
   %       st          - state from init_multi_window
   %       origin_slot - slot of the forecast origin (1..n_slots)
   %       horizon     - number of steps to forecast (288)
   %    Output:
   %       y_hat - (horizon x 1) forecast
   %       t_mw  - (n_slots x 1) the averaged template itself, so callers can
   %               reuse it instead of recomputing

   arguments
      st struct
      origin_slot (1,1) double
      horizon (:,1) double
   end

   t_mw = multi_window_template(st);
   u = target_slots(origin_slot, horizon, st.n_slots);
   y_hat = t_mw(u);
end
