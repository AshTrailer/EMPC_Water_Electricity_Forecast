# Basic 1.0：基础约束水箱 MPC

Basic 1.0 实现了一个单水箱、连续流量的约束模型预测控制器，用于验证水箱模型、MPC 约束和 Decision 模块接口，并作为后续 EMPC 的基线。

## 已实现功能

- 建立单水箱离散动态模型；
- 使用 24 小时预测窗口规划期望总流量；
- 通过 `quadprog` 求解带约束的二次规划问题；
- 限制水位、流量范围和相邻时刻的流量变化；
- 每小时重新优化，并只执行当前第一步控制量；
- 建立 MPC 与 Decision 模块的双向接口；
- 提供固定需求和周期需求两种模拟场景；
- 提供闭环仿真、结果绘图和确定性测试。

## 控制流程

```text
未来需求与参考水位
        ↓
约束 MPC 计算连续期望流量
        ↓
Decision 模块转换为实际执行流量
        ↓
水箱使用实际流量更新水位
        ↓
下一小时重新预测和优化
```

当前使用 `mock_decision_optimizer.m` 作为临时理想执行器，假设实际流量能够完全跟随 MPC 请求。真实 Decision 模块完成后，应替换该文件，而不需要修改 MPC 核心算法。

## 数学模型

水箱状态更新方程：

```text
x(k+1) = x(k) + dt/A × [q_actual(k) - d(k)]
```

- `x`：水位（m）；
- `A`：水箱横截面积（m²）；
- `q_actual`：Decision 模块实际执行流量（m³/s）；
- `d`：用水需求（m³/s）。

主要约束：

```text
level_min ≤ x(k) ≤ level_max
u_min ≤ u(k) ≤ u_max
|u(k) - u(k-1)| ≤ du_max
```

目标函数同时考虑水位跟踪误差、输入大小和输入变化量。

## 运行方法

在 MATLAB 中进入本目录并运行：

```matlab
run_basic_mpc
```

运行全部测试：

```matlab
run_basic_mpc_tests
```

运行环境需要 MATLAB Optimization Toolbox，并确保 `quadprog` 可用。

## 主要文件

| 文件 | 作用 |
|---|---|
| `basic_mpc_config.m` | 设置水箱参数、约束、预测窗口和目标函数权重 |
| `controller/constrained_tank_mpc.m` | 构造并求解基础 MPC 二次规划问题 |
| `interfaces/decision_to_mpc_input.m` | 将上游数据整理为 MPC 预测窗口输入 |
| `interfaces/mpc_to_decision_request.m` | 将 MPC 结果转换为 Decision 请求 |
| `interfaces/mock_decision_optimizer.m` | 临时理想 Decision 执行器 |
| `simulation/simulate_basic_mpc.m` | 执行滚动闭环仿真并绘图 |
| `scenarios/make_mock_decision_data.m` | 生成模拟需求、参考水位和预留电价数据 |
| `tests/test_basic_mpc.m` | 检查约束、接口和优化求解状态 |

## 模块接口

MPC 输出：

- `u_request`：归一化连续流量请求；
- `requested_flow_m3s`：当前期望总流量；
- `u_request_plan`：预测窗口内的完整流量计划；
- `x_prediction`：预测水位轨迹。

Decision 模块输出：

- `u_actual`：实际归一化总流量；
- `actual_flow_m3s`：实际总流量；
- 泵组状态、功率和运行时间等执行信息。

水箱状态必须使用 `actual_flow_m3s` 更新，不能直接使用 MPC 的请求值。

## 当前限制

Basic 1.0 不是 EMPC：

- 电价字段仅在接口中预留，尚未进入目标函数；
- 控制变量是连续总流量，不是离散泵开关；
- 尚未加入真实泵组选择、能耗模型和启停成本；
- 当前需求和参考水位来自模拟场景。

下一阶段应保持现有接口边界，引入电价预测、真实泵组决策、能耗成本和启停约束，形成完整 EMPC。
