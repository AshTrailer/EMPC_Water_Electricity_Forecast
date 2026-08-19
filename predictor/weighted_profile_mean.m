function mean_prof = weighted_profile_mean(profiles, alpha)
   % WEIGHTED_PROFILE_MEAN  日 profile 序列的指数加权平均
   %
   %   输入:
   %       profiles - cell 数组, 每个元素为 288×1 日 profile, 最新在前
   %       alpha    - 遗忘因子 (0 < α ≤ 1)
   %
   %   权重: w_k = (1-α)^k, k=0 为最新一天, 权重总和归一化
   %
   %   输出:
   %       mean_prof - 288×1 加权平均 profile

   n = numel(profiles);
   if n == 0
      mean_prof = zeros(288, 1);
      return;
   end

   w = (1 - alpha).^(0:n-1)';
   acc = zeros(288, 1);
   for k = 1:n
      acc = acc + w(k) * profiles{k};
   end
   mean_prof = acc / sum(w);
end