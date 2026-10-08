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



站在 AEMO 官方预测的肩膀上：不再从零预测整条电价曲线，而是
**以 AEMO 官方预测为基线，再预测它的短期误差**。

```
e(k, k_i)        = y(k) − ŷ_AEMO(k | k_i)          历史预测误差
ŷ_corrected(k|k0) = ŷ_AEMO(k | k0) + ê(k | k0)      修正后预测
```
真正要建的模型是 `ê(k | k0)`，且**只做短提前量**（前 12 个 5 分钟步 = 1 小时），
误差修正随提前量增大衰减到 0，长期回到 AEMO 原值。

---

## 1. 待裁决（需要用户决策，阻塞后续）

> **2026-09-24 第一轮审核已过**：数据侧 5 条解读、预测器侧 4 条解读全部认可；
> TD-1 选 A（改 `False`）；公式贴图确认是本人贴的深色底 LaTeX 位图。

- [x] **TD-1 `USE_AUS_LOCAL_TIME` 的默认值** —— **裁决：A**
  已改为 `False`（`aemo_config.py`），并在原位写清理由与实测数据。
  预期收益：抓取通路与月度文件 / AEMO 归档三者时基统一，夏令时期间不再错 12 个槽位。

- [ ] **TD-2 抓取数据是「回灌缓存」还是「删掉重抓」** —— **已按「删掉重抓」执行**
  三个损坏 store + `capture_state.json` + 旧 `zip_cache/`（646 个文件）已备份到
  `data_audit/_before_fix/` 后删除，正在跑全新一轮抓取验证修复。
  **剩余决策**：历史数据从 NEMWEB ARCHIVE 回填多少天（见 TD-3）。

- [ ] **TD-3 P5 / PREDISPATCH 的历史版本保留策略**
  教授要求「保存更多历史 AEMO 预测版本，不能只保留最近 10 次」。现配置
  `PREDISPATCH_KEEP_BATCHES = 10`（约 5 h）、`P5MIN_KEEP_BATCHES = 60`（约 5 h）。
  已探明 **ARCHIVE 有 375 个 P5MIN 日包（2025-09-12 ~ 2026-09-21，57 MB/天）**
  与 375 个 DispatchIS 日包（5.7 MB/天），可离线回填。
  **待定：回填多少天。** 试点已跑 3 天；建议 28 天（≈1.7 GB 下载，约 30 万行误差样本）。

- [ ] **TD-4 `Weekly/` 目录是否入 git**
  用户要求「不需要提交到 git」，但也在意文件备份。当前 `Weekly/` 是未跟踪目录。
  选项：(A) 全部不入 git，只做仓库外备份；(B) 只入文档与脚本、不入缓存与图片。

---

## 2. 进行中

- [x] **W-1 数据整理与三源比对** —— 解读与结论已通过用户审核（2026-09-24）
  产出：`data_audit/AUDIT.md` + `scripts/compare_report.txt` + `scripts/figures/F1..F3`

- [x] **W-2 抓取脚本修复** —— 5 个缺陷全部修完并重跑验证
  改 3 个文件：`aemo_parser.py`（D1 引号 / D3 表合并 / D4 PERIODID）、
  `aemo_common.py`（D2 紧凑格式宽度闸）、`aemo_config.py`（D5 时基默认值）。
  验证：`scripts/store_verify.txt` —— 三个 store 时间列零空值，dispatch 2880 行 /
  每区域 576 个 5 分钟区间（修复前永远 5 行）。

- [x] **W-3 AEMO 误差模型（第一部分）** —— 28 天归档回填 + 误差矩阵 + 修正模型 +
  五路对照全部跑完，结果见 `predictor/ERROR_STUDY.md`
  **核心数字**：P5 误差 RMSE 从 5 min 的 14.97 涨到 55 min 的 42.19；ε(k) 的
  ACF(1)=0.682、同号段平均 6.15 个区间（随机为 2.0）、最长 122；
  四阶滞后线性修正在 5 min 上把 AEMO 自己改善 **13.0%**，30 min 后转负；
  五路对照里 **5~10 min 赢家是 carry-forward persistence，15~55 min 是 T+AR(4)**，
  AEMO 原始预测从未夺冠。

- [x] **W-4 本周 PPT** —— 22 页，静态 QA 全部通过
  产出：`deck/Capstone_Weekly_2026-09-23.pptx` + `deck/deck_qa.txt`（0 项问题）

---

## 3. 待做（按依赖顺序）

> **2026-09-24 第二轮审核已过**：误差模型 5 条结论全部认可；
> **下一步选 A（先做公平化重跑）**；git 提交走 A（已提交）；skill 收录走 A。

### 第一优先 · 公平化重跑（用户 2026-09-24 裁决）

现在的四路对照有两个不可比之处，必须先把它们消掉，否则任何「谁更好」的结论都站不住：

- [ ] **F1 统一模板预热**：本轮的 T+AR(4) 模板只预热了 10 天，1 月基准用了 28~30 天。
  重跑时把热身拉到 ≥28 天（用 AEMO 归档往前多回填 3 周即可）。
- [ ] **F2 加价格钳位**：1 月基准把预测与实际都裁到滚动 30 日 Q1/Q99，本轮用原始价格，
  被一次 +215.6 $/MWh 的极端事件放大。两侧必须用同一条评分信号。
- [ ] **F3 统一信息集**：确认 AEMO P5、修正模型、T+AR(4)、persistence 四者
  在每个起源上看到的是同一批数据（当前 AEMO 的 h=1 实际是 10 分钟提前量，
  而我们的 T+AR(4) 更新到 y(k_i) 后是 5 分钟 —— 要在同一 lead 定义下重排）。
- [ ] **F4 重出 `ERROR_STUDY.md` 与 `C1` 图**，并把「修正后 AEMO 只在 30 分钟领先」
  这条换成公平化之后的说法。

### 第一部分 · 数据

- [x] **P1-1** 重跑抓取并验证 store 累积 —— 已完成（2880 行 / 零空值）
- [x] **P1-2** store 自检脚本 —— `data_audit/scripts/store_verify.py`（7 类判据，0 失败）
- [ ] **P1-3** 按 TD-3 的裁决调整保留策略，把预测 store 改成可累积
- [ ] **P1-4** RUNNO 普查：抽样 30 个交易日，统计 RUNNO > 1 的比例与时点
- [ ] **P1-5** `AEMO_Data` 目录分类整理（四类分开），一次性原始件归档
- [ ] **P1-6** `Online_Data_Capture_Script/__pycache__/*.pyc` 现在**被 git 跟踪**
      （本轮改了源码它就一直显示 modified）。应加 `__pycache__/`、`*.pyc` 到
      `.gitignore` 并 `git rm -r --cached`，下次整理提交时一起做。

### 第二部分 · 误差模型（公平化之后）

- [ ] **P2-2** 扩到五个区域；窗口从 28 天拉到 3 个月（P5MIN 约 57 MB/天，约 5 GB 下载）
- [ ] **P2-3** 按提前量**分段**做模型选择（≤10 min carry-forward，>10 min T+AR(4)），
      把「修正后 AEMO」当候选之一而不是默认答案
- [ ] **P2-4** 误差修正随提前量衰减到 0 的权重设计已由 C3 隐含（30 min 穿过零点），
      显式写成公式后再实现一版
- [ ] **P2-5** 残差模型稳定后接入 MPC，并补一次成本对比

### 第三部分 · 交付

- [x] **P3-1** 本周 PPT —— 22 页，静态 QA 0 项问题
- [ ] **P3-2** cherry studio 的 7 个 skill 收录（按 §4 的逐条建议，已获用户认可）

---

## 4. 待裁决 · 元层 skill 收录

cherry studio 的 7 个 skill 已盘点完毕（`_inbox/` 有摘要）。逐条建议：

| skill | 体积 | 建议 | 理由 |
|---|---|---|---|
| `pptx` | 1.16 MB / 56 文件 | **只摘规则，不搬文件** | Anthropic 专有许可（`© 2025 Anthropic, PBC. All rights reserved.`）；且依赖 pptxgenjs + LibreOffice + poppler，本机未验证齐备。SKILL.md 里的设计规范段（配色/字号/间距/QA 流程）值得摘成 `ppt` 域规则。 |
| `pdf` | 60 KB / 12 文件 | **只摘规则** | 同上专有许可；工具链全是 Python（pypdf/pdfplumber/reportlab），与元层无冲突。 |
| `grill-with-docs` | 404 B / 2 文件 | **不收录** | 它本身只是一行「调用 grilling 与 domain-modeling」，而**这两个 skill 本机根本不存在** ⇒ 收录了也跑不起来。 |
| `cherry-tool-guide` | 37 KB | **不收录** | 讲的是 Cherry Studio 自己的 `mcp__cherry-tools__*`，DSH 里没有这些工具。可借鉴的是「路由表 + references 分层」这一组织形式。 |
| `find-skills` | 7 KB | **不收录** | 依赖 Cherry 的 `search_skills` / `install_skill` 与 skills.sh 市场。 |
| `code-mate-deepseek-harness` | 1.4 KB | **不收录** | 讲的是在 Cherry 里怎样调 `dsh --profile headless`；在 DSH 里是循环引用。 |
| `skill-creator` | 227 KB / Apache-2.0 | **摘「description 要 pushy」与 eval 流程** | 唯一 Apache-2.0 的；但 eval 链路依赖 `claude -p` CLI，本机没有。 |

---

## 5. 已否决

- ~~把 cherry studio 的 pptx / pdf skill 整目录拷进元层~~ —— 否决理由：专有许可。
  **复活条件**：确认只是自用、不入公开仓库，且用户明确要求整目录搬运。
- ~~给预测器加更高阶 AR / 工作日周末拆分~~ —— 否决理由：上周实验已证无收益
  （AR 阶数扫描最好 AR(3)，类拆分结果不稳定）。
  **复活条件**：换成 AEMO 误差残差序列后重做阶数扫描，若残差自相关结构不同则可重开。

---

## 6. 已完成（本周）

- [x] 读元层四件套 + 领域 skill（matlab / ppt）+ recall 自动注入
- [x] 审阅预测器 AR 部分代码
- [x] 跑通 `run_predictor_benchmark.m`，拿到本周基线数字与 4 张图
- [x] AEMO_Data 全量清点与来源分类（`data_audit/scripts/aemo_probe_report.txt`）
- [x] 定位并修复抓取脚本 4 个解析缺陷 D1–D4
- [x] 三源比对：月度 VIC1 / 看板 dispatch 下载 / NEMWEB 归档（`compare_report.txt`）
- [x] 时基判定：`USE_AUS_LOCAL_TIME` 是偏移来源（`timebase_verdict.txt`）
- [x] 分析上周 PPT 的风格规格与公式显示根因（`deck/`）
- [x] 盘点 cherry studio 7 个 skill
