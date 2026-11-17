# HANDOVER —— EMPC 电价预测器（工作区说明）

> **2026-10-08 新阶段。** 本文件是接手入口：先读本文件，再读 [`TODO.md`](TODO.md)（唯一待办权威），
> 数据侧的细节读 [`data_audit/AUDIT.md`](data_audit/AUDIT.md)。
> 本文件不含待办。
> 2026-09-23 那一版整段保留在下方“历史版本”，未删除。

---

## 1. 现在是什么状态

预测器（本人负责的模块）在 2026-10-08 做了一次**结构重整**：从“六个模型并排、口径散在各脚本里”
变成**一个入口、一套协议、一张 (提前量 × 槽位) 误差图集**，并新增了一个把两个锚点混在一起的预测器。

同一轮里修掉了三个真实缺陷（详见 §5）。MPC 与 Decision 两层**不归本人管**，本文件只在需要接口时提到它们。

---

## 2. 目录现状（`Predicitor/`）

```
Predicitor/
  run_predictor_suite.m          ★ 唯一活跃入口：9 个模型 × 120 天 × 288 起点 × 288 步
  Shared/                        get_slot_index, target_slots, rls_scalar_step,
                                 rls_vector_step, predict_blend, update_blend_weights
  PriceClamp/                    init_price_clamp, update_price_clamp, clamp_price
  Template_AR_predictor/         init/update/predict_template_ar（滚动日模板 + 日内 AR(4)）
  ThetaY_Tracker/                init/update/predict_theta_tracker
  Anchor_AR_predictor/           ★ 新：fit_anchor_mix, predict_anchor_mix（锚点混合 + 直接多步）
  Kalman_predictor/              方向 3 的载体，协议不同，独立运行（run_kalman_prediction.m）
  archive/                       已退休：AR_RLS_predictor(11), Testing_Filter(3),
                                 Blend_TemplateAR, Blend_YT_AR,
                                 run_predictor_benchmark_v1.m, README.md
```

`archive/` **默认不在 MATLAB 路径上**：新入口用显式 `addpath` 只挂载在役子目录。
要跑归档里的旧脚本，得手动把 `Predicitor/Shared` 加进 path（`get_slot_index.m` 已迁到那里）。

## 3. 怎么跑

```matlab
% 出图（会导出 5 张 PNG，跑完与导出必须在同一次 MATLAB 调用里）
run('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\EMPC\2026-10-08\predictor\export_figures.m')
```

- 图落在 `Weekly/EMPC/2026-10-08/predictor/figures/`。
- **`run_predictor_suite.m` 自己绝不写文件**（仓库规则：MATLAB 脚本不含 `saveas/print/exportgraphics/writematrix`），
  落盘在调用侧做，就是上面那个 `export_figures.m`。
- 依赖：`MPC/First_Version_MPC/load_aemo_data.m` 必须在 path 上，脚本里已经 `addpath` 了。
- 单次运行约 4~8 分钟（120 天 × 288 起点 + 每天 3 组直接多步重估）。

## 4. 协议（`run_predictor_suite.m` 顶部注释是权威版，这里是要点）

| 项 | 值 |
|---|---|
| 数据 | `AEMO_Data/PRICE_AND_DEMAND_*_VIC1.csv`，5 分钟 RRP，NEM 时间，时间戳是**区间结束时刻** |
| 热身 | 2026-01-01 00:05 → 01-30 24:00，8,640 点，在线喂入不预测（模板要 28 天填满环缓冲） |
| 起点 | 01-31 00:05 起，每 5 分钟一个 |
| 目标 | 02-01 00:05 起，默认 `n_days = 120` 天 |
| **信息集** | **先吃后预测**：`y(t)` 先进状态，再发预测，所以 lead h = 距最新观测 h 步。模型 4 保留旧的“先预测后吃数”口径作对照（图 F5） |
| 钳位 | 滚动 **30 天全局 Q1/Q99**，每天重算一次，**预测与实际都裁**；训练段的阈值用滚动窗口（`run_predictor_suite.m` 里显式算） |
| 训练信号 | 模板 T、AR 系数、`r_seq` 仍建在**原始价**上；只有评分用钳位价（**这是待改项 A1-2**） |
| 评分 | `e = 钳位目标 − 钳位预测`，按 (目标槽位 s, 提前量 h, 目标天 d) 累积；**每格每天恰好 1 个样本**，所以跨模型同格可比 |
| RMSE | `sqrt( mean_d(e^2) )`，逐格；聚合只报“中位数（跨槽位）”“赢了多少槽位（/288）” |
| MSE | 脚本不单独打印，等于对应 RMSE 的平方；**不同样本批次的 MSE 不可相加** |

**为什么要钳位**（不是“让指标好看”）：MPC 的阶段成本对价格是**线性**的
（`RRP/1000 × 46 kW × 5/60 × u_k`），决策是二进制的，最优解等价于“在满足水位约束下挑最便宜的区间开泵”。
**调度由价格的次序与差额决定，一个 +19069 $/MWh 的偶发样本会让整个 288 步解围着它转。** 钳位保护的是控制器的解。

## 5. 本轮修掉的三个缺陷

1. **`Shared/target_slots.m` 一格偏移**——注释写 `u(1) = origin_slot + 1`，代码给 `origin_slot`，
   导致“给槽位 s 的目标用了 T(s−1)”。实测代价只有 **+0.01 $/MWh**（模板平滑），但 θ(s) 与混合权重按槽位查表，
   错配一格是实质问题。已修。
2. **`ThetaY_Tracker/predict_theta_tracker.m` 是 0 字节空文件**——θ 预测原本内联在基准里。已补成真函数并被新入口调用。
3. **`PriceClamp/clamp_price.m` 零调用点**——裁剪原本内联在四处。已改成支持逐点阈值，并替换掉内联。

## 6. 已测出的结论（2026-10-08，120 天窗口，钳位，$/MWh）

**跨槽位中位数 RMSE：**

| 模型 | 5min | 30min | 1h | 3h | 6h | 12h | 24h |
|---|---|---|---|---|---|---|---|
| Persistence(昨天同槽位) | 47.7 | 47.7 | 47.7 | 47.7 | 47.7 | 47.7 | 59.0 |
| Rolling template | 45.0 | 45.0 | 45.0 | 45.0 | 45.0 | 45.0 | 45.0 |
| Theta-y tracker | 45.6 | 45.6 | 45.6 | 45.6 | 45.6 | 45.6 | 45.6 |
| T+AR4（先预测） | 11.0 | 15.4 | 21.2 | 34.7 | 44.9 | 48.4 | 45.7 |
| T+AR4（先吃） | 9.8 | 15.2 | 20.4 | 34.3 | 44.6 | 48.7 | 45.1 |
| Carry-forward | 9.9 | 13.3 | 16.6 | 29.9 | 46.3 | 58.8 | 47.7 |
| T+DMS4（每天重估） | 9.8 | 15.1 | 19.4 | 30.5 | 37.2 | 41.6 | 41.4 |
| CF+DMS4（每天重估） | 9.0 | 13.4 | 16.8 | 30.0 | 46.3 | 58.8 | 47.7 |
| **Anchor-mix（新）** | **9.0** | **13.1** | 17.3 | **29.2** | **35.8** | **40.6** | **40.9** |

**每个提前量赢下的槽位数（/288）：**

| lead | Pers | Tpl | θy | T+AR4先预测 | T+AR4先吃 | CF | T+DMS4 | CF+DMS4 | **Anchor-mix** |
|---|---|---|---|---|---|---|---|---|---|
| 5min | 0 | 0 | 0 | 16 | 50 | 23 | 31 | 55 | **113** |
| 30min | 0 | 0 | 0 | 20 | 23 | 43 | 33 | 39 | **130** |
| 1h | 0 | 0 | 0 | 9 | 12 | 73 | 67 | 44 | **83** |
| 3h | 0 | 0 | 0 | 1 | 2 | 54 | 79 | 61 | **91** |
| 6h | 1 | 0 | 0 | 0 | 0 | 25 | 78 | 26 | **158** |
| 12h | 2 | 5 | 10 | 11 | 11 | 8 | 78 | 6 | **157** |
| 24h | 0 | 4 | 1 | 11 | 25 | 0 | 105 | 0 | **142** |

要点：
- 新 Anchor-mix 在**每个提前量**都赢下最多槽位；中位数在 7 档里赢 5 档（1h 档略输给 carry-forward）。
- **不存在单一冠军**：短档靠 carry-forward 类（当前价锚点），长档靠模板锚点；模型自己按提前量分配权重。
- 日内最难是 **07:00–08:30 与 17:00–18:30**，最易是凌晨 2–4 点与 21–23 点。
- “先吃后预测”相对“先预测后吃数”，5 分钟档 11.05 → 9.76（约 −12%）。

**已知待修**：Anchor-mix 的 `a_h`（当前价权重）在 15–18 小时提前量处变成 **−0.08**，是 `y_now` 与差分滞后共线造成的病态解
→ 需要正则化（TODO `A1-1`）。

## 7. 环境与坑（本机）

- **MATLAB MCP 可用**，直接 `run_matlab_file` / `run_matlab_code`；图窗在两次工具调用之间会被宿主清掉，
  **跑图与导出图必须写在同一次调用里**。
- `Online_Data_Capture_Script/aemo_config.py` 的 `OUTPUT_DIR` 仍指向**已不存在的旧路径**
  `C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data`；`.venv` 在新位置也不存在。
  现在跑抓取会静默写到旧目录（TODO `A3-4`）。
- 任何自动化不许抢屏抢焦点：跑图前 `set(0,'DefaultFigureVisible','off')`。
- Python 用 `C:\Users\AshTrailer\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe`（自带 pandas/numpy/python-pptx）。
- git：按**显式路径** `add`，禁止 `git add -A`；`Weekly/` 默认不入 git。

## 8. 下一步（详见 TODO 阶段 A）

1. `A1-1` 给 Anchor-mix 加正则化（用户看图 F4 后裁决）；
2. `A1-2` 训练信号改钳位序列（独立一次改动，保留旧口径对照）；
3. `A1-3` T+ARX：接入 AEMO P5 偏差项，**融合律**是研究点；
4. `A2-2` 把数学表达、符号、钳位、滚动、平均、RMSE/MSE 定义做成 PPT（用户先确认图集）。

---

# 历史版本 —— 2026-09-23 周（保留）

