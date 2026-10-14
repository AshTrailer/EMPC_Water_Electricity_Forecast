function st = init_multi_window(n_slots, windows)
   % INIT_MULTI_WINDOW  Arithmetic mean of rolling per-slot templates
   %
   %    T_mw(s) = mean over w of T_w(s)
   %    T_w(s)  = mean of the last w values observed at slot s
   %
   %    One ring buffer of length max(windows) per slot holds the history, and
   %    the shorter windows are read off the same buffer. A window that is not
   %    yet full uses whatever is available, which is what an online predictor
   %    can actually do on its first days.
   %
   %    Every window gets the same weight. Equal weights avoid the estimation
   %    variance of fitted combination weights, which the forecast combination
   %    literature repeatedly finds do not pay off.
   %
   %    Input:
   %       n_slots - slots per day (288)
   %       windows - template windows in days, e.g. [7 28 56 112]
   %    Output:
   %       st - state struct

   arguments
      n_slots (1,1) double = 288
      windows (1,:) double = [7 28 56 112]
   end

   assert(~isempty(windows) && all(windows >= 1), 'windows must be positive');

   st.n_slots = n_slots;
   st.windows = sort(windows(:)');
   st.maxwin = max(st.windows);
   st.H = zeros(n_slots, st.maxwin);    % column 1 is the newest value
   st.cnt = zeros(n_slots, 1);
end
