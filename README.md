# EMPC_Water_Electricity_Forecast
Economic model predictive control for pumping scheduling in water distribution systems under stochastic electricity prices, using AR/ARMA-based forecast models.

# EMPC for Water Pumping under Uncertain Electricity Prices

## 项目目标
- 对 AEMO 电价预测误差进行建模（AR / ARMA）；
- 考虑预测模型在经济模型预测控制（EMPC）中的闭环特性，进行参数估计；
- 实现基于 EMPC 的水泵调度策略，降低购电成本。

## 研究方法
- 电价预测误差建模：AR, ARMA 模型；
- 参数估计：以 EMPC 闭环性能为导向的辨识方法；
- 控制器设计：经济模型预测控制，利用储水设施移峰填谷。

## 仓库结构（计划）
- `/data`           原始电价数据与处理脚本
- `/models`         预测模型（AR/ARMA/ARMAX）相关代码
- `/empc`           EMPC 控制器实现
- `/simulation`     仿真案例与结果分析
- `/docs`           笔记、公式推导、参考文献

## 环境依赖
- MATLAB R20xx（版本号）
- Optimization Toolbox, System Identification Toolbox 等

## 当前进展
- [ ] 获取并清洗 AEMO 电价数据
- [ ] 实现 AR/ARMA 参数估计（闭环指标）
- [ ] 搭建水管网仿真模型
- [ ] 实现 EMPC 控制器
- [ ] 对比不同策略的经济性





