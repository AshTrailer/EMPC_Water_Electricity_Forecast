function [templates, day_buf] = init_ewma_state(price_hist, time_hist, alpha, min_weight)
   % INIT_EWMA_STATE  初始化"类别内截断EWMA"的模板与日缓冲
   %
   %   截断 EWMA: 模板 = 缓冲内各天 profile 的指数加权平均
   %       template_c = Σ_{k=0}^{n-1} (1-α)^k · p_k / Σ_{k=0}^{n-1} (1-α)^k
   %       p_0 = 最新一天, p_{n-1} = 最旧一天
   %
   %   截断规则: 只保留权重 (1-α)^k ≥ min_weight 的天, 即每类最多
   %       K = floor(log(min_weight) / log(1-α))  个类内天
   %   例如 α=0.15, ε=0.01 → K=28。
   %   缓冲大小严格有界: 2 类 × K 天 × 288 点, 无无限记忆问题。
   %
   %   类别分离: 工作日与周末各自独立维护缓冲和遗忘——
   %   工作日模板每周更新 5 次, 周末模板每周更新 2 次, 但两者的
   %   "类内有效记忆"一致 (都是约 1/α 个类内天)。
   %
   %   输入:
   %       price_hist - 历史电价 (N×1)
   %       time_hist  - 时间戳 (N×1 datetime)
   %       alpha      - 遗忘因子 (0 < α ≤ 1)
   %       min_weight - 截断阈值 ε (0 < ε < 1)
   %
   %   输出:
   %       templates - 模板结构体 (.values 为 2×288 加权平均)
   %       day_buf   - 日缓冲: .wd_profiles / .we_profiles (cell, 最新在前)

   arguments
      price_hist (:,1) double
      time_hist  (:,1) datetime
      alpha      (1,1) double
      min_weight (1,1) double = 0.01
   end

   assert(alpha > 0 && alpha <= 1, 'alpha 必须在 (0, 1] 内');
   assert(min_weight > 0 && min_weight < 1, 'min_weight 必须在 (0, 1) 内');

   K = max(1, floor(log(min_weight) / log(1 - alpha)));

   % ---- 按数据日拆分 (24:00 采样点归入前一天) ----
   day_ids = dateshift(time_hist - minutes(1), 'start', 'day');
   [unique_days, ~, day_group] = unique(day_ids);
   n_days = length(unique_days);

   day_buf.wd_profiles = {};
   day_buf.we_profiles = {};
   day_buf.max_k = K;

   for d = 1:n_days
      mask = day_group == d;
      t_day = time_hist(mask);
      y_day = price_hist(mask);
      prof = zeros(288, 1);
      prof(get_slot_index(t_day)) = y_day;
      c = get_day_class(t_day(1));
      if c == 1
         day_buf.wd_profiles = [{prof}, day_buf.wd_profiles];  % 最新在前
      else
         day_buf.we_profiles = [{prof}, day_buf.we_profiles];
      end
   end

   % ---- 裁剪到截断窗口 ----
   if numel(day_buf.wd_profiles) > K
      day_buf.wd_profiles = day_buf.wd_profiles(1:K);
   end
   if numel(day_buf.we_profiles) > K
      day_buf.we_profiles = day_buf.we_profiles(1:K);
   end

   % ---- 初始模板 = 缓冲加权平均 ----
   templates.mode = "weekday_weekend";
   templates.values = zeros(2, 288);
   templates.values(1, :) = weighted_profile_mean(day_buf.wd_profiles, alpha);
   templates.values(2, :) = weighted_profile_mean(day_buf.we_profiles, alpha);
   templates.counts = [numel(day_buf.wd_profiles); numel(day_buf.we_profiles)];
end