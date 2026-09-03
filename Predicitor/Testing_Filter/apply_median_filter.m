function [y_filt, buf] = apply_median_filter(y_new, buf, window_size)
   % APPLY_MEDIAN_FILTER  在线移动中值滤波器
   %
   %   与移动平均相比，中值滤波对尖峰/异常值更鲁棒，
   %   但计算成本略高 (需要排序)。
   %
   %   输入/输出接口与 apply_moving_average 一致。

   arguments
      y_new       (1,1) double
      buf
      window_size (1,1) double {mustBeInteger, mustBePositive}
   end

   % ---- 健壮的初始化检查 ----
   needs_init = ~isstruct(buf) || ...
                ~isfield(buf, 'buffer') || ...
                ~isfield(buf, 'idx') || ...
                ~isfield(buf, 'pos');

   if needs_init
      buf.buffer = zeros(window_size, 1);
      buf.idx    = 0;
      buf.pos    = 1;
   end

   % ---- 环形缓冲区写入 ----
   buf.buffer(buf.pos) = y_new;
   buf.pos = buf.pos + 1;
   if buf.pos > window_size
      buf.pos = 1;
   end
   buf.idx = min(buf.idx + 1, window_size);

   % ---- 计算当前窗口中值 ----
   if buf.idx < window_size
      y_filt = median(buf.buffer(1:buf.idx));
   else
      y_filt = median(buf.buffer);
   end
end