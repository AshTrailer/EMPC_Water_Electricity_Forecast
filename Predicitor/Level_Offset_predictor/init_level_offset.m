function st = init_level_offset(n_slots, window, fit_days, use_run)
   % INIT_LEVEL_OFFSET  Rolling per-slot template plus a daily-level offset
   %
   %    y_hat(t+h) = T(s(t+h)) + ( Lhat(D) - Lbar )
   %
   %    T(s)   rolling per-slot mean over the last `window` days
   %    Lbar   mean of T over all slots, i.e. the template's own daily level
   %    Lhat   estimate of the target day's mean price
   %    D      day the target point belongs to, origin day or the one after
   %
   %    Without the running term (use_run = false) Lhat is a pure recursion on
   %    completed daily means:
   %
   %       Lhat(d)   = c + b1 * L(d-1)
   %       Lhat(d+1) = c + b1 * Lhat(d)
   %
   %    L(d-1) is the mean of the last day that finished before the origin, so
   %    it is always known. Coefficients are refitted once per day, at slot 1,
   %    by ordinary least squares on the last `fit_days` daily means.
   %
   %    The pure recursion is weak for next-day targets: two steps of an AR(1)
   %    with b1 around 0.5 leave only b1^2, roughly 0.28, on yesterday. With
   %    use_run = true the origin's own day is folded in first,
   %
   %       w        = observed slots of the origin's day / n_slots
   %       Lhat(d)  = w * runmean(day d) + (1 - w) * (c + b1 * L(d-1))
   %       Lhat(d+1)= c + b1 * Lhat(d)
   %
   %    so the running mean takes over as the day fills up. The blend weight is
   %    the observed fraction itself, which needs no extra fitting.
   %
   %    With b1 = 0 the offset vanishes and the predictor degenerates to the
   %    bare rolling template.
   %
   %    Input:
   %       n_slots  - slots per day (288)
   %       window   - template window in days (28)
   %       fit_days - days used to refit c and b1 (56)
   %       use_run  - fold in the running mean of the origin's day
   %    Output:
   %       st - state struct

   arguments
      n_slots (1,1) double = 288
      window (1,1) double = 28
      fit_days (1,1) double = 56
      use_run (1,1) logical = false
   end

   st.n_slots = n_slots;
   st.window = window;
   st.fit_days = fit_days;
   st.use_run = use_run;

   % rolling per-slot template, ring buffer per slot
   st.sum = zeros(n_slots, 1);
   st.cnt = zeros(n_slots, 1);
   st.win = zeros(n_slots, window);

   % daily accounting
   st.day_sum = 0;
   st.day_cnt = 0;
   st.day_hist = zeros(0, 1);      % completed daily means, oldest first

   % level recursion, prior is the random walk b1 = 1 with no intercept
   st.c = 0;
   st.b1 = 1;
   st.n_refit = 0;
end
