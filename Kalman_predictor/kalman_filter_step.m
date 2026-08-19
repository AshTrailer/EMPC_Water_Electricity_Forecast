function [x, P, innov] = kalman_filter_step(x, P, y_obs, slot, model)
   % KALMAN_FILTER_STEP  单步卡尔曼滤波 (预测 + 更新)
   %
   %   时间语义: 输入 x, P 为 t-1 时刻滤波状态 x(t-1|t-1);
   %   先预测到 t:  x(t|t-1) = A x(t-1|t-1)
   %                P(t|t-1) = A P(t-1|t-1) A' + Q
   %   再用观测 y(t) 更新:
   %                K = P(t|t-1) C' / (C P(t|t-1) C' + R)
   %                x(t|t) = x(t|t-1) + K [y(t) - C x(t|t-1)]
   %
   %   输入:
   %       x, P  - t-1 时刻滤波状态与协方差
   %       y_obs - t 时刻观测电价
   %       slot  - t 时刻槽位 (1..288)
   %       model - 模型结构体 (.A, .Q, .R, .nx, ...)
   %   输出:
   %       x, P  - t 时刻滤波状态与协方差
   %       innov - 新息 y(t) - C x(t|t-1)

   x = model.A * x;
   P = model.A * P * model.A' + model.Q;
   P = (P + P') / 2;

   C = make_harmonic_C(model, slot);
   S = C * P * C' + model.R;
   K = P * C' / S;
   innov = y_obs - C * x;
   x = x + K * innov;
   P = (eye(model.nx) - K * C) * P;
   P = (P + P') / 2;
end