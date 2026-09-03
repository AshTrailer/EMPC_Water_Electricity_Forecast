classdef PumpStation < handle
   % PUMPSTATION  泵站模型 (多台同型号并联泵)
   %
   %   简化为: 出流量 ≈ n_on * flow_per_pump
   %           功率   ≈ n_on * power_per_pump (不考虑扬程变化)
   %
   %   这种简化与论文公式 (2) 和 (16) 的思路一致。

   properties
      n_total       (1,1) double  % 可用泵总数
      flow_per_pump (1,1) double  % 单泵额定出流量 (m³/s)
      power_per_pump (1,1) double % 单泵额定功率 (kW)
      efficiency    (1,1) double  % 额定效率 (0~1)
      name          (1,1) string  % 泵站名称
   end

   properties (SetAccess = private)
      n_on (1,1) double = 0       % 当前运行台数
   end

   methods
      function obj = PumpStation(pump_cfg)
         % 构造函数
         %   pump_cfg: cfg.pump(i) 结构体
         obj.n_total        = pump_cfg.n_total;
         obj.flow_per_pump  = pump_cfg.flow_per_pump;
         obj.power_per_pump = pump_cfg.power_per_pump;
         obj.efficiency     = pump_cfg.efficiency;
         obj.name           = pump_cfg.name;

         fprintf("泵站 %s 初始化: %d 台泵, 单泵流量 %.4f m³/s, 功率 %.1f kW\n", ...
            obj.name, obj.n_total, obj.flow_per_pump, obj.power_per_pump);
      end

      function [q_out, power, energy] = get_output(obj, n_on)
         % GET_OUTPUT  给定运行台数，计算总出流量、功率和单位步长能耗
         %
         %   输入:
         %       n_on - 运行泵台数 (整数, 0 ≤ n_on ≤ n_total)
         %
         %   输出:
         %       q_out  - 总出流量 (m³/s)
         %       power  - 总功率 (kW)
         %       energy - 单位时间步长的能耗 (kJ) [需要外部乘以dt得到kWh]

         % ---- 输入验证 (手动实现，避免 arguments 块的版本兼容问题) ----
         validateattributes(n_on, {'numeric'}, ...
            {'scalar', 'integer', '>=', 0, '<=', obj.n_total}, ...
            'PumpStation.get_output', 'n_on');

         obj.n_on = n_on;
         q_out  = n_on * obj.flow_per_pump;
         power  = n_on * obj.power_per_pump;
         energy = power * 1.0;  % 每秒钟的能耗 (kJ, 因为kW = kJ/s)
      end

      function [q_out, power] = get_output_continuous(obj, n_continuous)
         % GET_OUTPUT_CONTINUOUS  连续松弛版本 (用于MPC中远期预测)
         %   输入 n_continuous 可以是小数，线性插值
         %
         %   这个函数对应论文中 "treated as continuous variables" 的处理

         validateattributes(n_continuous, {'numeric'}, ...
            {'scalar', 'nonnegative'}, ...
            'PumpStation.get_output_continuous', 'n_continuous');

         % 钳制到有效范围
         n_clamped = max(0, min(n_continuous, obj.n_total));
         q_out  = n_clamped * obj.flow_per_pump;
         power  = n_clamped * obj.power_per_pump;
      end

      function cost_per_step = compute_energy_cost(obj, n_on, price, dt)
         % COMPUTE_ENERGY_COST  计算单个时间步的能耗成本
         %
         %   输入:
         %       n_on  - 运行台数
         %       price - 电价 (对应论文中的 α(k))
         %       dt    - 步长 (s)
         %
         %   输出:
         %       cost_per_step - 该步能耗成本 (货币单位与price一致)

         [~, power, ~] = obj.get_output(n_on);
         energy_kwh = power * (dt / 3600);  % kW * h = kWh
         cost_per_step = price * energy_kwh;
      end

      function feasible = is_valid_n(obj, n_on)
         % IS_VALID_N  检查运行台数是否合法
         feasible = (n_on >= 0) && (n_on <= obj.n_total) && (mod(n_on, 1) == 0);
      end
   end
end