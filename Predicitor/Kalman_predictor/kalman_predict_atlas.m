function y_hat = kalman_predict_atlas(xi, G, u, h_step)
   % KALMAN_PREDICT_ATLAS  Mean forecast as one matrix product
   %
   %    y_hat(i) = G(h_step(i), u(i)) * xi
   %
   %    u       (n x 1) target slot of each forecast point, from target_slots
   %    G       table from kalman_basis_table, rows indexed h + n_s*(s-1)
   %    h_step  (n x 1) those points' leads in 5-minute steps, default 1..n
   %    xi      filtered state at the forecast origin, after ingesting y(k)
   %
   %    Input:
   %       xi     (nx x 1) filtered state
   %       G      (n_s*n_step_max x nx) basis table
   %       u      (n x 1) target slots
   %       h_step (n x 1) step numbers, default (1:n)'
   %    Output:
   %       y_hat (n x 1) forecast means

   arguments
      xi (:,1) double
      G (:,:) double
      u (:,1) double
      h_step (:,1) double = (1:numel(u))'
   end

   n_s = 288;
   lin = u + n_s * (h_step(:) - 1);
   y_hat = G(lin, :) * xi;
end
