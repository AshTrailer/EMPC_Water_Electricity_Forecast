function [u_opt, info] = mpc_water_tank(x_cur, d_cur, mpc_cfg)
   % MPC_WATER_TANK  Single-step QP-based MPC for the water tank
   %
   % Plant model (Euler discretization, 5-min step):
   %     x(k+1) = x(k) + (dt/S) * (u(k) - d(k))
   %     x - water level (m),   u - inflow (m^3/s, control input),
   %     d - outflow (m^3/s, measured disturbance, nominal value used)
   %
   % MPC cost over prediction horizon Np:
   %     J = sum_{k=0}^{Np-1} [ Q_x (x_{k+1} - x_ref)^2
   %                          + R_u (u_k - u_ref)^2 + rho eps_k^2 ]
   %
   % Constraints:
   %     0 <= u_k <= u_max
   %     x_lo - eps_k <= x_{k+1} <= x_hi + eps_k,   eps_k >= 0  (soft level band)
   %
   % The band [x_lo, x_hi] is 40%..90% of the usable range [x_min, x_max]:
   %     x_lo = x_min + 0.40*(x_max - x_min),  x_hi = x_min + 0.90*(x_max - x_min)
   % Soft constraints (slack eps) guarantee QP feasibility;
   % rho >> Q_x keeps band violations negligible.
   %
   % QP solved with quadprog (Optimization Toolbox):
   %     min_z  0.5 z' H z + f' z,   z = [u_0..u_{Np-1}; eps_0..eps_{Np-1}]
   %
   % Parameters and their effect:
   %     Np      - larger -> more far-sighted, smoother inflow
   %     Q_x/R_u - larger ratio -> tighter level tracking (faster flow changes)
   %     rho     - slack penalty, larger -> level band treated as harder constraint
   %
   % Inputs:
   %     x_cur   - current measured level (m)
   %     d_cur   - current nominal outflow (m^3/s)
   %     mpc_cfg - struct with fields: .n_horizon, .area (S), .dt,
   %               .x_ref, .x_lo, .x_hi, .u_max, .u_ref,
   %               .q_level (Q_x), .r_flow (R_u), .rho_slack
   % Outputs:
   %     u_opt - optimal inflow for the current step (m^3/s)
   %     info  - diagnostics: .fval, .exitflag, .u_seq, .x_pred

   arguments
      x_cur (1,1) double
      d_cur (1,1) double
      mpc_cfg struct
   end

   Np  = mpc_cfg.n_horizon;
   g   = mpc_cfg.dt / mpc_cfg.area;   % level gain per 1 m^3/s over one step
   Q_x = mpc_cfg.q_level;
   R_u = mpc_cfg.r_flow;
   rho = mpc_cfg.rho_slack;

   % x_pred = x0_vec + Phi*(U - D),  Phi = lower-triangular g-matrix
   Phi = tril(ones(Np)) * g;
   D   = d_cur * ones(Np, 1);
   x0_vec = x_cur * ones(Np, 1);

   % ---- cost: quadratic terms ----
   H_uu = Phi' * (Q_x * Phi) + R_u * eye(Np);
   c    = x0_vec - mpc_cfg.x_ref - Phi * D;      % e = Phi*U + c
   f_u  = Phi' * (Q_x * c) - R_u * mpc_cfg.u_ref * ones(Np, 1);

   H = blkdiag(2 * H_uu, 2 * rho * eye(Np));
   f = [2 * f_u; zeros(Np, 1)];

   % ---- inequality constraints (soft level band) ----
   A_ineq = [-Phi, -eye(Np);  Phi, -eye(Np)];
   b_ineq = [-(mpc_cfg.x_lo * ones(Np,1) - x0_vec + Phi * D); ...
              mpc_cfg.x_hi * ones(Np,1) - x0_vec + Phi * D];

   lb = [zeros(Np,1); zeros(Np,1)];
   ub = [mpc_cfg.u_max * ones(Np,1); inf(Np,1)];

   options = optimoptions('quadprog', 'Display', 'off', 'Algorithm', 'interior-point-convex');
   [z, fval, exitflag] = quadprog(H, f, A_ineq, b_ineq, [], [], lb, ub, [], options);

   assert(exitflag >= 0, 'MPC QP failed (exitflag %d)', exitflag);

   u_opt = z(1);
   if nargout > 1
      info.fval = fval;
      info.exitflag = exitflag;
      info.u_seq = z(1:Np);
      info.x_pred = x0_vec + Phi * (z(1:Np) - D);
   end
end