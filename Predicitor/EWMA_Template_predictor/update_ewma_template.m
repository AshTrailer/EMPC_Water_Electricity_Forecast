function st = update_ewma_template(st, slot, y_true)
   % UPDATE_EWMA_TEMPLATE  Push one observation into its slot's ring buffer
   %
   %    Recomputes T_e(slot) only, which is O(K) work once per day per slot.

   arguments
      st struct
      slot (1,1) double
      y_true (1,1) double
   end

   K = st.K;
   p = st.pos(slot);

   st.ring(slot, p) = y_true;
   st.pos(slot) = mod(p, K) + 1;
   st.cnt(slot) = min(st.cnt(slot) + 1, K);

   n = st.cnt(slot);
   vsum = 0;  wsum = 0;  w = 1;
   for i = 1:n
      j = mod(p - i, K) + 1;          % i = 1 is the newest entry
      vsum = vsum + w * st.ring(slot, j);
      wsum = wsum + w;
      w = w * (1 - st.alpha);
   end
   st.T_e(slot) = vsum / wsum;
end
