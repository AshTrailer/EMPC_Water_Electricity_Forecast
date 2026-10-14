function st = init_day_class(n_slots, window)
   % INIT_DAY_CLASS  Per-slot template split by weekday and weekend
   %
   %    T_c(s) = mean of the last `window` observations of slot s that fell on
   %    a day of class c, with c one of {weekday, weekend}.
   %
   %    The class is that of the TARGET day, not of the origin, so the forecast
   %    for a Monday morning uses the weekday template even when it is issued
   %    on Sunday night.
   %
   %    Folded in from archive/AR_RLS_predictor/get_day_class.m so that the
   %    earlier finding that the split costs accuracy stops being an assertion
   %    and becomes a column in the atlas. The window matches the plain rolling
   %    template, so the class split is the only difference between the two.
   %
   %    Input:
   %       n_slots slots per day (288)
   %       window  rolling window in days, default 28
   %    Output:
   %       st - state struct

   arguments
      n_slots (1,1) double = 288
      window (1,1) double = 28
   end

   assert(window >= 1, 'window must be positive');

   st.n_slots = n_slots;
   st.window = window;
   st.ring = zeros(n_slots, 2, window);
   st.pos = ones(n_slots, 2);
   st.cnt = zeros(n_slots, 2);
   st.T_c = zeros(n_slots, 2);
end
