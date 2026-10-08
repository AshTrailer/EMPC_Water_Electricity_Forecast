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


> 2026-09-23 周 ｜ 布局参照元层 `C:\DSH_Home\_meta\`：**一份 TODO + 一份 HANDOVER + 分目录存档**。
> **本文件不含任何待办** —— 待办只在 [`TODO.md`](TODO.md)。
> 接手先读本文件，再读 [`data_audit/AUDIT.md`](data_audit/AUDIT.md)。

---

## 1. 这是什么

硕士毕业设计 **EMPC_Water_Electricity_Forecast** 的三分之一：水泵站的经济 MPC 需要
未来电价，本工作区负责其中的**电价预测器**与**喂给它的数据链路**。

闭环：

```
AEMO 市场 ──► 数据抓取(Python) ──► AEMO_Data ──► 电价预测器(MATLAB) ──► EMPC(MPC 层) ──► 供水系统
                                          └──► (新) AEMO 预测误差模型
```

控制步长与现货电价都是 **5 分钟**；AEMO 预调度预测是 **30 分钟**网格。分工：
MPC 层归队友，本工作区只管**预测器 + 数据**。

---

## 2. 目录与文件

### 2.1 项目里已有的

| 路径 | 是什么 |
|---|---|
| `Predicitor/` | 预测器全部 MATLAB 代码（六模型套件 + 旧实验） |
| `Predicitor/run_predictor_benchmark.m` | **当前主基准**：6 个预测器 × 288 步 × 4320 起点 |
| `Online_Data_Capture_Script/` | AEMO 在线抓取（Python，本工作区可自由改） |
| `AEMO_Data/` | 全部数据（四类，见 AUDIT §1） |
| `MPC/First_Version_MPC/` | `system_config.m` 与 `load_aemo_data.m` 的**老家** |
| `Simulation_Log/` | 历史仿真输出（`Ash_YYYYMMDD/`） |

### 2.2 本周新增（**未入 git**）

```
Weekly/EMPC/2026-09-23/
  TODO.md                 本周唯一待办权威
  HANDOVER.md             本文件
  data_audit/
    AUDIT.md              数据审计报告（含结论与下一步）
    scripts/              全部可重放脚本 + 控制台报告 + figures/
  predictor/
    benchmark_console.txt 基准的完整控制台输出
    figures/              4 张基准图（原 MATLAB figure 导出 PNG）
  deck/                   上周 PPT 的提取物与公式问题取证
  _inbox/                 待投递元层的候选草稿
```

---

## 3. 怎么跑

### 3.1 预测器基准（MATLAB）

```matlab
% 前提：MPC\First_Version_MPC 必须在 MATLAB path 上
addpath('C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\MPC\First_Version_MPC');
run('C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\Predicitor\run_predictor_benchmark.m');
```

**为什么需要那一行 `addpath`**：`run_predictor_benchmark.m` 自己只
`addpath(project_root)` 与 `addpath(genpath(Predicitor))`，但 `load_aemo_data.m`
住在 `MPC/First_Version_MPC/`。更早的几个实验脚本（`run_prediction_experiment.m`、
`run_ar_order_sweep.m`、`run_update_cadence_sweep.m`、`run_template_class_long_test.m`、
`run_kalman_prediction.m`）还额外调用 `system_config()`，同样来自那里 ——
这就是「跑预测器前要先在 `MPC/First_Version_MPC/system_config.m` 上按一次运行」的由来。
`run_predictor_benchmark.m` **不读 `cfg`**，参数全是脚本顶部的硬编码常量。
（统一参数化是 TODO 里迟早要做的事，但不阻塞本周。）

基准会开 4 个 figure。脚本按规范**不写任何落盘代码**；要存图在调用侧做：

```matlab
set(0,'DefaultFigureVisible','off');      % 不抢屏
run('...\run_predictor_benchmark.m');
outdir = '...\Weekly\EMPC\2026-09-23\predictor\figures';
f = findall(0,'Type','figure'); [~,o] = sort([f.Number]); f = f(o);
names = {'bench_week_aligned','bench_rmse_lead','bench_rmse_slot','bench_rmse_matrix'};
for k = 1:numel(f), exportgraphics(f(k), fullfile(outdir,[names{k} '.png']), 'Resolution', 160); end
```
⚠️ **跑完必须与导出写在同一次调用里**：宿主会在两次工具调用之间清掉 MATLAB 的图窗。

### 3.2 抓取脚本（Python）

```powershell
# 用项目 venv；系统 Python 3.14 没有 pandas/numpy
cd C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\Online_Data_Capture_Script
& ..\.venv\Scripts\python.exe aemo_capture.py --once      # 跑一轮
& ..\.venv\Scripts\python.exe aemo_capture.py             # 常驻，默认 60 s 一轮
```

### 3.3 数据审计脚本（Python）

```powershell
cd C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project
$py = ".\.venv\Scripts\python.exe"
& $py "Weekly\EMPC\2026-09-23\data_audit\scripts\compare_sources.py"     # 三源比对
& $py "Weekly\EMPC\2026-09-23\data_audit\scripts\store_verify.py"        # store 自检
& $py "Weekly\EMPC\2026-09-23\data_audit\scripts\timebase_verdict.py"    # 时基判决
```
每个脚本都把结果写进同目录的一个 `.txt`，因为本机沙箱会吞掉被管道捕获的 stdout。

### 3.4 AEMO 误差模型（本周新增，三步）

```powershell
$py = ".\.venv\Scripts\python.exe"
# 1) 从 NEMWEB ARCHIVE 回填「实际价 + 官方 P5 预测」——可断点续跑，已下过的日包会跳过
& $py "Weekly\EMPC\2026-09-23\data_audit\scripts\backfill_archive.py" `
      --start 20260825 --end 20260921 --regions VIC1 --purge-zips
# 2) 误差矩阵 + 可预测性（ACF / 同号段长 / 训练-测试切分的三个修正模型）
& $py "Weekly\EMPC\2026-09-23\data_audit\scripts\build_error_matrix.py"
```
```matlab
% 3) 把 T+AR(4) 放到与 AEMO P5 完全相同的起源与提前量上
addpath('C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\Weekly\EMPC\2026-09-23\predictor');
T = weekly_p5_compare( ...
   'C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data\forecast_actual\dispatch_5min.csv', ...
   'C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data\forecast_actual\p5min.csv');
% 写盘在调用侧做（脚本本身按规范不落盘）
writetable(T, 'C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\Weekly\EMPC\2026-09-23\predictor\tar_p5_forecasts.csv');
```
```powershell
& $py "Weekly\EMPC\2026-09-23\predictor\p5_vs_tar.py"   # 四路对照与图
```

### 3.5 PPT

```powershell
cd "Weekly\EMPC\2026-09-23\deck"
& ..\..\..\..\.venv\Scripts\python.exe build_week2_deck.py   # 生成 pptx（数字从 JSON 读）
& ..\..\..\..\.venv\Scripts\python.exe deck_qa.py            # 静态 QA，不渲染、不抢屏
& ..\..\..\..\.venv\Scripts\python.exe list_pictures.py      # 逐张图片的版面几何
& ..\..\..\..\.venv\Scripts\python.exe render_formula.py --selftest  # 公式渲染器自检
```
本机**没有** LibreOffice / poppler，pptx 的官方 QA 链路（soffice + pdftoppm）走不通；
`deck_qa.py` 用「解析文件本身」代替「渲染后目视」，覆盖边框越界、字号下限、自动缩字、
配色预算、图片透明性、图文重叠、每页信息量七类判据。

---

## 4. 数据格式速查

### 4.1 A 类：月度历史（预测器的训练/测试数据）
```csv
REGION,SETTLEMENTDATE,TOTALDEMAND,RRP,PERIODTYPE
VIC1,2026/03/01 00:05:00,5074.19,52.58,TRADE
```
- 5 分钟，**区间结束**时刻（`00:05` = 当天第 1 个，`24:00` = 第 288 个）
- **NEM 时间（AEST/UTC+10，全年不随夏令时平移）**
- `RRP` 是 2 位小数；`TOTALDEMAND` 单位 MW
- 每月行数 = 当月天数 × 288

### 4.2 C 类：抓取 store
```
dispatch_actual.csv      settlement_date, region_id, rrp, eep, total_demand,
                         run_no, dispatch_interval, intervention, source_file
p5min_forecast.csv       effective_time, region_id, interval_datetime,
                         rrp, total_demand, intervention, source_file
predispatch_forecast.csv effective_time, predispatch_seqno, run_no, region_id,
                         period_id, rrp, eep, total_demand, intervention, source_file
```
- `effective_time` = 该批报告的**发布批次时刻**（预测视角的「现在」）
- `interval_datetime` / `period_id` = **被预测的目标时刻**
- ⚠️ 出厂默认会把它们写成悉尼本地时间，夏令时期间与 A 类差 **12 个槽位**（见 AUDIT §3.5）

### 4.3 NEMWEB 原始报表
行首单字符是记录类型：`C` 报表头 / `I` 表头 / `D` 数据行。
- `I,DISPATCH,PRICE,5,SETTLEMENTDATE,RUNNO,REGIONID,...` —— `5` 是**负载字段数**，
  不是列数（列 = 其后所有字段）
- 找表靠 `_find_table`：**按列名匹配**，不按表名 —— 同名表在不同产品里列不同
- **D 记录里的时间字段一律带双引号**（`"2026/09/04 03:55:00"`）
- 日包 `PUBLIC_DISPATCHIS_YYYYMMDD.zip` 里**套着** 288 个单报 zip，每个再含一个 `.CSV` —— 要解两层

---

## 5. 排障

| 症状 | 原因 / 处理 |
|---|---|
| `Unrecognized function 'load_aemo_data'` | `MPC/First_Version_MPC` 不在 path 上（§3.1） |
| 跑完 MATLAB 看不到图 | 图窗被宿主清掉；跑与存必须在同一次调用内 |
| Python 脚本「没有输出」 | 沙箱吞掉被管道捕获的 stdout；脚本一律自己写 `.txt` 再读 |
| 抓取脚本警告 `SETTLEMENTDATE values failed to parse; sample='"2026/…"'` | 引号没剥（缺陷 D1，已修）。**这条警告一直存在，是发现问题的线索** |
| `dispatch_actual.csv` 只有 5 行 | D1 的后果：`settlement_date` 全空导致去重键塌陷（已修） |
| `PRICE_AND_DEMAND_*` 里 `RRP` 与实时价差几十块 | 先查时基（AUDIT §3.5），不要先怀疑数据源 |
| matplotlib 报 `Access is denied: AppData\Local\matplotlib` | 设 `MPLCONFIGDIR` 到工作区内（脚本已处理） |
| `git status` 报 `Access is denied` | 本机沙箱限制；用 `cmd /c 'git … > 文件 2>&1'` 再读文件 |

---

## 6. 变更纪律

- **git 按显式路径 `git add`，禁止 `git add -A`** —— 三人协作，宽口径会把队友的在制品卷进无关提交。
- **里程碑式提交**：一个完整交付提交一次，不刷「没啥更新」的 commit。
- `Weekly/` 是**本周工作区，默认不入 git**；文件备份走仓库外的本地备份目录。
- `Online_Data_Capture_Script/` 与 `Predicitor/` 是本人职责范围，可直接改。
- MATLAB 脚本**不写自动保存/导出代码**（`saveas`/`print`/`exportgraphics`/`writematrix`），落盘在调用侧做。
- 变量/函数 `snake_case`，类名 `UpperCamel`，缩进 3 空格；注释用英文、精简。
- 改完 MATLAB 文件后跑 `check_matlab_code` 静态检查。

---

## 7. 名词表

| 词 | 含义 |
|---|---|
| **NEM 时间** | 澳洲国家电力市场标准时间 = AEST = UTC+10，**全年不随夏令时平移**。AEMO 发布的一切原始数据都用它 |
| **AEDT / AEST** | 悉尼本地时间的夏令时/标准时形态，分别 UTC+11 / UTC+10 |
| **区间结束时刻** | `SETTLEMENTDATE` 标的是该 5 分钟区间的**终点**；`00:05` 是当天第 1 个槽位 |
| **slot / 槽位** | 一天 288 个 5 分钟槽位，`get_slot_index()` 把时刻映射到 1..288（`00:00` → 288） |
| **RRP** | Regional Reference Price，区域参考价，$/MWh，可正可负 |
| **RUNNO** | 同一区间的第几次求解；市场重跑会增加。取最大者 = 最后一次成功求解 |
| **intervention** | 干预定价标志；正常为 0 |
| **提前量 (lead)** | 目标时刻距发布时刻的 5 分钟步数，1..288 |
| **Template + AR(4)** | 当前最佳短期模型：滚动日模板 `T(s)` + 日内残差 AR(4) 递归 |
| **P5 / Predispatch** | AEMO 官方 5 分钟 / 30 分钟预测产品，分别提前约 1 h / 48 h |
| **价格钳位** | 把预测与实际都裁到滚动 30 日 Q1/Q99，使评分与 MPC 实际收到的信号一致 |
