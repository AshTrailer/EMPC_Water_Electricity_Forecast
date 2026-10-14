function st = update_day_class(st, slot, y_true, is_weekend)
   % UPDATE_DAY_CLASS  Push one observation into its slot and class buffer
   %
   %    Only the touched class of the touched slot is recomputed.

   arguments
      st struct
      slot (1,1) double
      y_true (1,1) double
      is_weekend (1,1) logical
   end

   c = 1 + double(is_weekend);
   W = st.window;
   p = st.pos(slot, c);

   st.ring(slot, c, p) = y_true;
   st.pos(slot, c) = mod(p, W) + 1;
   st.cnt(slot, c) = min(st.cnt(slot, c) + 1, W);

   v = st.ring(slot, c, 1:st.cnt(slot, c));
   st.T_c(slot, c) = mean(v);
end
