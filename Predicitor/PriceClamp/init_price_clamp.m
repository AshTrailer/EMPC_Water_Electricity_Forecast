function cs = init_price_clamp(y_window)
   % INIT_PRICE_CLAMP  Initialize the daily [Q1, Q99] price clamp
   %
   %    Thresholds are global quantiles (no per-slot split) of a rolling
   %    window of raw prices. The window holds complete days only, so its
   %    length in days stays fixed.
   %
   %    Input:
   %       y_window - (n_days x 288) raw prices, oldest day first
   %    Output:
   %       cs - struct: .window, .n_days, .q = [Q1, Q99]

   arguments
      y_window (:,:) double
   end

   cs.window = y_window;
   cs.n_days = size(y_window, 1);
   cs.q = prctile(y_window(:), [1 99]);
end