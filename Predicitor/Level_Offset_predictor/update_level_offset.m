function st = update_level_offset(st, slot, y_true)
   % UPDATE_LEVEL_OFFSET  One point update of the template and the daily means
   %
   %    Called when the true price of `slot` arrives, for every streamed point
   %    including the warm-up. Two things happen:
   %
   %       1. slot 1 closes the previous day, so its mean is pushed onto the
   %          daily history and the level coefficients are refitted
   %       2. the rolling per-slot template is updated pointwise
   %
   %    The origin loop calls this before forecasting, so the newest point is
   %    inside the state when the forecast is issued.

   arguments
      st struct
      slot (1,1) double
      y_true (1,1) double
   end

   if slot == 1 && st.day_cnt > 0
      st.day_hist(end+1, 1) = st.day_sum / st.day_cnt;
      st.day_sum = 0;
      st.day_cnt = 0;
      if numel(st.day_hist) >= 20
         L = st.day_hist;
         n = min(st.fit_days, numel(L) - 1);
         tgt = L(end - n + 1:end);        % L(d)   for the last n completed days
         lag = L(end - n:end - 1);        % L(d-1) for the same days
         cf = [ones(n, 1), lag] \ tgt;
         st.c = cf(1);
         st.b1 = cf(2);
         st.n_refit = st.n_refit + 1;
      end
   end

   st.day_sum = st.day_sum + y_true;
   st.day_cnt = st.day_cnt + 1;

   if st.cnt(slot) == 0
      st.sum(slot) = y_true;
      st.win(slot, 1) = y_true;
      st.cnt(slot) = 1;
   else
      col = mod(st.cnt(slot), st.window) + 1;
      st.sum(slot) = st.sum(slot) - st.win(slot, col) + y_true;
      st.win(slot, col) = y_true;
      st.cnt(slot) = min(st.cnt(slot) + 1, st.window);
   end
end
