function st = update_smoothing(st, y_true)
   % UPDATE_SMOOTHING  One point into the ring buffer, then recompute S and its slope
   %
   %    The slope is the one-step change of the smoothed value, not of the raw
   %    value, so the forward projection it drives is not driven by a single
   %    spike.

   arguments
      st struct
      y_true (1,1) double
   end

   st.ring(st.pos) = y_true;
   st.pos = mod(st.pos, st.window) + 1;
   st.cnt = min(st.cnt + 1, st.window);

   st.S_prev = st.S;
   v = st.ring(1:st.cnt);
   if st.mode == "mean"
      st.S = mean(v);
   else
      st.S = median(v);
   end

   if isfinite(st.S_prev)
      st.slope = st.S - st.S_prev;
   else
      st.slope = 0;
   end
end
