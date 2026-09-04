function data = load_aemo_data(data_folder)
   % LOAD_AEMO_DATA  批量读取AEMO电价与需求CSV文件
   %
   %   data = load_aemo_data(data_folder)
   %
   %   输入:
   %       data_folder  - 存放CSV文件的文件夹路径 (字符串)
   %
   %   输出:
   %       data - 结构体，包含以下字段:
   %           .time          : datetime 向量 (5分钟间隔)
   %           .price         : 电价 RRP ($/MWh)
   %           .demand        : 总需求 TOTALDEMAND (MW)
   %           .region        : 区域名称 (字符串)
   %           .num_months    : 加载的月份数
   %           .file_list     : 读取的文件列表

   arguments
      data_folder (1,1) string = "data"
   end

   % 查找所有匹配的CSV文件 (兼容单点和双点命名)
   file_pattern = fullfile(data_folder, "PRICE_AND_DEMAND_*VIC1*.csv");
   file_info = dir(file_pattern);

   if isempty(file_info)
      error("未找到匹配的CSV文件。请检查路径: %s", data_folder);
   end

   n_files = length(file_info);
   fprintf("找到 %d 个数据文件:\n", n_files);

   % 预分配存储
   all_time   = [];
   all_price  = [];
   all_demand = [];

   for i = 1:n_files
      fname = fullfile(file_info(i).folder, file_info(i).name);
      fprintf("  正在读取: %s\n", file_info(i).name);

      % 读取CSV (假设第一行为表头)
      opts = detectImportOptions(fname);
      opts.VariableNamingRule = "preserve";  % 保留原始列名
      tbl = readtable(fname, opts);

      % 验证必要的列存在
      required_cols = ["SETTLEMENTDATE", "RRP", "TOTALDEMAND"];
      col_names = string(tbl.Properties.VariableNames);
      for c = required_cols
         if ~any(col_names == c)
            error("文件 %s 缺少列: %s", file_info(i).name, c);
         end
      end

      % 解析时间戳
      time_col = tbl.SETTLEMENTDATE;
      if iscell(time_col) || isstring(time_col)
         time_dt = datetime(time_col, "InputFormat", "yyyy/M/d H:mm");
      else
         time_dt = datetime(time_col);
      end

      % 提取电价和需求
      price_col  = tbl.RRP;
      demand_col = tbl.TOTALDEMAND;

      % 拼接
      all_time   = [all_time;   time_dt(:)];
      all_price  = [all_price;  price_col(:)];
      all_demand = [all_demand; demand_col(:)];
   end

   % 按时间排序 (以防文件读取顺序混乱)
   [all_time, sort_idx] = sort(all_time);
   all_price  = all_price(sort_idx);
   all_demand = all_demand(sort_idx);

   % 检查时间连续性并报告缺口
   expected_dt = minutes(5);
   time_diffs = diff(all_time);
   gaps = find(time_diffs > expected_dt * 1.5);
   if ~isempty(gaps)
      fprintf("\n警告: 发现 %d 个时间缺口:\n", length(gaps));
      for g_idx = 1:min(length(gaps), 10)
         g = gaps(g_idx);
         fprintf("  %s -> %s (间隔 %.0f 分钟)\n", ...
            char(all_time(g)), char(all_time(g+1)), minutes(time_diffs(g)));
      end
      if length(gaps) > 10
         fprintf("  ... (还有 %d 个缺口未列出)\n", length(gaps) - 10);
      end
   end

   % 组装输出结构体
   data.time       = all_time;
   data.price      = all_price;    % $/MWh
   data.demand     = all_demand;   % MW
   data.region     = "VIC1";
   data.num_months = n_files;
   data.file_list  = {file_info.name}';

   % 打印汇总信息
   fprintf("\n数据加载完成:\n");
   fprintf("  时间范围: %s ~ %s\n", char(all_time(1)), char(all_time(end)));
   fprintf("  数据点数: %d\n", length(all_time));
   fprintf("  电价范围: %.2f ~ %.2f $/MWh\n", min(all_price), max(all_price));
   fprintf("  需求范围: %.2f ~ %.2f MW\n", min(all_demand), max(all_demand));
   fprintf("  采样间隔: %d 分钟\n", minutes(expected_dt));
end