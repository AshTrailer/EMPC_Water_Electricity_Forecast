function y_pred = predict_ar_recursive(theta, history, horizon)
   % PREDICT_AR_RECURSIVE  AR模型递归(iterated)多步预测
   %
   %   在时刻 t，用冻结的 AR 系数 θ 对未来 horizon 步做递归预测:
   %       ŷ(t+1|t)   = θ'·[y(t); ...; y(t-p+1)]
   %       ŷ(t+s|t)   = θ'·[ŷ(t+s-1|t); ...]   (预测值回填缓冲)
   %
   %   预测期间系数保持不变（冻结），这是"递归预测"的定义：
   %   每个预测值作为输入用于下一步预测，误差沿时域累积。
   %
   %   输入:
   %       theta   - AR 系数 (p×1)，theta(j) 对应滞后 j 的系数
   %       history - 最近 p 个观测 (p×1)，history(1) 是最新观测
   %                 （顺序与 apply_rls_filter 的 state.history 一致）
   %       horizon - 预测步数 h (正整数)
   %
   %   输出:
   %       y_pred - (horizon×1)，y_pred(s) = ŷ(t+s|t)

   arguments
      theta   (:,1) double
      history (:,1) double
      horizon (1,1) double {mustBeInteger, mustBePositive}
   end

   p = length(theta);
   assert(length(history) == p, ...
      'history 长度 (%d) 必须等于 AR 阶数 p (%d)', length(history), p);

   buf = history;                 % 最新在前
   y_pred = zeros(horizon, 1);

   for s = 1:horizon
      y_pred(s) = theta' * buf;              % 一步预测
      buf = [y_pred(s); buf(1:end-1)];       % 预测值进入缓冲 → 递归
   end
end