function st = update_ensemble(st, day, E_day)
   % UPDATE_ENSEMBLE  Push one completed day of realised errors into the window
   %
   %    A day is complete once every target that falls inside it has been
   %    observed, so the block for day d is available from the first control
   %    step of day d+1 onwards. Nothing here looks forward.
   %
   %    Input:
   %       st    - state from init_ensemble
   %       day   - day index, 1-based, must increase by one between calls
   %       E_day - (n_s x n_s x n_models) signed error at (target slot, lead)
   %    Output:
   %       st - updated state

   arguments
      st struct
      day (1,1) double
      E_day (:,:,:) single
   end

   assert(size(E_day,1) == st.n_s && size(E_day,2) == st.n_s, ...
      'error block is not %d by %d', st.n_s, st.n_s);
   assert(size(E_day,3) == st.n_models, ...
      'error block carries %d models, the ensemble holds %d', ...
      size(E_day,3), st.n_models);
   assert(day >= 1, 'day must be a positive day index, got %d', day);
   if st.n_stored > 0
      assert(day > max(st.buf_day), 'days must arrive in increasing order');
   end

   p = mod(day - 1, st.n_w) + 1;
   st.buf(:, :, p, :) = E_day;
   st.buf_day(p) = day;
   st.pos_next = mod(p, st.n_w) + 1;
   st.n_stored = min(st.n_stored + 1, st.n_w);
end
