function [y_hat, offset, Lhat_cur, Lhat_next] = predict_level_offset(st, origin_slot, horizon, Lbar)
   % PREDICT_LEVEL_OFFSET  One horizon-step forecast with the daily-level offset
   %
   %    y_hat(h) = T(u(h)) + offset(h)
   %    offset(h) = Lhat(D(h)) - Lbar
   %
   %    u(h)  target slot of lead h, wrapping around the daily cycle
   %    D(h)  0 if the target still falls inside the origin's day, 1 otherwise
   %    Lbar  daily level of the template the offset is added to. Passing it in
   %          lets the same offset be added to any template, not only T(s).
   %          Default is the mean of this module's own template.
   %
   %    For a horizon of one day there are only two target days, so the whole
   %    offset is described by two numbers.
   %
   %    Input:
   %       st          - state from init_level_offset
   %       origin_slot - slot of the forecast origin (1..n_slots)
   %       horizon     - number of steps to forecast (288)
   %       Lbar        - optional daily level of the template being corrected
   %    Output:
   %       y_hat      - (horizon x 1) forecast
   %       offset     - (horizon x 1) level correction that was added
   %       Lhat_cur   - estimated mean of the origin's day
   %       Lhat_next  - estimated mean of the following day

   arguments
      st struct
      origin_slot (1,1) double
      horizon (:,1) double
      Lbar (1,1) double = NaN
   end

   if isscalar(horizon)
      steps = (1:horizon)';
   else
      steps = horizon(:);
   end

   u = target_slots(origin_slot, steps, st.n_slots);
   t_vec = st.sum(u) ./ max(st.cnt(u), 1);
   if isnan(Lbar)
      Lbar = mean(t_vec);
   end

   Lprev = 0;
   if ~isempty(st.day_hist)
      Lprev = st.day_hist(end);
   end
   Lhat_cur = st.c + st.b1 * Lprev;
   if st.use_run && st.day_cnt > 0
      w = min(st.day_cnt / st.n_slots, 1);
      Lhat_cur = w * (st.day_sum / st.day_cnt) + (1 - w) * Lhat_cur;
   end
   Lhat_next = st.c + st.b1 * Lhat_cur;

   % unwrapped target index: day 0 is the origin's day, day 1 the one after
   days_ahead = floor((origin_slot - 1 + steps) / st.n_slots);
   offset = zeros(numel(steps), 1);
   offset(days_ahead == 0) = Lhat_cur - Lbar;
   offset(days_ahead >= 1) = Lhat_next - Lbar;

   y_hat = t_vec + offset;
end
