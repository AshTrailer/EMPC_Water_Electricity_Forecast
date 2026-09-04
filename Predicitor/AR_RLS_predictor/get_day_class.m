function class_id = get_day_class(t)
   % GET_DAY_CLASS  判断采样点所属"数据日"是工作日还是周末
   %
   %   数据日定义: 每天的采样序列为 00:05 ~ 24:00, 其中 24:00 的
   %   采样点属于当天 (即前一天的最后一个点)。因此先把时间戳
   %   回拨 1 分钟再查星期, 保证 24:00 归入前一天。
   %
   %   MATLAB weekday(): 1=周日, 2=周一, ..., 7=周六
   %   映射: 工作日(周一~周五) → 1, 周末(周六/周日) → 2
   %
   %   注: 公共假日 (如 1/1 元旦、1/26 澳洲国庆日) 当前归为工作日。
   %   维州 2026 年公共假日表可后续在此维护, 强制映射为周末类。
   %   2 月测试期无公共假日, 只影响 1 月训练模板的纯净度。
   %
   %   输入:
   %       t - datetime 标量或向量
   %   输出:
   %       class_id - 与 t 同尺寸, 1=工作日, 2=周末

   arguments
      t datetime
   end

   t_data_day = t - minutes(1);     % 24:00 的采样点归入前一天
   wd = weekday(t_data_day);
   class_id = ones(size(wd));
   class_id(wd == 1 | wd == 7) = 2; % 周日或周六 → 周末
end