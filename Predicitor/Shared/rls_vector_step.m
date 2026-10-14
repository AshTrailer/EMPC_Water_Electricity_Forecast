function [theta_new, P_rls_new, z_hat] = rls_vector_step(z, u, theta, P_rls, lambda)
   % RLS_VECTOR_STEP  One vector RLS update with exponential forgetting
   %
   %    Notation follows section 2.4 of
   %    Weekly/2026-10-13/HANDOVER_预测器整理与全跨度比较_20261013.md.
   %       z      the explained quantity
   %       u      the regressor vector
   %       theta  the estimated coefficient vector
   %       P_rls  its covariance matrix
   %       z_hat  the one-step-ahead prediction, u'*theta before the update
   %
   %    G_rls = P_rls u / ( lambda + u' P_rls u )
   %    theta = theta + G_rls ( z - u' theta )
   %    P_rls = ( P_rls - G_rls u' P_rls ) / lambda
   %
   %    Numerical guards: denominator floor, symmetrization, trace cap.
   %
   %    Used by the per-slot cross-day AR(p), where u holds the same slot's
   %    residuals on the previous p days and theta is phi.

   arguments
      z (1,1) double
      u (:,1) double
      theta (:,1) double
      P_rls (:,:) double
      lambda (1,1) double = 0.98
   end

   n = numel(u);
   assert(numel(theta) == n && all(size(P_rls) == n), 'Dimension mismatch in RLS state');

   P_u = P_rls * u;
   denom = lambda + u' * P_u;

   if abs(denom) < 1e-10
      z_hat = u' * theta;
      theta_new = theta;
      P_rls_new = P_rls;
      return;
   end

   G_rls = P_u / denom;
   z_hat = u' * theta;
   theta_new = theta + G_rls * (z - z_hat);
   P_rls_new = (P_rls - G_rls * u' * P_rls) / lambda;
   P_rls_new = (P_rls_new + P_rls_new') / 2;

   if trace(P_rls_new) > 1e8
      P_rls_new = P_rls_new * (1e8 / trace(P_rls_new));
   end
end
