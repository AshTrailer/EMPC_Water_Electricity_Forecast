function [theta_new, P_rls_new, z_hat] = rls_scalar_step(z, u, theta, P_rls, lambda)
   % RLS_SCALAR_STEP  One scalar RLS update with exponential forgetting
   %
   %    Notation follows section 2.4 of
   %    Weekly/2026-10-13/HANDOVER_预测器整理与全跨度比较_20261013.md.
   %       z      the explained quantity
   %       u      the scalar regressor
   %       theta  the estimated coefficient
   %       P_rls  its covariance, a scalar here
   %       z_hat  the one-step-ahead prediction, u*theta before the update
   %
   %    G_rls = P_rls u / ( lambda + P_rls u^2 )
   %    theta = theta + G_rls ( z - u theta )
   %    P_rls = ( 1 - G_rls u ) P_rls / lambda
   %
   %    Shared by the per-slot gains of the theta tracker and the blend weights.

   arguments
      z (1,1) double
      u (1,1) double
      theta (1,1) double
      P_rls (1,1) double
      lambda (1,1) double = 0.98
   end

   denom = lambda + P_rls * u * u;
   if denom < 1e-10
      z_hat = theta * u;
      theta_new = theta;
      P_rls_new = P_rls;
      return;
   end

   G_rls = P_rls * u / denom;
   z_hat = theta * u;
   theta_new = theta + G_rls * (z - z_hat);
   P_rls_new = (1 - G_rls * u) * P_rls / lambda;
   if P_rls_new > 1e8
      P_rls_new = 1e8;   % covariance cap: avoid unbounded growth
   end
end
