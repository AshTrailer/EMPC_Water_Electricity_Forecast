# Predicitor/archive —— 已退休的预测器与实验

本目录下的代码**不再被任何活跃入口调用**，保留只为可追溯。活跃入口只有一个：`../run_predictor_suite.m`。

## 为什么在这里

| 目录/文件 | 退休原因 |
|---|---|
| `AR_RLS_predictor/` | 上一代实验脚本（AR 阶数扫描、模板类拆分、更新节奏扫描、预测实验）。它们的协议与当前基准不同，数字不可比。**注意：`get_slot_index.m` 已于 2026-10-08 迁到 `../Shared/`，本目录里的脚本要跑必须把 `../Shared` 加进 path。** |
| `Testing_Filter/` | 移动平均 / 移动中值 / RLS 滤波，只被 `AR_RLS_predictor/` 的旧脚本使用。 |
| `Blend_TemplateAR/` | Blend A。实测权重不收敛到极端而是停在 0.46（中位数），因为它把**水平** T 与**校正量** r̂ 做凸组合，参数化本身不可能赢；见 `../docs/` 或 HANDOVER 的 T+ARX 章节。 |
| `Blend_YT_AR/` | Blend B，同上。 |
| `run_predictor_benchmark_v1.m` | 旧基准（6 模型）。它依赖已归档的 Blend A/B，且 `target_slots` 存在一格偏移（2026-10-08 已修）。保留为历史版本，不再维护。 |

## 不在归档里

- `../Kalman_predictor/` —— 方向 3 的载体，仍在役（协议不同，单独运行）。
- `../ThetaY_Tracker/`、`../Template_AR_predictor/`、`../PriceClamp/`、`../Shared/` —— 活跃依赖。

## 路径注意

`addpath(genpath(Predicitor))` 会把本目录也加进搜索路径。新的活跃入口用**显式 addpath** 只挂载在役子目录，本目录因此默认不在 path 上。
