function [y_filt, state] = apply_rls_filter(y_new, state, params)
   % APPLY_RLS_FILTER  基于RLS的自适应电价滤波器 (带正则化保护)
   %
   %   使用AR(p)模型: y(k) = φ(k)^T θ + e(k)
   %   其中 φ(k) = [y(k-1), y(k-2), ..., y(k-p)]^T
   %
   %   数值保护机制:
   %     1. 分母阈值保护
   %     2. 正则化: P += ε*I (岭回归阻尼)
   %     3. 协方差迹约束 (防止P膨胀)
   %     4. 条件数检测 + 软重启
   %
   %   输入:
   %       y_new  - 新数据点
   %       state  - RLS状态 (首次可传入 struct(), [], 或任意值)
   %       params - 参数结构体
   %
   %   输出:
   %       y_filt - 滤波值 (标量)
   %       state  - 更新后的RLS状态

   arguments
      y_new  (1,1) double
      state
      params  struct
   end

   % ---- 默认参数 ----
   if ~isfield(params, 'lambda'),      params.lambda      = 0.98; end
   if ~isfield(params, 'delta'),       params.delta       = 100;  end
   if ~isfield(params, 'p'),           params.p           = 4;    end
   if ~isfield(params, 'eps_reg'),     params.eps_reg     = 1e-6; end
   if ~isfield(params, 'max_trace'),   params.max_trace   = 1e6;  end
   if ~isfield(params, 'restart_tol'), params.restart_tol = 1e10; end

   lambda      = params.lambda;
   delta       = params.delta;
   p           = params.p;
   eps_reg     = params.eps_reg;
   max_trace   = params.max_trace;
   restart_tol = params.restart_tol;

   % ---- 健壮的初始化检查 ----
   needs_init = ~isstruct(state) || ...
                ~isfield(state, 'P') || ...
                ~isfield(state, 'theta') || ...
                ~isfield(state, 'history') || ...
                ~isfield(state, 'initialized');

   if needs_init
      state.P           = delta * eye(p);
      state.theta       = zeros(p, 1);
      state.history     = zeros(p, 1);
      state.initialized = false;
      state.restart_count = 0;
   end

   % ---- 初始阶段：填充历史数据 ----
   if ~state.initialized
      state.history = [y_new; state.history(1:end-1)];
      if all(state.history ~= 0)
         state.initialized = true;
         state.theta(1) = 1.0;           % 初始猜测: y(k)≈y(k-1)
         state.P = delta * eye(p);
      end
      y_filt = y_new;
      return;
   end

   % ---- 正常RLS更新 ----
   phi = state.history;  % [y(k-1); y(k-2); ...; y(k-p)]

   % 步骤1: 增益计算 (带分母保护)
   P_phi = state.P * phi;
   denom = lambda + phi' * P_phi;

   if abs(denom) < 1e-10
      y_filt = phi' * state.theta;
      return;
   end

   K = P_phi / denom;

   % 步骤2: 先验误差 (带梯度裁剪)
   y_pred = phi' * state.theta;
   e = y_new - y_pred;
   max_update = 0.5;
   e_clipped = max(-max_update, min(max_update, e));

   % 步骤3: 权重更新
   state.theta = state.theta + K * e_clipped;

   % 步骤4: 协方差更新
   state.P = (state.P - K * phi' * state.P) / lambda;

   % 步骤5: 对称化
   state.P = (state.P + state.P') / 2;

   % 步骤6: 正则化 (岭回归阻尼)
   state.P = state.P + eps_reg * eye(p);

   % 步骤7: 迹约束 (防膨胀)
   P_trace = trace(state.P);
   if P_trace > max_trace
      scale = max_trace / P_trace;
      state.P = scale * state.P;
   end

   % 步骤8: 条件数检测 + 软重启
   if p > 1
      cond_P = cond(state.P);
      if cond_P > restart_tol
         state.P = delta * eye(p);
         state.restart_count = state.restart_count + 1;
      end
   end

   % 步骤9: 滤波输出
   y_filt = phi' * state.theta;

   % 步骤10: 更新历史缓冲
   state.history = [y_new; state.history(1:end-1)];
end