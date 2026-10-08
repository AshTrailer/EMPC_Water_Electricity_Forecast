# TODO —— 电价预测器（EMPC）

> 本文件是**唯一待办权威**。别的文档（HANDOVER / AUDIT / 回复正文）不另开待办小节。
> 状态：`进行中` / `待做` / `待裁决（需用户点头）` / `已否决（带复活条件）` / `已完成`
> 编号：`id` 是稳定号，永远不动；显示序号会随位置重排。条目之间引用一律写 `id`。

---

# 阶段 A —— 2026-10-08 起飞：预测器重构（当前唯一在办）

> 本阶段的目标：把预测器从"六个模型并排 + 手工口径"变成**一个入口、一套协议、一张 (提前量 × 槽位) 误差图集**，
> 并把数学表达固化成 PPT。上一阶段（2026-09-23）的内容整段保留在本文件末尾，未删除任何条目。

## A1 预测器与评价（进行中）

- [ ] **A1-1 锚点混合模型的系数正则化** —— `Predicitor/Anchor_AR_predictor/fit_anchor_mix.m`
  现状：无正则 OLS。实测 `a_h`（当前价权重）在 15–18 小时提前量处变成 **−0.08**，`a_h+b_h` 掉到 0.45，
  这是 `y_now` 与差分滞后强共线造成的病态解。做法：加岭惩罚，或把 `a_h` 收缩到先验（短线偏 1、长线偏 0），
  惩罚强度用日滚动窗口的交叉验证定。判据：`a_h ∈ [0,1]`、`a_h+b_h` 在 6 小时处不再超过 1.15，且 5min/24h 两档 RMSE 不劣化。
  验收人：用户看图 F4。

- [ ] **A1-2 训练信号改用钳位序列**（独立一次改动，必须保留旧口径跑一遍做对照）
  现状：模板 T、AR 系数、`r_seq` 都用**原始价**估计，只有评分用钳位价。原始序列最大 19069 $/MWh。
  做法：T 与 r 建在钳位序列上，全套模型重跑；旧口径另存一份作对照。
  预期：短提前量变化不大，长提前量与 bias 变好。判据：三档（5min/1h/24h）至少两档不劣化，且 bias 绝对值下降。

- [ ] **A1-3 T+ARX：接入 AEMO P5 偏差项** `g_{t+h|t} = pi_{t+h|t} - T(s_{t+h})`
  已实测：在 8/25–9/22 窗口、同一批起点上，`T+AR(4)` 第一小时 pooled RMSE 16.72 → 加 P5 后 **15.51（−7.2%）**，
  每个提前量都改善，权重 5min 0.26 → 45min 0.55。**但固定权重有一天翻车（09-17 −33%），朴素在线 RLS 又超配（16.86）。**
  所以本条的真正内容是**融合律**：带收缩先验的逐提前量权重。
  前置：`AEMO_Data/forecast_actual/` 只有 2026-08-25 → 09-22 的配对；要扩窗口必须先跑 `backfill_archive.py`。
  判据：三档 RMSE 全部改善，且逐日起伏不超过 T+AR 的 10%。

- [ ] **A1-4 可选扩展（用户已认可可以考虑）**
  多 X：`Operational_Demand_FORECAST` 的 `OPERATIONAL_DEMAND_POE50`、P5MIN 的 `AVAILABLEGENERATION`；
  γ 换成 RLS 版（若需要更快适应）；对 `σ_h(s)` 建模，给 MPC **分布**而不是点。
  注意：先用岭或 PLS 处理共线，且**先做 A1-3 的最小闭环**。

- [ ] **A1-5 把图集跑成多窗口**（现在只有 2026-02-01 → 05-31 一个 120 天窗口）
  月度数据到 2026-08-09，可再切 2 个窗口做稳定性检查。判据：`F3 slots won` 的冠军顺序在两个窗口一致。

- [ ] **A1-6 节假日表**（`get_day_class` 注释里留的坑）
  维州 2026 公共假日表，强制映射为周末类。现在基准的模板根本没用 `get_day_class`，本条只在重新引入日型时才有意义。

## A2 图像与文档（待确认 → 已出图，等用户过目）

- [ ] **A2-1 图集定稿**（已出 5 张，等用户确认）
  位置 `Weekly/EMPC/2026-10-08/predictor/figures/`：`F1_rmse_vs_slot_per_lead`、`F2_error_distribution_anchor_mix`、
  `F3_slots_won`、`F4_anchor_mix_weights`、`F5_information_set`。
  用户确认后：补 `F6`（模板/AR 状态量的时间轨迹）与 `F7`（钳位前后的尾部对照）。

- [ ] **A2-2 PPT：预测器数学与口径全量**
  内容：符号表、分解式、迭代 AR 与直接多步、锚点混合、钳位（定义/用途/为什么 EMPC 必须用）、
  数据滚动（28 天环缓冲、14 天重估）、平均与 RMSE/MSE 的精确定义、五套历史口径对照。
  **做法参考用户提供的 `D:\Study\Capstone Project\Capstone_Weekly_2026-09-23.pptx`，但删掉只有纯文字表达的页。**
  前置：用户先确认 A2-1 的图。
  落点：`Weekly/EMPC/<date>/deck/`，用 `office-pptx` 技能；导出后跑 `check_office.py`。

- [ ] **A2-3 联网调研 pptx 专用 skill 并合并进本机 pptx 技能**
  做法：搜公开的 pptx/slide skill 规范（版式、字号下限、图文关系、QA 判据），把可复用的**规则**（不是文件）
  用元层入口写进 `pptx` 域：`node "$env:DSH_META_ROOT\_meta\tools\skill-rule.mjs" --domain pptx --text "<正文>" --apply`。
  **注意：本工作区不是元层，写不进去。** 这条要在元层会话里执行，或由用户在那边提一句。
  已可用的现成件：本机 `office-pptx` 技能自带 `check_office.py` + LibreOffice Kit 渲染，先复用，别重写。

## A3 工程与账目（待做）

- [x] **A3-1 文件夹整理**（2026-10-08 完成）
  `AR_RLS_predictor/`、`Testing_Filter/`、`Blend_TemplateAR/`、`Blend_YT_AR/` → `Predicitor/archive/`；
  `get_slot_index.m` 移到 `Predicitor/Shared/`；旧基准改名 `archive/run_predictor_benchmark_v1.m`；
  新增 `archive/README.md` 说明退休原因。

- [x] **A3-2 空壳与死件补成真函数**（2026-10-08 完成）
  `ThetaY_Tracker/predict_theta_tracker.m`（原 0 字节）→ 真函数，并已被新入口调用；
  `PriceClamp/clamp_price.m`（原零调用）→ 支持逐点阈值，并在新入口里替换掉 4 处内联裁剪。

- [x] **A3-3 `target_slots` 一格偏移**（2026-10-08 修）
  代码与自己的注释矛盾：注释写 `u(1) = origin_slot + 1`，代码给 `origin_slot`，导致"给槽位 s 的目标用 T(s−1)"。
  实测代价仅 **+0.01 $/MWh**（模板很平滑），但 θ(s) 与混合权重按槽位查表，错配一格是实质性的。已修。

- [ ] **A3-4 `Online_Data_Capture_Script/aemo_config.py` 的旧路径**
  `OUTPUT_DIR` 仍指向 `C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data`（本机已不存在）。
  现在跑抓取会**静默写到旧目录**，把数据劈成两半。同时项目搬到新路径后 `.venv` 不存在，系统 Python 3.14 没有 pandas。
  判据：抓取一轮后新 `AEMO_Data` 的三个 store 行数增加。

- [ ] **A3-5 `Weekly/EMPC/2026-09-23/predictor/benchmark_console.txt` 是 0 字节**
  但 HANDOVER 把它列为"基准的完整控制台输出"。要么补齐，要么删掉那条引用。

- [ ] **A3-6 git 提交**（按显式路径，禁止 `git add -A`）
  待提交：`Predicitor/` 的移动与新增、`Shared/target_slots.m` 的一行修复、`PriceClamp/clamp_price.m`。
  `Weekly/` 默认不入 git。

## A4 待裁决（需要用户点头）

- [ ] **A4-1 `Predicitor/run_predictor_suite.m` 取代旧基准** —— 已建，是否正式替代 `archive/run_predictor_benchmark_v1.m`。
- [ ] **A4-2 归档目录是否移出 `Predicitor/`** —— 新入口用显式 addpath，archive 默认不在 path 上；若要物理隔离，需移到 `Predicitor/` 之外。
- [ ] **A4-3 反馈给导师的口径** —— 之前汇报里的数字（P5 误差 11→17.7→26.4、ACF 0.50、同号段 5.05）与
  `ERROR_STUDY.md`（14.97→42.19、ACF 0.682、6.152）**不是同一批样本**，两者必须统一后再汇报。

---

# 阶段 B —— 2026-09-23 周（历史，全部保留）

## 0. 本周目标（教授给的）
