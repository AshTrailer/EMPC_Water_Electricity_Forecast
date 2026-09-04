function [templates, day_buf] = update_template_ewma(templates, day_buf, y_new_day, t_new_day, alpha, min_weight)
   % UPDATE_TEMPLATE_EWMA  类别内截断 EWMA 模板更新 (每天 00:00 调用)
   %
   %   把前一天完整一天的 profile 推入其类别的缓冲, 丢弃超出截断
   %   窗口 K 的最旧数据, 然后重算该类模板:
   %       template_c = Σ_{k=0}^{n-1} (1-α)^k · p_k / Σ_{k=0}^{n-1} (1-α)^k
   %
   %   与纯递归形式 template ← (1-α)·template + α·y 的区别:
   %       纯递归等价于无限记忆的指数平均 (权重永不为 0);
   %       本实现严格截断——权重 < min_weight 的历史被彻底丢弃,
   %       缓冲大小有界 (每类 ≤ K 天)。
   %
   %   类别分离: 只更新昨天所属类别的模板, 另一类保持不动。
   %       工作日模板每周更新 5 次, 周末模板每周更新 2 次,
   %       但两者的"类内有效记忆"一致 (都是约 1/α 个类内天)。
   %
   %   输入:
   %       templates  - 模板结构体 (init_ewma_state 输出)
   %       day_buf    - 日缓冲结构体 (init_ewma_state 输出)
   %       y_new_day  - 前一天 288 个观测 (288×1, 按时间升序)
   %       t_new_day  - 前一天 288 个时间戳 (288×1 datetime)
   %       alpha      - 遗忘因子 (0 < α ≤ 1)
   %       min_weight - 截断阈值 ε (0 < ε < 1)
   %
   %   输出:
   %       templates - 更新后的模板
   %       day_buf   - 更新后的缓冲

   arguments
      templates struct
      day_buf struct
      y_new_day (288,1) double
      t_new_day (288,1) datetime
      alpha (1,1) double
      min_weight (1,1) double = 0.01
   end

   assert(alpha > 0 && alpha <= 1, 'alpha 必须在 (0, 1] 内');
   assert(min_weight > 0 && min_weight < 1, 'min_weight 必须在 (0, 1) 内');
   assert(isfield(day_buf, 'wd_profiles') && isfield(day_buf, 'we_profiles'), ...
      'day_buf 未初始化, 请先用 init_ewma_state 创建');

   K = max(1, floor(log(min_weight) / log(1 - alpha)));

   % ---- 前一天类别 (288 点应同属一个数据日) ----
   day_class = get_day_class(t_new_day(1));
   assert(all(get_day_class(t_new_day) == day_class), ...
      'update_template_ewma: 输入时间戳跨越类别边界, 应为完整的一天');

   % ---- 前一天 profile 按槽位对齐 ----
   prof = zeros(288, 1);
   prof(get_slot_index(t_new_day)) = y_new_day;

   % ---- 推入对应类别缓冲 (最新在前), 裁剪到 K, 重算该类模板 ----
   if day_class == 1
      day_buf.wd_profiles = [{prof}, day_buf.wd_profiles];
      if numel(day_buf.wd_profiles) > K
         day_buf.wd_profiles = day_buf.wd_profiles(1:K);
      end
      templates.values(1, :) = weighted_profile_mean(day_buf.wd_profiles, alpha);
   else
      day_buf.we_profiles = [{prof}, day_buf.we_profiles];
      if numel(day_buf.we_profiles) > K
         day_buf.we_profiles = day_buf.we_profiles(1:K);
      end
      templates.values(2, :) = weighted_profile_mean(day_buf.we_profiles, alpha);
   end

   templates.counts = [numel(day_buf.wd_profiles); numel(day_buf.we_profiles)];
   day_buf.max_k = K;
end