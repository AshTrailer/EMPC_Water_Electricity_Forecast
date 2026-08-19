function [pred_mean, pred_sd, pred_harm] = kalman_predict_288(x_now, P_now, slot_now, model)
   % KALMAN_PREDICT_288  谐波状态空间 288 步预测 (每天 00:00 调用)
   %
   %   预测均值: x̂(t+h|t) = A^h x̂(t|t),  ŷ(t+h) = C(t+h) x̂(t+h|t)
   %   预测协方差 (理论预测误差):
   %       P(t+h|t) = A P(t+h-1|t) A' + Q   (闭式递推)
   %       σ_ŷ(h)   = sqrt(C P(t+h|t) C' + R)
   %
   %   谐波块 A^h 解析: 旋转 h·ω_k 角; h=288 旋转一圈 = I,
   %   所以 24h 预测的谐波部分与当前时刻相位自洽。
   %
   %   输入:
   %       x_now, P_now - 当前时刻 (t) 滤波状态与协方差
   %       slot_now     - 当前时刻槽位 (前一天 24:00 → 288)
   %       model        - 模型结构体
   %   输出:
   %       pred_mean - 288×1 电价预测
   %       pred_sd   - 288×1 预测标准差 (95% 带 = ±1.96·σ)
   %       pred_harm - 288×1 周期分量预测 (μ + 谐波, 不含 AR 残差)
   %                   → 用于展示"周期结构本身捕捉了多少"

   arguments
      x_now (:,1) double
      P_now (:,:) double
      slot_now (1,1) double
      model struct
   end

   n_slots_day = 288;
   x_pred = x_now;
   P_pred = P_now;
   pred_mean = zeros(n_slots_day, 1);
   pred_sd   = zeros(n_slots_day, 1);
   pred_harm = zeros(n_slots_day, 1);

   i_ar = 1 + 2*model.n_harm + 1;

   for h = 1:n_slots_day
      x_pred = model.A * x_pred;
      P_pred = model.A * P_pred * model.A' + model.Q;
      P_pred = (P_pred + P_pred') / 2;

      slot_pred = mod(slot_now - 1 + h, n_slots_day) + 1;
      C = make_harmonic_C(model, slot_pred);
      pred_mean(h) = C * x_pred;
      pred_sd(h)   = sqrt(C * P_pred * C' + model.R);

      C_harm = C;  C_harm(i_ar) = 0;
      pred_harm(h) = C_harm * x_pred;
   end
end