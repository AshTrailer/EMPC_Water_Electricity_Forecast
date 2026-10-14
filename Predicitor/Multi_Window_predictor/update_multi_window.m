function st = update_multi_window(st, slot, y_true)
   % UPDATE_MULTI_WINDOW  Push one new value into the slot's history buffer
   %
   %    The newest value goes to column 1 and the rest shift one column right.
   %    Only the row of the observed slot is touched, so the cost per point is
   %    the buffer length, not the buffer area.

   arguments
      st struct
      slot (1,1) double
      y_true (1,1) double
   end

   if st.cnt(slot) == 0
      st.H(slot, 1) = y_true;
   else
      st.H(slot, 2:end) = st.H(slot, 1:end - 1);
      st.H(slot, 1) = y_true;
   end
   st.cnt(slot) = min(st.cnt(slot) + 1, st.maxwin);
end
