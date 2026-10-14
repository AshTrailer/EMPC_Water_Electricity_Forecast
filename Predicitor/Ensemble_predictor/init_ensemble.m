function st = init_ensemble(n_models, n_s, n_w, opts)
   % INIT_ENSEMBLE  State of the combination layer that feeds the controller
   %
   %    This holds the trailing window of realised errors, one block per day,
   %    and nothing else. The sub-model forecasts themselves are produced
   %    outside and handed in, which is what lets the same engine be used both
   %    from a live predictor suite and from a saved error atlas.
   %
   %    It keeps signed errors rather than forecasts because any convex
   %    combination satisfies e_c = sum_m w_m e_m, so the combined error can be
   %    formed from the members' errors without re-running them.
   %
   %    Notation follows section 2.6 of
   %    Weekly/2026-10-13/HANDOVER_预测器整理与全跨度比较_20261013.md.
   %
   %    Input:
   %       n_models      number of sub-models, the width of every error block
   %       n_s           slots per day, 288
   %       n_w           trailing window length in days, 28
   %       opts.K_sel    models kept by the selective equal-weight rule,
   %                     0 disables that rule
   %       opts.eps      shrinkage of the error covariance toward its diagonal,
   %                     the eps of section 2.6
   %       opts.B        lead block width in steps, 48
   %    Output:
   %       st - state struct

   arguments
      n_models (1,1) double
      n_s (1,1) double = 288
      n_w (1,1) double = 28
      opts.K_sel (1,1) double = 0
      opts.eps (1,1) double = 0.3
      opts.B (1,1) double = 48
   end

   assert(n_models >= 2, 'an ensemble needs at least two sub-models');
   assert(n_w >= 2, 'the trailing window must span at least two days');
   assert(mod(n_s, opts.B) == 0, 'the lead block width must divide the day');

   st.n_models = n_models;
   st.n_s = n_s;
   st.n_w = n_w;
   st.K_sel = opts.K_sel;
   st.eps = opts.eps;
   st.B = opts.B;
   st.n_blk = n_s / opts.B;

   % ring buffer of the last n_w completed days, newest at pos_next
   st.buf = zeros(n_s, n_s, n_w, n_models, 'single');
   st.buf_day = zeros(n_w, 1);
   st.pos_next = 1;
   st.n_stored = 0;

   % sub-sampled cells used by the covariance fit, and the lead blocks
   st.sub_slots = 1:6:n_s;
   st.blocks = arrayfun(@(b) (b*opts.B + 1):((b+1)*opts.B), 0:st.n_blk-1, ...
      'UniformOutput', false);
end
