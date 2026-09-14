function [st, t_pre] = update_template_ar(st, slot, y_true)
   % UPDATE_TEMPLATE_AR  One slot update: template, residual history, AR coefficients
   %
   %    Order of operations matters:
   %      1. t_pre = T(s) BEFORE the update (the value used by the last
   %         forecast of this slot) -> residual r_today = y_true - t_pre
   %      2. RLS update of phi(s): regressors = previous p days' same-slot
   %         residuals (st.r_hist), target = r_today
   %      3. push r_today into st.r_hist (buffer keeps past days only)
   %      4. rolling template update (evict oldest, insert y_true)
   %
   %    On the very first pass of a slot the template is initialized with
   %    the observation itself and no residual is produced.

   arguments
      st struct
      slot (1,1) double
      y_true (1,1) double
   end

   if st.cnt(slot) == 0
      t_pre = y_true;
      st.sum(slot) = y_true;
      st.win(slot, 1) = y_true;
      st.cnt(slot) = 1;
      return;
   end

   t_pre = st.sum(slot) / st.cnt(slot);
   r_today = y_true - t_pre;

   if st.r_cnt(slot) >= st.p
      phi = st.r_hist(slot, :)';
      [th, P, ~] = rls_vector_step(r_today, phi, st.theta(slot, :)', st.P{slot}, st.lambda);
      st.theta(slot, :) = th';
      st.P{slot} = P;
   end

   st.r_hist(slot, :) = [r_today, st.r_hist(slot, 1:end-1)];
   st.r_cnt(slot) = min(st.r_cnt(slot) + 1, st.p);

   col = mod(st.cnt(slot), st.window) + 1;
   st.sum(slot) = st.sum(slot) - st.win(slot, col) + y_true;
   st.win(slot, col) = y_true;
   st.cnt(slot) = min(st.cnt(slot) + 1, st.window);
end