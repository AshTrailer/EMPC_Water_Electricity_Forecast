function slot = get_slot_index(t)
   % GET_SLOT_INDEX  将时间戳映射到一天内的槽位 (1~288)
   %
   %   5 分钟采样: 00:05 → 1, 00:10 → 2, ..., 23:55 → 287, 00:00 → 288
   %   注意 00:00 属于前一天的最后一个槽位 (288)。
   %
   %   输入:
   %       t - datetime 标量或向量
   %   输出:
   %       slot - 与 t 同尺寸, 取值 1~288

   arguments
      t datetime
   end

   minutes_of_day = hour(t) * 60 + minute(t);
   slot = round(minutes_of_day / 5);
   slot(slot == 0) = 288;   % 00:00 → 槽位 288
end