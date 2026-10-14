function st = init_ewma_template(n_slots, alpha, min_weight)
   % INIT_EWMA_TEMPLATE  Exponentially weighted per-slot template
   %
   %    T_e(s) = sum_{i=0}^{n-1} w_i * y^(i)(s) / sum_i w_i,   w_i = (1-alpha)^i
   %
   %    i = 0 is the newest day. The history is truncated at K days, where K
   %    is the first lag whose weight falls below min_weight, so a day that
   %    has decayed to nothing is dropped instead of lingering forever. That
   %    is the difference between this and a plain recursion
   %    T <- (1-alpha) T + alpha y, which has infinite memory.
   %
   %    One ring buffer of length K per slot holds the daily history. Each
   %    slot is updated once per day, in slot order, so the ring is already
   %    in age order and the i-th newest entry is at position
   %    mod(pos - i, K) + 1.
   %
   %    Notation follows section 2.3 of
   %    Weekly/2026-10-13/HANDOVER_预测器整理与全跨度比较_20261013.md.
   %    Input:
   %       n_slots    slots per day (288)
   %       alpha      forgetting factor, 0 < alpha <= 1
   %       min_weight truncation threshold, 0 < min_weight < 1
   %    Output:
   %       st - state struct

   arguments
      n_slots (1,1) double = 288
      alpha (1,1) double = 0.15
      min_weight (1,1) double = 0.01
   end

   assert(alpha > 0 && alpha <= 1, 'alpha must lie in (0, 1]');
   assert(min_weight > 0 && min_weight < 1, 'min_weight must lie in (0, 1)');

   K = max(1, floor(log(min_weight) / log(1 - alpha)));

   st.n_slots = n_slots;
   st.alpha = alpha;
   st.min_weight = min_weight;
   st.K = K;
   st.ring = zeros(n_slots, K);
   st.pos = ones(n_slots, 1);
   st.cnt = zeros(n_slots, 1);
   st.T_e = zeros(n_slots, 1);
end
