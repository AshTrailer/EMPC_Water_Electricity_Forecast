function t_mw = multi_window_template(st)
   % MULTI_WINDOW_TEMPLATE  The averaged per-slot template itself
   %
   %    T_mw(s) = mean over w of T_w(s),  T_w(s) = mean of the last w values
   %    observed at slot s. Shorter windows are read off the same ring buffer
   %    as the longest one, and a window that is not yet full uses whatever is
   %    available.
   %
   %    Split out of predict_multi_window so a caller can read the template
   %    without forming a forecast, for instance to build a residual series or
   %    to feed another model's anchor.
   %
   %    Input:
   %       st   - state from init_multi_window
   %    Output:
   %       t_mw - (n_slots x 1) averaged template

   arguments
      st struct
   end

   cs = cumsum(st.H, 2);
   W = zeros(st.n_slots, numel(st.windows));
   for k = 1:numel(st.windows)
      w = st.windows(k);
      W(:, k) = cs(:, w) ./ max(min(st.cnt, w), 1);
   end
   t_mw = mean(W, 2);
end
