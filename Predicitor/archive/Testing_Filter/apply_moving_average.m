function [y_filt, buf] = apply_moving_average(y_new, buf, window_size)
   % APPLY_MOVING_AVERAGE  在线移动平均滤波器
   %
   %   每次接收一个新数据点，输出当前窗口内的平均值。
   %   适合实时应用场景 (与MPC在线计算兼容)。
   %
   %   输入:
   %       y_new       - 新数据点 (标量)
   %       buf         - 滤波器状态 (首次可传入 struct(), [], 或任意值)
   %       window_size - 移动窗口大小 (正整数, 如6点=30分钟)
   %
   %   输出:
   %       y_filt - 滤波后的值 (标量)
   %       buf    - 更新后的滤波器状态结构体

   arguments
      y_new       (1,1) double
      buf
      window_size (1,1) double {mustBeInteger, mustBePositive}
   end

   % ---- 健壮的初始化检查 ----
   % 检查 buf 是否是一个拥有必需字段的结构体
   needs_init = ~isstruct(buf) || ...
                ~isfield(buf, 'buffer') || ...
                ~isfield(buf, 'idx') || ...
                ~isfield(buf, 'pos');

   if needs_init
      buf.buffer = zeros(window_size, 1);
      buf.idx    = 0;          % 已填充的元素计数
      buf.pos    = 1;          % 环形缓冲区写入位置
   end

   % ---- 环形缓冲区写入 ----
   buf.buffer(buf.pos) = y_new;
   buf.pos = buf.pos + 1;
   if buf.pos > window_size
      buf.pos = 1;
   end
   buf.idx = min(buf.idx + 1, window_size);

   % ---- 计算当前窗口均值 ----
   if buf.idx < window_size
      y_filt = mean(buf.buffer(1:buf.idx));
   else
      y_filt = mean(buf.buffer);
   end
end