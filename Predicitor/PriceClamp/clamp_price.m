function y = clamp_price(y, q)
   % CLAMP_PRICE  Clip values into [Q1, Q99]
   %
   %    Applied to forecasts and actuals alike so that every metric is
   %    measured on exactly the signal the MPC receives: one occasional
   %    +19000 $/MWh print must not be allowed to steer a 24-hour schedule.
   %
   %    q is either
   %       a 1x2 pair  - one threshold pair for the whole vector, or
   %       an Nx2 pair  - one pair per element of a length-N y (per target day)
   %
   %    Input:
   %       y - values to clip
   %       q - thresholds as above
   %    Output:
   %       y - clipped values

   arguments
      y (:,1) double
      q (:,2) double
   end

   if size(q,1) == 1
      y = min(max(y, q(1)), q(2));
   else
      assert(size(q,1) == numel(y), ...
         'clamp_price: per-element thresholds need one row per value');
      y = min(max(y, q(:,1)), q(:,2));
   end
end
