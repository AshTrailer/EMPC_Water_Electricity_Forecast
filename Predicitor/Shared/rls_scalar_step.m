function [theta_new, P_new, y_hat] = rls_scalar_step(y_new, x, theta, P, lambda)
   % RLS_SCALAR_STEP  One scalar RLS update with exponential forgetting
   %
   %    Model: y = theta*x + e, state (theta, P), forgetting factor lambda.
   %    Returns the updated pair and the one-step-ahead prediction y_hat.
   %    Shared by the per-slot gains (theta tracker, blend weights).

   arguments
      y_new (1,1) double
      x (1,1) double
      theta (1,1) double
      P (1,1) double
      lambda (1,1) double = 0.98
   end

   denom = lambda + P * x * x;
   if denom < 1e-10
      y_hat = theta * x;
      theta_new = theta;
      P_new = P;
      return;
   end

   K = P * x / denom;
   y_hat = theta * x;
   theta_new = theta + K * (y_new - y_hat);
   P_new = (1 - K * x) * P / lambda;
   if P_new > 1e8
      P_new = 1e8;   % covariance cap: avoid unbounded growth
   end
end