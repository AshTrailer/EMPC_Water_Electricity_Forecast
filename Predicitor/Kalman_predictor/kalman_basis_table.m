function G = kalman_basis_table(model, n_step_max)
   % KALMAN_BASIS_TABLE  C_s A^h for every (lead, target slot) pair
   %
   %    Notation follows section 2.9 of
   %    Weekly/2026-10-13/HANDOVER_预测器整理与全跨度比较_20261013.md.
   %
   %    The observation row C_k depends only on the target slot and the lead,
   %    never on the filter state, so the whole mean prediction collapses to
   %    one inner product per lead:
   %
   %       y_hat(h) = C_{u(h)} A^h xi = G(h, u(h)) * xi
   %
   %    Building this table once replaces one matrix product per lead per
   %    forecast origin. At 34560 origins that is the difference between an
   %    affordable model and one that never finishes.
   %
   %    A^h stays bounded at any h: the harmonic blocks are rotations, the
   %    trend block is a random walk with no drift, and the residual AR block
   %    decays. So the table is safe to build out to 2196 steps, the 183-hour
   %    end of the atlas lead axis.
   %
   %    Input:
   %       model      - struct from build_harmonic_ss_model
   %       n_step_max - largest lead in 5-minute steps, default 288
   %    Output:
   %       G - (n_s*n_step_max x nx) matrix; row h + n_s*(s-1) is the row for
   %           lead h and target slot s, which is the layout
   %           kalman_predict_atlas indexes with u + n_s*(h_step-1)

   arguments
      model struct
      n_step_max (1,1) double = 288
   end

   n_s = 288;
   nx = model.nx;

   C_all = zeros(n_s, nx);
   for s = 1:n_s
      C_all(s, :) = make_harmonic_C(model, s);
   end

   G = zeros(n_s*n_step_max, nx);
   Ah = eye(nx);
   for h = 1:n_step_max
      Ah = model.A * Ah;                       % A^h, accumulated
      G((h-1)*n_s + (1:n_s), :) = C_all * Ah;
   end
end
