function st = init_smoothing(window, mode)
   % INIT_SMOOTHING  Causal smoother of the raw 5-minute stream
   %
   %    S(k) = mean or median of { y(k), y(k-1), ..., y(k-window+1) }
   %
   %    This module smooths the PAST. On its own it is not a forecast, because
   %    a trailing average lags the signal by about (window-1)/2 steps. The
   %    delay is kept in the state so a caller can either use S(k) as a
   %    deliberately naive baseline or project it forward to compensate.
   %
   %    Folded in from archive/Testing_Filter so that "smooth first, then
   %    predict" is answered with numbers instead of asserted.
   %
   %    Input:
   %       window number of raw points in the window, default 12 (one hour)
   %       mode   "mean" or "median"
   %    Output:
   %       st - state struct

   arguments
      window (1,1) double = 12
      mode (1,1) string {mustBeMember(mode, ["mean" "median"])} = "mean"
   end

   assert(window >= 1, 'window must be positive');

   st.window = window;
   st.mode = mode;
   st.delay = (window - 1) / 2;
   st.ring = zeros(window, 1);
   st.pos = 1;
   st.cnt = 0;
   st.S = NaN;          % current smoothed value
   st.S_prev = NaN;     % previous smoothed value, for the slope
   st.slope = 0;
end
