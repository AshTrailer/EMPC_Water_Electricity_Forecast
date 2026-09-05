classdef WaterTankSystem < handle
   % WATERTANKSYSTEM  基于质量守恒的水箱仿真模型
   %
   %   动力学方程:
   %       x(k+1) = x(k) + (dt / S) * (q_in(k) - q_out(k))
   %
   %   其中:
   %       x     - 水位 (m)
   %       dt    - 仿真步长 (s)
   %       S     - 水箱底面积 (m²)
   %       q_in  - 总入流量 (m³/s)
   %       q_out - 总出流量 (m³/s)

   properties
      S           (1,1) double  % 底面积 (m²)
      dt          (1,1) double  % 仿真步长 (s)
      x_min       (1,1) double  % 最低水位 (m)
      x_max       (1,1) double  % 最高水位 (m)
      x           (1,1) double  % 当前水位 (m)
   end

   properties (Access = private)
      disturbance_enabled (1,1) logical = false
      disturbance_std     (1,1) double  = 0
      rng_state           % 随机数生成器状态
   end

   methods
      function obj = WaterTankSystem(cfg)
         % 构造函数
         %   cfg: system_config() 返回的配置结构体
         obj.S     = cfg.tank.S;
         obj.dt    = cfg.sim.dt_control;
         obj.x_min = cfg.tank.x_min;
         obj.x_max = cfg.tank.x_max;
         obj.x     = cfg.tank.x0;

         % 扰动设置
         if isfield(cfg, 'disturbance') && cfg.disturbance.enabled
            obj.disturbance_enabled = true;
            obj.disturbance_std = cfg.disturbance.std_ratio;
            rng(cfg.disturbance.seed);
            obj.rng_state = rng;
         end

         fprintf("水箱系统初始化: S=%.0f m², dt=%.0f s, x0=%.2f m\n", ...
            obj.S, obj.dt, obj.x);
      end

      function [q_out_actual, x_new] = step(obj, q_in, q_out_nominal)
         % STEP  单步仿真推进
         %
         %   输入:
         %       q_in          - 入流量 (m³/s)，通常来自泵站
         %       q_out_nominal - 标称出流量 (m³/s)，通常为需求预测值
         %
         %   输出:
         %       q_out_actual  - 实际出流量 (含扰动) (m³/s)
         %       x_new         - 更新后的水位 (m)

         arguments
            obj
            q_in  (1,1) double
            q_out_nominal (1,1) double
         end

         % 施加扰动到出流量 (模拟需求波动)
         if obj.disturbance_enabled && obj.disturbance_std > 0
            noise_std = abs(q_out_nominal) * obj.disturbance_std;
            noise = noise_std * randn();
            q_out_actual = q_out_nominal + noise;
         else
            q_out_actual = q_out_nominal;
         end

         % 确保出流量非负 (物理约束)
         q_out_actual = max(q_out_actual, 0);

         % 欧拉离散化的质量守恒
         x_new = obj.x + (obj.dt / obj.S) * (q_in - q_out_actual);

         % 硬约束：水位不能超出物理范围
         % 超出上限意味着溢流 (在日志中可记录)
         % 低于下限意味着供水失败 (此处仅做截断警告)
         if x_new > obj.x_max
            fprintf("警告: 水位 %.3f m 超出上限 %.2f m (可能溢流)\n", ...
               x_new, obj.x_max);
         end
         if x_new < obj.x_min
            fprintf("警告: 水位 %.3f m 低于下限 %.2f m (供水不足风险)\n", ...
               x_new, obj.x_min);
         end

         % 更新内部状态
         obj.x = x_new;
      end

      function reset(obj, x0)
         % RESET  重置水位到指定值
         arguments
            obj
            x0 (1,1) double = 3.12
         end
         obj.x = x0;
         if obj.disturbance_enabled
            rng(obj.rng_state);  % 重置随机种子
         end
         fprintf("水箱水位重置为: %.2f m\n", obj.x);
      end

      function [feasible, reason] = is_feasible(obj)
         % IS_FEASIBLE  检查当前水位是否在允许范围内
         if obj.x < obj.x_min
            feasible = false;
            reason = sprintf("水位过低: %.3f < %.2f", obj.x, obj.x_min);
         elseif obj.x > obj.x_max
            feasible = false;
            reason = sprintf("水位过高: %.3f > %.2f", obj.x, obj.x_max);
         else
            feasible = true;
            reason = "";
         end
      end

      function [q_max_in, q_max_out] = get_flow_limits(obj, dt_override)
         % GET_FLOW_LIMITS  计算在当前水位下允许的最大入流/出流
         %   使得下一步水位不越界 (用于MPC约束构建)

         if nargin < 2
            dt_override = obj.dt;
         end

         % 最大允许入流 (使水位从当前值升到 x_max)
         q_max_in  = (obj.x_max - obj.x) * obj.S / dt_override;
         % 最大允许出流 (使水位从当前值降到 x_min)
         q_max_out = (obj.x - obj.x_min) * obj.S / dt_override;

         q_max_in  = max(q_max_in, 0);
         q_max_out = max(q_max_out, 0);
      end
   end
end