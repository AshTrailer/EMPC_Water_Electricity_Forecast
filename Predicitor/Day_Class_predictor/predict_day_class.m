function [y_hat, T_c] = predict_day_class(st, origin_slot, cls_tgt, h_step)
   % PREDICT_DAY_CLASS  Forecast from the class-split template
   %
   %    y_hat(h) = T_c( u(h), class of the target day )
   %
   %    Input:
   %       st          - state from init_day_class
   %       origin_slot - slot of the forecast origin, 1..n_slots
   %       cls_tgt     - (n x 1) target-day class, 1 = weekday, 2 = weekend
   %       h_step      - (n x 1) those targets' step numbers, default 1..n
   %    Output:
   %       y_hat - (n x 1) forecast
   %       T_c   - (n_slots x 2) the class-split template itself

   arguments
      st struct
      origin_slot (1,1) double
      cls_tgt (:,1) double
      h_step (:,1) double = (1:numel(cls_tgt))'
   end

   u = target_slots(origin_slot, h_step(:), st.n_slots);
   T_c = st.T_c;
   y_hat = T_c(u + st.n_slots * (cls_tgt - 1));
end
