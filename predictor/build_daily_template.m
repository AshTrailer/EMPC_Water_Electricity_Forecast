function templates = build_daily_template(price_hist, time_hist, mode, window)
   % BUILD_DAILY_TEMPLATE  从历史数据构建日均值模板
   %
   %   模板: 一天 288 个槽位 (每 5 分钟一个)，每个槽位 = 该时刻历史均价。
   %
   %   输入:
   %       price_hist - 历史电价 (N×1)
   %       time_hist  - 对应时间戳 (N×1 datetime)
   %       mode       - "none" | "weekday_weekend"
   %       window     - 窗口定义:
   %                       Inf        → 全部历史
   %                       标量 N     → 最近 N 个日历天
   %                       [wd, we]   → 类别内窗口: 工作日取最近 wd 个工作日,
   %                                     周末取最近 we 个周末日
   %                                     (解决连续日历窗口内周末样本数
   %                                      远少于工作日的问题)
   %
   %   输出:
   %       templates - 结构体: .mode, .values (n_class×288), .counts

   arguments
      price_hist (:,1) double
      time_hist  (:,1) datetime
      mode       (1,1) string = "weekday_weekend"
      window            = Inf
   end

   % ---- 参数校验 (用 assert 代替 arguments 块多参验证函数) ----
   assert(any(mode == ["none", "weekday_weekend"]), ...
      'mode 必须是 "none" 或 "weekday_weekend"');

   n_slots = 288;

   % ---- 类别映射 ----
   if mode == "none"
      class_ids = ones(size(time_hist));
      n_class = 1;
   else
      class_ids = get_day_class(time_hist);
      n_class = 2;
   end

   % ---- 时间窗口 ----
   keep = true(size(time_hist));
   if isnumeric(window) && isscalar(window) && isfinite(window)
      % 标量: 最近 N 个日历天
      keep = time_hist > (time_hist(end) - days(window));
   elseif isnumeric(window) && numel(window) == 2
      assert(all(window >= 1), '类别内窗口 [wd, we] 各分量必须 ≥ 1');
      keep = per_class_window_mask(time_hist, class_ids, window(1), window(2));
   end

   price_hist = price_hist(keep);
   time_hist  = time_hist(keep);
   class_ids  = class_ids(keep);

   % ---- 逐点累加 ----
   sum_vals = zeros(n_class, n_slots);
   cnt_vals = zeros(n_class, n_slots);

   for i = 1:length(price_hist)
      s = get_slot_index(time_hist(i));
      c = class_ids(i);
      sum_vals(c, s) = sum_vals(c, s) + price_hist(i);
      cnt_vals(c, s) = cnt_vals(c, s) + 1;
   end

   % ---- 均值 + 缺失槽位回退 ----
   values = zeros(n_class, n_slots);
   for c = 1:n_class
      for s = 1:n_slots
         if cnt_vals(c, s) > 0
            values(c, s) = sum_vals(c, s) / cnt_vals(c, s);
         else
            filled = cnt_vals(c, :) > 0;
            if any(filled)
               values(c, s) = mean(values(c, filled));
            end
         end
      end
   end

   templates.mode   = mode;
   templates.values = values;
   templates.counts = cnt_vals;
end

function keep = per_class_window_mask(time_hist, class_ids, wd_days, we_days)
   % PER_CLASS_WINDOW_MASK  类别内时间窗口掩码
   %
   %   从最新往回数: 工作日保留最近 wd_days 个工作日,
   %                 周末保留最近 we_days 个周末日。
   %
   %   效果: wd_days = 7 时, 工作日模板覆盖约 1.4 个日历周,
   %         we_days = 7 时, 周末模板覆盖 7 个日历周——
   %         两类样本数一致, 统计方差对齐。

   day_ids = dateshift(time_hist - minutes(1), 'start', 'day');
   [unique_days, ~, day_group] = unique(day_ids);
   n_days = length(unique_days);

   % 每一天的类别 (取该天第一个采样点)
   day_class = zeros(n_days, 1);
   for d = 1:n_days
      day_class(d) = class_ids(find(day_group == d, 1));
   end

   keep_days = false(n_days, 1);
   n_wd = 0;  n_we = 0;
   for d = n_days:-1:1
      if day_class(d) == 1
         if n_wd < wd_days
            keep_days(d) = true;
            n_wd = n_wd + 1;
         end
      else
         if n_we < we_days
            keep_days(d) = true;
            n_we = n_we + 1;
         end
      end
   end

   keep = ismember(day_group, find(keep_days));
end