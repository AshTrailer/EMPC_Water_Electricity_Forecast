function [st, t_pre] = update_template_ar(st, slot, y_true)
   % UPDATE_TEMPLATE_AR  One point update: template + intraday residual AR
   %
   %    Order of operations matters:
   %      1. t_pre = T(s) BEFORE the update -> residual r = y_true - t_pre
   %         (same residual definition as the one the last forecast of
   %          this slot targeted, so the RLS update stays consistent)
   %      2. RLS update of phi with CONSECUTIVE regressors
   %         st.hist = [r(t-1); ...; r(t-p)] and target r
   %      3. push r into st.hist (newest first)
   %      4. rolling template update (evict oldest sample, insert y_true)
   %
   %    On the very first pass of a slot the template is initialized with
   %    the observation itself and no residual is produced (there is no
   %    T(s) yet to deviate from).

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
   r = y_true - t_pre;

   % intraday AR update (consecutive regressors, every 5 min)
   if st.n_hist >= st.p
      [st.phi, st.P, ~] = rls_vector_step(r, st.hist, st.phi, st.P, st.lambda);
   end
   st.hist = [r; st.hist(1:end-1)];
   st.n_hist = min(st.n_hist + 1, st.p);

   % rolling template update
   col = mod(st.cnt(slot), st.window) + 1;
   st.sum(slot) = st.sum(slot) - st.win(slot, col) + y_true;
   st.win(slot, col) = y_true;
   st.cnt(slot) = min(st.cnt(slot) + 1, st.window);
end