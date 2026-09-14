function y = clamp_price(y, q)
   % CLAMP_PRICE  Clip values into [Q1, Q99]
   %
   %    Applied to both forecasts and actuals so that RMSE is measured on
   %    exactly the signal the MPC receives. Any spike that still shows up
   %    in the clamped error is a predictor issue, not a data issue.

   arguments
      y (:,1) double
      q (1,2) double
   end

   y = min(max(y, q(1)), q(2));
end