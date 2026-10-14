function [w_sel, w_opt, info] = combine_ensemble(st, h, mode)
   % COMBINE_ENSEMBLE  Convex weights for one lead, from the trailing window
   %
   %    Two rules, both from section 6.2 of the handover report.
   %
   %    Rule two, selective equal weight, is applied PER LEAD and ranks the
   %    MODELS, not the slots: at a given lead every slot keeps the same set.
   %    Rank by trailing RMSE at that lead and keep the best K_sel:
   %       w_m = 1/K_sel for the kept models, 0 otherwise
   %
   %    Rule three, inverse-covariance weights, is applied PER LEAD BLOCK,
   %    because one covariance per lead would need n_s solves per day. On the
   %    block that contains h, with the covariance shrunk toward its diagonal:
   %       S <- (1-eps) S + eps (trace(S)/M) I
   %       w  = S^-1 1 / (1' S^-1 1)
   %
   %    Input:
   %       st   - state from init_ensemble
   %       h    - lead in steps, 1..n_s. A vector is allowed and returns one
   %              weight row per requested lead, which is what the driver wants
   %       mode - "sel", "opt", or "both" (default)
   %    Output:
   %       w_sel  - (n_models x 1) rule two weights, empty when not requested
   %       w_opt  - (n_models x 1) rule three weights, empty when not requested
   %       info   - struct with the ranking and the covariance, for logs

   arguments
      st struct
      h (:,1) double
      mode (1,1) string {mustBeMember(mode, ["sel" "opt" "both"])} = "both"
   end

   w_sel = [];
   w_opt = [];
   info = struct('rank', [], 'S', []);

   if st.n_stored < 2
      return
   end
   % ring positions that hold a completed day; the day NUMBERS are not valid
   % indices into the buffer
   pos = find(st.buf_day > 0);

   % ---- rule two: rank the models by trailing RMSE at each requested lead ----
   % The ranking is over models, not over slots: at a given lead every slot
   % gets the same kept set, which is what run_ensemble_combos.m does with
   % Mrr(h,:,:). Asking for a vector of leads returns one weight row per lead.
   if mode ~= "opt" && st.K_sel > 0
      k = min(st.K_sel, st.n_models);
      nh = numel(h);
      Wsel = zeros(nh, st.n_models);
      for i = 1:nh
         E = double(st.buf(:, h(i), pos, :));            % n_s x n_day x n_models
         rmse_d = squeeze(sqrt(mean(E.^2, 1)));          % n_day x n_models
         score = mean(rmse_d, 1);                        % 1 x n_models
         [~, ord] = sort(score);
         Wsel(i, ord(1:k)) = 1 / k;
      end
      if isscalar(h)
         w_sel = Wsel(1, :)';
      else
         w_sel = Wsel;
      end
      info.rank = Wsel;
   end

   % ---- rule three: one inverse covariance for the lead block of h ----
   if mode ~= "sel"
      assert(isscalar(h), 'rule three is fitted per lead block, ask for one lead');
      ib = floor((h - 1) / st.B) + 1;
      leads_fit = st.blocks{ib}(1:6:end);
      past = double(st.buf(st.sub_slots, leads_fit, pos, :));
      X = reshape(past, [], st.n_models);
      if size(X,1) >= 50
         S = (X' * X) / size(X,1);
         S = (1 - st.eps)*S + st.eps*(trace(S)/st.n_models)*eye(st.n_models);
         info.S = S;
         w = S \ ones(st.n_models, 1);
         if abs(sum(w)) > 1e-12
            w_opt = w / sum(w);
         end
      end
   end
end
