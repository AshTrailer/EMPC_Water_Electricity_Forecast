function [y_hat, T_e] = predict_ewma_template(st, origin_slot, horizon)
   % PREDICT_EWMA_TEMPLATE  Forecast from the exponentially weighted template
   %
   %    y_hat(h) = T_e(u(h))
   %
   %    Independent of the lead time, exactly like the plain rolling template.
   %    The only difference between this and M2 is how the days are weighted.
   %
   %    Input:
   %       st          - state from init_ewma_template
   %       origin_slot - slot of the forecast origin, 1..n_slots
   %       horizon     - number of steps to forecast
   %    Output:
   %       y_hat - (horizon x 1) forecast
   %       T_e   - (n_slots x 1) the template itself, for callers that want it

   arguments
      st struct
      origin_slot (1,1) double
      horizon (:,1) double
   end

   T_e = st.T_e;
   u = target_slots(origin_slot, horizon, st.n_slots);
   y_hat = T_e(u);
end
