function model = build_harmonic_ss_model(price_hist, time_hist, n_harm, ar_order)
   % BUILD_HARMONIC_SS_MODEL  训练谐波状态空间模型 (方案A)
   %
   %   模型:
   %      y(t) = μ(t) + Σ_{k=1}^{n_harm} [a_k(t) sin θ_k(t) + b_k(t) cos θ_k(t)] + r(t)
   %      状态: x = [μ, a1, b1, ..., aK, bK, r_t, r_{t-1}, ..., r_{t-p+1}]'
   %      观测: y(t) = C(t) x(t)
   %
   %   训练步骤 (与方案 B 一致, 仅用训练期数据):
   %     1. 全局 OLS 拟合谐波基 → 初始系数 μ̂, â_k, b̂_k
   %     2. 残差拟合 AR(p) → φ 与扰动标准差 σ_ε
   %     3. 逐日重拟合系数 → 系数逐日差分方差 / 288 = 每步过程噪声 Q
   %     4. 训练期逐点卡尔曼滤波预热 → 训练期末的滤波状态与协方差
   %
   %   A 矩阵 (分块对角, 线性时不变):
   %     趋势块:   [1]
   %     谐波块 k: [cos ω_k, sin ω_k; -sin ω_k, cos ω_k],  ω_k = 2πk/288
   %       性质: A^h 谐波块 = 旋转 h·ω_k 角 (解析);
   %              A^288 谐波块 = I (旋转一圈), 24h 预测周期自洽
   %     AR 块:   伴随矩阵 [φ1 ... φp; I_{p-1} 0] (残差动态嵌入 A)
   %
   %   Q: diag([q_μ, q_a1, q_b1, ..., q_ap, q_bp, σ_ε², 0, ..., 0])
   %   R: 理论上出清价精确观测 R=0; 取 σ_ε²×1e-3 仅为数值稳定
   %
   %   输入:
   %       price_hist - 训练期电价 (N×1)
   %       time_hist  - 训练期时间戳 (N×1 datetime)
   %       n_harm     - 谐波阶数 (默认 3)
   %       ar_order   - 残差 AR 阶数 (默认 4)
   %
   %   输出 model 结构体:
   %       .A, .Q, .R        - 状态转移 / 过程噪声 / 观测噪声
   %       .x0, .P0          - 预热后的初始滤波状态与协方差
   %       .n_harm, .ar_order, .nx
   %       .phi, .sigma_eps  - AR 系数与扰动标准差
   %       .coef0, .q_step, .r2_train - OLS 系数 / 步进噪声 / 拟合 R² (诊断)

   arguments
      price_hist (:,1) double
      time_hist  (:,1) datetime
      n_harm   (1,1) double = 3
      ar_order (1,1) double = 4
   end

   assert(n_harm >= 1 && ar_order >= 1, 'n_harm 与 ar_order 必须 ≥ 1');
   n_slots_day = 288;
   nx = 1 + 2*n_harm + ar_order;
   n_pts = length(price_hist);

   % ---- 1. 全局 OLS 谐波拟合 ----
   slot = get_slot_index(time_hist);
   X = harmonic_basis(slot, n_harm, n_slots_day);
   coef0 = X \ price_hist;
   resid = price_hist - X * coef0;
   r2_train = 1 - var(resid) / var(price_hist);

   % ---- 2. 残差 AR(p) 拟合 (OLS) ----
   r_now = resid(ar_order+1:end);
   R_lag = zeros(length(r_now), ar_order);
   for j = 1:ar_order
      R_lag(:, j) = resid(ar_order+1-j : end-j);
   end
   phi = R_lag \ r_now;
   eps_innov = r_now - R_lag * phi;
   sigma_eps = std(eps_innov);

   % ---- 3. 逐日系数差分 → Q ----
   day_ids = dateshift(time_hist - minutes(1), 'start', 'day');
   [unique_days, ~, day_group] = unique(day_ids);
   n_days = length(unique_days);
   assert(n_days >= 2, '训练期至少需要 2 天数据');

   coef_daily = zeros(1 + 2*n_harm, n_days);
   for d = 1:n_days
      mask = (day_group == d);
      assert(sum(mask) == n_slots_day, '训练数据应按天完整 (每天 288 点)');
      coef_daily(:, d) = harmonic_basis(slot(mask), n_harm, n_slots_day) \ price_hist(mask);
   end
   q_step = max(var(diff(coef_daily, 1, 2), 0, 2) / n_slots_day, 1e-6);

   % ---- 4. A / Q / R 矩阵 ----
   A = zeros(nx);
   A(1, 1) = 1;                                    % 趋势: 随机游走
   for k = 1:n_harm
      w = 2*pi*k / n_slots_day;
      Rk = [cos(w), sin(w); -sin(w), cos(w)];
      idx = 1 + 2*(k-1) + (1:2);
      A(idx, idx) = Rk;                            % 谐波块: 旋转矩阵
   end
   i_ar = 1 + 2*n_harm + 1;                        % AR 块起始索引
   A(i_ar, i_ar : i_ar+ar_order-1) = phi';
   A(i_ar+1 : nx, i_ar : nx-1) = eye(ar_order-1);  % 伴随矩阵下三角

   Q = zeros(nx);
   Q(1, 1) = q_step(1);                            % 趋势步进噪声
   for k = 1:n_harm
      Q(1 + 2*(k-1) + 1, 1 + 2*(k-1) + 1) = q_step(1 + 2*(k-1) + 1);
      Q(1 + 2*(k-1) + 2, 1 + 2*(k-1) + 2) = q_step(1 + 2*(k-1) + 2);
   end
   Q(i_ar, i_ar) = sigma_eps^2;                    % AR 扰动驱动

   R = max(sigma_eps^2 * 1e-3, 1e-4);              % 理论 R=0, 取极小值保数值稳定

   % ---- 5. 训练期卡尔曼滤波预热 ----
   x = [coef0; zeros(ar_order, 1)];
   P = sigma_eps^2 * eye(nx);
   core = struct('A', A, 'Q', Q, 'R', R, 'nx', nx, 'n_harm', n_harm, 'ar_order', ar_order);
   for i = 1:n_pts
      [x, P] = kalman_filter_step(x, P, price_hist(i), slot(i), core);
   end

   % ---- 输出 ----
   model.A = A;  model.Q = Q;  model.R = R;
   model.nx = nx;  model.n_harm = n_harm;  model.ar_order = ar_order;
   model.x0 = x;  model.P0 = P;
   model.phi = phi;  model.sigma_eps = sigma_eps;
   model.coef0 = coef0;  model.q_step = q_step;  model.r2_train = r2_train;
end

function X = harmonic_basis(slot, n_harm, n_slots_day)
   % HARMONIC_BASIS  谐波回归基 [1, sin θ1, cos θ1, ..., sin θK, cos θK]
   %   θ_k = 2πk(slot-1)/288, 槽位 1 (00:05) 相位为 0
   theta = 2*pi*(slot - 1) / n_slots_day;
   X = ones(numel(slot), 1);
   for k = 1:n_harm
      X = [X, sin(k*theta), cos(k*theta)];
   end
end