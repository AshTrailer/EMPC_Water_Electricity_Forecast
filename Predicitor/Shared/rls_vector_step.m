function [theta_new, P_new, y_hat] = rls_vector_step(y_new, phi, theta, P, lambda)
   % RLS_VECTOR_STEP  One vector RLS update with exponential forgetting
   %
   %    Model: y = phi'*theta + e, state (theta, P), forgetting lambda.
   %    Numerical guards: denominator floor, P symmetrization, trace cap.
   %
   %    Used by the per-slot cross-day AR(p): phi holds the same slot's
   %    residuals on the previous p days.

   arguments
      y_new (1,1) double
      phi (:,1) double
      theta (:,1) double
      P (:,:) double
      lambda (1,1) double = 0.98
   end

   n = numel(phi);
   assert(numel(theta) == n && all(size(P) == n), 'Dimension mismatch in RLS state');

   P_phi = P * phi;
   denom = lambda + phi' * P_phi;

   if abs(denom) < 1e-10
      y_hat = phi' * theta;
      theta_new = theta;
      P_new = P;
      return;
   end

   K = P_phi / denom;
   y_hat = phi' * theta;
   theta_new = theta + K * (y_new - y_hat);
   P_new = (P - K * phi' * P) / lambda;
   P_new = (P_new + P_new') / 2;

   if trace(P_new) > 1e8
      P_new = P_new * (1e8 / trace(P_new));
   end
end