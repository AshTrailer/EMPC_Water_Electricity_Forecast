function cs = update_price_clamp(cs, y_day)
   % UPDATE_PRICE_CLAMP  Push one completed day into the rolling window
   %
   %    Evicts the oldest day, appends the new one and recomputes the
   %    global [Q1, Q99]. Called once per day (after the day completes),
   %    so the thresholds are constant within a day.

   arguments
      cs struct
      y_day (1,288) double
   end

   cs.window = [cs.window(2:end, :); y_day(:)'];
   cs.q = prctile(cs.window(:), [1 99]);
end