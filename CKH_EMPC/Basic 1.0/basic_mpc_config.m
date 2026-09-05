function config = basic_mpc_config()
%BASIC_MPC_CONFIG 基础水箱 MPC 的统一参数。
% MPC 只计算连续的期望总流量；具体水泵组合由 Decision 模块负责。

% 物理模型参数
config.dt_seconds = 3600;
config.tank_area_m2 = 1000;
config.max_requested_flow_m3s = 0.050;

% 水位硬约束和初始状态
config.level_min_m = 1.40;
config.level_max_m = 3.37;
config.level_initial_m = 2.30;

% MPC 设置：每步 1 小时，向前预测 24 小时
config.horizon_steps = 24;
config.u_min = 0.0;
config.u_max = 1.0;
config.du_max = 0.35;

% 目标函数权重：水位跟踪、输入大小和输入变化量
config.weight_level = 50.0;
config.weight_input = 0.02;
config.weight_move = 0.50;
end
