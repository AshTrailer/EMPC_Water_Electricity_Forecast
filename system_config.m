function cfg = system_config()
   % SYSTEM_CONFIG  生成系统仿真所需的配置参数
   %
   %   返回一个结构体 cfg，所有模块通过 cfg 获取参数，
   %   方便集中管理和调整。

   % ============ 水箱参数 ============
   cfg.tank.S     = 1000;        % 水箱底面积 (m^2)
   cfg.tank.x_min = 1.4;        % 最低运行水位 (m)
   cfg.tank.x_max = 3.37;       % 最高运行水位 (m)
   cfg.tank.x0    = 3.12;       % 初始水位 (m)，与论文一致

   % ============ 仿真步长 ============
   cfg.sim.dt_control  = 300;   % 控制步长 (s), 默认5分钟与AEMO数据对齐
   cfg.sim.dt_hydraulic = 60;   % 水力仿真步长 (s), 可选更细粒度

   % ============ 泵站参数 ============
   % 泵站1: 2台同型号并联泵
   cfg.pump(1).n_total      = 2;           % 可用泵总数
   cfg.pump(1).flow_per_pump = 0.025;      % 单泵额定出流量 (m³/s), 约25 L/s
   cfg.pump(1).power_per_pump = 46.0;      % 单泵额定功率 (kW)
   cfg.pump(1).efficiency   = 0.66;        % 额定效率
   cfg.pump(1).name         = "PS1";

   % 泵站2: 1台增压泵
   cfg.pump(2).n_total      = 1;
   cfg.pump(2).flow_per_pump = 0.021;      % 约21 L/s
   cfg.pump(2).power_per_pump = 21.4;      % kW
   cfg.pump(2).efficiency   = 0.60;
   cfg.pump(2).name         = "PS2";

   % ============ 扰动配置 ============
   cfg.disturbance.enabled    = true;        % 是否启用出流扰动
   cfg.disturbance.type       = "gaussian";  % 扰动类型: "gaussian" | "uniform" | "none"
   cfg.disturbance.std_ratio  = 0.05;        % 标准差相对于当前出流量的比例 (5%)
   cfg.disturbance.seed       = 2024;        % 随机种子 (可复现)

   % ============ 需求/电价数据配置 ============
   cfg.data.folder    = "data";              % AEMO数据文件夹
   cfg.data.price_unit = "$/MWh";            % 电价单位 (用于标注图表)

   % ============ 滤波器默认参数 ============
   cfg.filter.ma_window  = 6;     % 移动平均窗口大小 (6点 = 30分钟)
   cfg.filter.med_window = 6;     % 移动中值窗口大小
   cfg.filter.rls_lambda = 0.98;  % RLS遗忘因子 (0<λ≤1, 越小适应性越强)
   cfg.filter.rls_delta  = 100;   % RLS初始协方差 = δ*I
   cfg.filter.rls_order  = 4;     % RLS使用的AR模型阶数

   fprintf("系统配置已加载。\n");
   fprintf("  水箱: S=%.0f m², 水位范围 [%.1f, %.1f] m\n", ...
      cfg.tank.S, cfg.tank.x_min, cfg.tank.x_max);
   fprintf("  泵站: %d 个泵站, 控制步长 %d s\n", ...
      length(cfg.pump), cfg.sim.dt_control);
end