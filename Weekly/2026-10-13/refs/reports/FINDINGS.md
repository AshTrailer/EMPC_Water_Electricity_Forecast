# EMPC_Water_Electricity_Forecast 报告与历史预测器代码：结构化摘要

调研范围：`C:\Ash\Projects\EMPC_Water_Electricity_Forecast` 下的全部报告文档与预测器代码。
未修改该项目下任何既有文件。本文件是本次调研唯一新建的产出。

读法说明：

- 每个结论后面给路径。给行号的，行号按本次读到的文件内容计。
- 代码里的数字照抄，未改写。
- 拿不准的地方标「未能确认」。
- 三处与任务书描述不符的实测事实，先记在这里：
  1. `decision_module` 不是 0 字节，是 **2 字节**，内容为 `0D 0A`（一个 CRLF），即空文件带一个 Windows 行尾。
  2. `Predicitor\ThetaY_Tracker\` 只有 **3 个** `.m`，不是 4 个（`init_theta_tracker.m`、`update_theta_tracker.m`、`predict_theta_tracker.m`）。git 全历史里该目录也只出现过这 3 个 `.m`。
  3. `Predicitor\archive\AR_RLS_predictor\` 有 **11 个** `.m`，不是 9 个。全 `archive\` 共 17 个 `.m`。

---

## 第一节 项目文档说了什么

### 1.1 项目根

| 文件 | 说了什么 |
|---|---|
| `README.md` | 项目总说明：毕设 EMPC 水泵电价预测，分工是 Predicitor(Ash) / MPC(Kehong) / Decision(Mingke)（`README.md:329-334`）。Predicitor 章节写的是「六个在线预测器」的统一基准（`README.md:81`、`README.md:93`），协议是 5 分钟更新、288 步递推、价格钳位到滚动 30 日 Q1/Q99，测试期 2 月前两周。§3.1.8 列了 5 条实验结论。目录树（`README.md:235-258`）把 `Decision/`、`MPC/`、`Online_Data_Capture_Script/` 三个目录标成 "empty"。 |
| `deck_text.md` | 2026-09-15 那版 PPT 的 markitdown 文本稿，共 26 页。前半是数据源与抓取（页面 3-5）、RLS AR(p) 滤波与迭代多步（页面 6-7）、日模板与 EWMA（页面 8）；中段是实验 1-5；后半是「六模型预测器套件」与两周基准结果（页面 17-24）。页面 22-24 给出六模型的 RMSE 表与「相对 persistence 改善」表。 |
| `Github_Code.txt` | 13 行的 git 速查 + 一段长提交说明。提交说明描述 `init_template_ar` / `update_template_ar` / `predict_template_ar` / `run_predictor_benchmark` 四件，明说基准跑「six predictors」。注意它写的路径是旧机路径 `C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project`（`Github_Code.txt:1`）。 |
| `requirements-frozen.txt` | 39 行 Python 冻结依赖。与预测器相关的是 `pandas==3.0.5`、`numpy==2.5.2`、`matplotlib==3.11.2`、`python-pptx==1.0.2`、`markitdown==0.1.7`、`xlsxwriter==3.2.9`。 |
| `.gitignore` | 39 行。除 MATLAB 常规忽略外，2026-09-23 周新增了 `AEMO_Data/zip_cache/`、`AEMO_Data/archive_cache/`、`AEMO_Data/window_60d_20260811_20261009\p5min_vic1_partial/`、`Weekly/**/_mplcache/`、`Weekly/**/_prev_qa/`（`.gitignore:28-39`）。 |

### 1.2 `Weekly\EMPC\2026-09-23\`

| 文件 | 说了什么 |
|---|---|
| `HANDOVER.md`（358 行） | 接手入口。**前 137 行是 2026-10-08 的新版**：预测器做了一次结构重整，从一个入口、一套协议、一张 (提前量 × 槽位) 误差图集出发，新增 Anchor-mix（`HANDOVER.md:10-13`）。§2 给目录现状，§4 给协议表，§5 列本轮修掉的三个缺陷，§6 给 120 天窗口的 9 模型中位数 RMSE 表与「赢下槽位数」表，§7 记本机坑，§8 列下一步 A1-1/A1-2/A1-3/A2-2。第 136 行起是「历史版本 —— 2026-09-23 周」，内容是数据格式速查、排障表、变更纪律、名词表。 |
| `MIGRATION.md`（123 行） | 2026-09-23 周的迁移与提交说明。里程碑提交 `2349068`，655 个文件。列出 5 个抓取缺陷 D1-D5 改在哪些文件、删掉的 4 个损坏文件及重建后的行数（`dispatch_actual.csv` 2880 行 / `p5min_forecast.csv` 3600 行 / `predispatch_forecast.csv` 2975 行，`MIGRATION.md:37-38`）。§2 列本周新增文件清单，§4 给脚本重放顺序。也说明 `Weekly/` 默认不入 git，`_mplcache/`、`_formula_tmp/`、`_prev_qa/` 可随时删。 |
| `TODO.md`（252 行） | 唯一待办权威。**前 103 行是阶段 A（2026-10-08 起飞）**：A1-1 Anchor-mix 系数正则化、A1-2 训练信号改钳位序列、A1-3 T+ARX 接 AEMO P5 偏差项、A1-4 可选扩展、A1-5 多窗口、A1-6 节假日表；A2 图像与文档；A3 工程与账目（A3-1/A3-2/A3-3 已勾完成，A3-4 旧路径、A3-5 空文件、A3-6 git 提交待做）；A4 四条待裁决。第 101 行起是阶段 B（2026-09-23 周历史），含 TD-1 到 TD-4 四条裁决、W-1 到 W-4 已完成项、F1-F4 公平化重跑、P1/P2/P3 待做、元层 skill 收录建议、已否决两条。 |
| `_commit_message.txt`（48 行） | 提交 `2349068` 的正文。逐条写 D1-D5 五个缺陷的机理。关键实测：D1 让 `dispatch_actual.csv` 从建库起永远只有 5 行；D5 关掉本地时间转换后八个月份全部 0 偏移，平均 `|dRRP|` 0.0007 到 0.0019 $/MWh。 |
| `_inbox\meta-candidates-2026-09-23.md`（21 行） | 待投递元层的 14 条候选草稿，一行一条 JSON。9 条 bug-log（NEMWEB 引号、strptime 宽度闸、NEM 时基、MPLCONFIGDIR、公式贴图透明底、公式图按高定尺）、2 条 skill（无渲染器的 pptx 静态 QA、MATLAB MCP 图窗活不过两次调用）、3 条 env-facts（无 LibreOffice/poppler、`.venv` 可用包清单、NEMWEB 归档规模）。 |
| `data_audit\AUDIT.md`（250 行） | 数据审计报告。一句话结论：月度 VIC1 文件与 AEMO 实时报表本来就没有分歧，分歧来自自己的抓取链路（`AUDIT.md:8-17`）。§1 把 `AEMO_Data` 分成 A/B/C/D 四类；§2 三源口径对照；§3 五个缺陷 D1-D5；§4 讲清 B 类导出是 DISPATCHIS 实际值 + PREDISPATCHIS 预测值的拼接；§5 对预测器的影响；§6 给本周六模型基准基线数字；§7 下一步。 |
| `data_audit\_before_fix\` | 4 个被替换掉的损坏文件备份：`dispatch_actual.csv`（560 B）、`p5min_forecast.csv`、`predispatch_forecast.csv`、`capture_state.json`。 |
| `data_audit\backfill_28d.log`、`backfill_pilot.log`、`capture_run.log` | 归档回填日志（28 天与试点）与修复后重跑抓取的日志。 |
| `data_audit\scripts\`（13 个 .py + 各自的 .txt） | 可重放脚本：`aemo_probe.py` 文件清点、`store_diagnosis.py` store 字段体检、`parser_replay.py` 重放原始 zip、`compare_sources.py` 三源比对、`dst_probe.py` DST 连续性、`timebase_census.py` 逐月时基普查、`timebase_verdict.py` 开关转换判决、`january_offset_look.py`、`archive_zip_probe.py`、`network_probe.py`、`archive_inventory.py`、`backfill_archive.py`、`build_error_matrix.py`。另有 `error_summary.json`（VIC1 的 P5 误差统计）与 `figures/F1..F3`。 |
| `predictor\ERROR_STUDY.md`（167 行） | AEMO P5 误差模型第一部分结论。窗口 2026-08-25 到 09-22，VIC1，8064 个区间，配对 96702 行，训练/测试 70/30。核心数字：P5 误差 RMSE 5 min 14.97 涨到 55 min **42.19**；`ε(k)` 的 ACF(1)=**+0.682**、同号段平均 **6.152**、最长 **122** 个区间。三阶修正模型 C1/C2/C3 在 5 min 上把 AEMO 自己改善 13.0%，30 min 后转负。五路对照里 5-10 min 赢家是 carry-forward persistence，15-55 min 是 T+AR(4)，AEMO 原始预测从未夺冠（`ERROR_STUDY.md:99-111`）。§7 列 5 条局限。 |
| `predictor\p5_vs_tar_report.txt`（48 行） | 四路对照控制台输出。误差矩阵 96702 行，T+AR 结果 57024 行，配对 56958 行，测试集 **17050 行**。逐提前量 RMSE 与 MAE 两张表、每个提前量的赢家清单。 |
| `predictor\p5_vs_tar.json` | 上一份报告的 JSON 版。 |
| `predictor\p5_vs_tar.py`（175 行） | 四路对照与出图脚本。 |
| `predictor\weekly_p5_compare.m`（163 行） | 把 T+AR(4) 放到与 AEMO P5 完全相同的起源与提前量上打分。只返回 table，不落盘。**硬编码旧机路径**（`weekly_p5_compare.m:44`）。 |
| `predictor\tar_p5_forecasts.csv` | 57,024 行 T+AR(4) 在 AEMO 起点上的预测。 |
| `predictor\benchmark_console.txt` | **0 字节**。但 `MIGRATION.md:81` 把它列为「六模型基准完整控制台输出」。 |
| `predictor\figures\` | `bench_week_aligned.png`、`bench_rmse_lead.png`、`bench_rmse_slot.png`、`bench_rmse_matrix.png` 四张六模型基准图，另有 E1-E4、C1 五张误差研究图。 |
| `deck\` | 2026-09-23 周 PPT 与其工具：`Capstone_Weekly_2026-09-23.pptx`（22 页）、`build_week2_deck.py`、`deck_kit.py`、`render_formula.py`、`deck_qa.py`、`list_pictures.py`、`deck_qa.txt`（0 项问题）。另有 `_prev_qa/`（上一版 53 张渲染图）、`_media_samples/`、`_formula_samples/`、`_formula_tmp/`。 |
| `backup\` | **空目录**，无任何文件。 |

### 1.3 `Weekly\EMPC\2026-10-08\`

| 文件 | 说了什么 |
|---|---|
| `handover_new_section.md`（137 行） | 内容与 `2026-09-23\HANDOVER.md` 的第 1-137 行一致，是 2026-10-08 新版那一段的单独副本。到此为止是完整的：§1 状态、§2 目录、§3 怎么跑、§4 协议表、§5 三个缺陷、§6 结论表、§7 环境坑、§8 下一步。 |
| `todo_new_section.md`（103 行） | 内容与 `2026-09-23\TODO.md` 的第 1-103 行一致，是阶段 A 的单独副本。 |
| `deck\Capstone_Forecasting_v1.pptx`、`.pdf` | 2026-10-08 版 PPT（22 页，5268 KB）与 PDF 导出。 |
| `deck\Capstone_Update_2026-10-08_EN.pptx` | 英文更新版。 |
| `deck\build_update_deck.py`（531 行） | 生成 `Capstone_Forecasting_v1.pptx`。§页面 4 标题明写 **"The eight models"**（`build_update_deck.py:325`），列 8 个模型；页面 11 是 AEMO P5 误差页（`build_update_deck.py:483-505`），结论写 "The result is negative. We report it as negative and keep P5 out of the eight models."；页面 12 下一步 5 条（`build_update_deck.py:510-524`）。 |
| `deck\deck_numbers.py`（258 行） | deck 的唯一数字权威。`TABLE_120` 是 120 天 8 模型 × 7 档的（合并 RMSE, 跨槽位中位数）；`CLAMPED_STD = 48.8`；`ANCHOR_C` 是 7 档的 (c_h, a_h, b_h)；`P5` 是新旧两个窗口的 P5 数字；`DEPRECATED` 列 4 个必须废弃的旧数字；`ledger()` 产出 260 行核验表。 |
| `deck\PPT_NUMBERS.md`（339 行） | 逐数字核验表，由 `deck_numbers.py` 与 pptx 自动生成。§一 定义 4 种口径；§二 260 行核验表，其中 246 行的值在 deck 里实测到；§三 必须废弃的旧数字（17.7 / 26.4 / 0.50 / 5.05）；§四 跨页一致性；§五 六个「同名量必须带限定词」的对照；§六 承认 4 组数字在仓库里找不到产出文件，并给出与 09-23 HANDOVER 表的逐条对照。 |
| `deck\check_deck.py`、`check_deck.txt` | 静态 QA 脚本与报告。十条判据全部通过；最低字号 10.0 pt；配色 6 个 sRGB 值；最大图文交叠 0.0%。报告明确说本机无法栅格化整页，判据 10 是估算不是渲染证据（`check_deck.txt:47-50`）。 |
| `deck\formulas\`（17 张 PNG） | 透明底公式贴图：`persistence`、`rolling_template`、`theta_y`、`t_ar4`、`t_dms4`、`carry_forward`、`cf_dms4`、`anchor_mix_a/b`、`template_def/fill`、`residual_def`、`delta_y`、`y_clamp`、`p5_gap`、`rmse`。另有 `render_check.json`。 |
| `deck\_render_check.txt`、`_tmp_render_formulas.py`、`_tmp_fetch_wheel.mjs`、`_wheels\`、`_pylibs\`、`_mplcache\` | 公式渲染自检与离线依赖：9 个 wheel（matplotlib 等）与解包后的 `_pylibs`（matplotlib / numpy / pandas / pyparsing 等第三方副本）。属工具链，不是项目代码。 |
| `deck\_formula_contact_sheet.png` | 17 张公式贴图的接触印相。 |
| `predictor\export_figures.m`（34 行） | 调用侧导出包装。跑 `run_predictor_suite.m`，同一次 MATLAB 调用内把所有 figure 按 `Name` 导出 PNG 到 `figures\`，并开 diary 写 `suite_console.txt`。 |
| `predictor\suite_console.txt` | **只有 6 行**，每行都是 `feature('HotLinks',0);cd('...2026-10-08\predictor')`，没有任何 suite 输出。 |
| `predictor\figures\`（21 张 PNG） | D 系列 7 张（按提前量单日）、G 系列 7 张（按提前量跨天）、`D_single_day__rolling_5-min`、`G_rolling_5-min__across_days`、`H_fixed_origin__288-step`、`I_long-horizon__many_origins`、`J_RMSE_288x288_heatmap`。 |

### 1.4 `Simulation_Log\`

| 路径 | 说了什么 |
|---|---|
| `convert_figs_to_png.m`（39 行） | 把 9 个 `.fig` 批量转 200 dpi PNG 到 `figures_png\`。**硬编码旧机路径**（`convert_figs_to_png.m:4`）。 |
| `Ash_20260812\AR+RLS+P_Controller_for_simple_constraint\Report.txt` | 数据加载（63360 点，电价 -969.97 到 19069.69 $/MWh，需求 1409.44 到 10783.74 MW）。三种滤波 RMSE：移动平均 **31.518**、移动中值 **33.475**、RLS **33.147** $/MWh。水箱闭环 288 步，最终水位 2.749 m，总能耗 840.9 kWh，水位范围 [2.496, 3.120] m。 |
| `Ash_20260812\AR+RLS+no_constraint_open_lood_controller\Report.txt`（309 行） | 同样的数据加载与滤波对比。开环仿真从 x0=3.12 m 起一路溢流，报告 289 行水位越上限 3.37 m 的警告，水位最高涨到 4.2 m 以上。这是「不加约束会怎样」的负面对照。 |
| `Ash_20260820\AR_Predictor+RLS\Report.txt`（46 行） | 预测实验六模型的控制台输出：纯 AR(4) **51.8** / AR(4)+全体模板 **43.6** / AR(4)+区分模板(固定1月) **43.8** / 类内7天窗 **54.3** / 类内28天窗 **44.5** / 截断 EWMA α=0.15 **46.3**。信号标准差 58.0 $/MWh。另给 1h/3h/6h/12h/24h 分档 RMSE。 |
| `Ash_20260820\Harmonic_State_Space_Kalman_Predictor_HSSKF\Report.txt`（39 行） | 方案 A 卡尔曼控制台输出。1 月谐波 OLS 拟合 R² **0.098**；OLS 系数 μ=38.6、a=[-18.9 -0.9 2.5]、b=[28.5 -18.9 -4.0]；残差 AR(4) 系数 [0.822 0.204 -0.131 0.022]、σ_ε=**33.8** $/MWh；A^288 谐波块与单位阵偏差 2.31e-14。测试期整体 RMSE **56.3**、MAE 41.5；95% 理论带覆盖率 **99.9%**；分档 RMSE 18.4/35.0/49.3/64.5/41.3，覆盖率每档都是 100.0%。 |
| `Ash_20260827\Predicitor_Order_Testing\Report.txt`（14 行） | 纯 AR(p) 阶数扫描 p=1..10 的完整表。总 RMSE 从 AR(3) 的 51.04 单调涨到 AR(10) 的 65.29。结论行：`Best overall: AR(3)   best 1h: AR(9)   best 24h: AR(3)`。信号 std 58.0 $/MWh。 |
| `Ash_20260827\Predicitor_Long_Term_Test\Report.txt`（15 行） | 89 天（2026-02-01 到 05-01）不分模板 A vs 分工作日周末 B。Overall A **134.0** / B **278.5**；Weekdays A 149.0 / B 327.1；Weekends A 84.1 / B **46.4**。24h 档 A 383.3 / B 1039.7。 |
| `Ash_20260827\Predicitor_Update_Different\Report.txt`（23 行） | 纯 AR(4) 更新节奏扫描。总 RMSE：5 min 26.8 / 30 min 29.2 / 1 h 34.1 / 6 h 57.2 / 24 h 51.8。同提前量对照表、按起点时段（00-06h/06-12h/12-18h/18-24h）的 RMSE 表。 |
| `Ash_20260827\Controller_MPC_QP_solver_static_Test\` | 只有一个 `.fig`，**无 Report.txt**。 |
| `Ash_20260915\Report.txt`（119 行） | 2026-09-15 那版六模型两周基准的完整控制台输出，是 `deck_text.md` 页面 22-24 数字的来源。Q1/Q99 起 -60.0/299.5、末 -33.6/178.7 $/MWh；钳位信号 std 51.3；覆盖度 14..14。含 Table 1-5、改善表、每提前量赢家、AR 短期跟踪检查（T+AR vs 模板在 5min 差 -30.6、24h 差 +12.1 $/MWh）。 |
| `figures_png\`（12 张 PNG） | 上述 `.fig` 的导出图，也是根目录 `build_deck.py` 的图片输入。 |

### 1.5 `Decision\`

| 文件 | 说了什么 |
|---|---|
| `decision_mpc.m`（69 行） | 「Economic MPC for Tank Pump Decision Module，可直接独立运行版本」。参数：预测时域 N=12 步（每步 5 min）、水箱动态系数 C=1.075、目标水位 0.65、上下限 0.40/0.90、偏差惩罚 lam=10、泵流量系数 Qmax=0.025、初值 x0=0.50。用 `intlinprog` 解 MILP，变量是 `[u1..uN, x1..xN, x_{N+1}]`，前 N 个是 0/1 整数。**价格是硬编码的 12 个数**（`decision_mpc.m:15`），注释写「Jerry预测输出电价序列（后续替换成predictor输出）」。有远期衰减权重 `1./(1+(0:N-1)*0.2)`。 |
| `..\decision_module`（根目录） | **2 字节**，内容是 `0D 0A`。git 历史里由提交 `6bca164 "Create decision_module"` 创建，此后从未写入内容。它是给 Decision 模块预留的空占位文件。任务书说它是 0 字节，实测是 2 字节的 CRLF 空文件。 |

### 1.6 `Related Paper\`

| 项 | 内容 |
|---|---|
| 文件 | `WangetalJWaterResorcuesASCE2021.pdf`，12 页，1,243,622 字节。PDF 元数据 creationDate `D:20210513012144`，modDate `D:20260812140155+10'00'`。 |
| 题目 | **Minimizing Pumping Energy Cost in Real-Time Operations of Water Distribution Systems Using Economic Model Predictive Control** |
| 作者 | Ye Wang, Kevin Too Yok, Wenyan Wu, Angus R. Simpson, Erik Weyer, Chris Manzie（全部墨尔本大学 / 阿德莱德大学） |
| 年份与出处 | 2021。J. Water Resour. Plann. Manage., 2021, 147(7): 04021042。DOI 10.1061/(ASCE)WR.1943-5452.0001399。2021-05-13 在线发表。 |
| 结论 | 提出一个实时 WDS 的 EMPC 框架，**创新点是把每个泵站开几台泵作为决策变量**，用整数规划求解，代价是最小化总抽水能耗，约束是所有用水需求必须满足。用 Richmond Pruned 网络（两个泵站共三台泵）+ EPANET 水力仿真做闭环。结果：峰值电价时段少抽水、只在该抽时抽，非峰时段多开泵。与触发水位控制对比，**最小需求工况下能耗接近，但触发水位控制的抽水能量贵 2.5 倍**（Table 5 的 cost ratio 2.50），原因是 EMPC 用上了时变电价。作者也承认模型与需求/电价预测都有不确定性，EMPC 表现出一定固有鲁棒性，但增强鲁棒性的鲁棒控制是未来工作；网络更复杂时算法的计算可解性会成为挑战。数据与代码在 https://github.com/yewangunimelb/watersystem。 |
| 项目里谁引用它 | `MPC\Basic 1.2\README.md:123-204`。该项目用它做 Richmond Pruned 网络的 24 小时用水倍率（Figure 2，期刊页 04021042-5），但实际 24 个数取自作者仓库的 `Richmond_Pruned.inp`（提交 `dd94817dbcf7bb46f244090234eb3a4983ca3891`），并用 Exeter 的 `Richmond_skeleton.inp` 交叉验证。倍数集合平均 0.99625、最小 0.39、最大 1.61；基础需求 25 L/s 对应 9.75 到 40.25 L/s。 |

### 1.7 `MPC\`（一句话）

`MPC\` 是队友负责的**水箱层经济 MPC 的五个版本迭代目录**（`First_Version_MPC` 为初版，`Basic 1.0` 到 `Basic 1.3` 逐步从单水箱单泵做到三泵 MILP 滚动时域，配 README、测试与结果图），本报告不深入。

### 1.8 `AEMO_Data\` 里的说明文档（与第五节相关，先记在此）

| 文件 | 说了什么 |
|---|---|
| `window_60d_20260811_20261009\README.md`（217 行） | PD7DAY 7 天预调度，窗口 2026-08-11 到 10-09 共 60 天，只存在于 NEMWEB 的 CURRENT，ARCHIVE 没有这个产品。5 个区域各 63,240 行，合计 316,200 行 34.38 MB（34,375,434 字节），180 个 run 无缺口。时间戳是 NEM 时间。 |
| `window_60d_20260811_20261009\README.md`（160 行） | PREDISPATCH 30 分钟，同 60 天窗口，每天 48 个 run，5 个区域各 159,840 行，合计 799,200 行 101.69 MB（101,692,749 字节）。horizon 15.5 到 39.0 小时。**未做任何钳位**。数据来自 ARCHIVE 周包 + CURRENT 单批报表补齐。 |
| `window_120d_20260201_20260601\_build_stats.json` | DISPATCHIS + P5MIN + PREDISPATCH 15 个 CSV，窗口 2026-02-01 到 2026-06-01（120 天），5 区域。`predispatch_identity_violations: 0`，`periods_per_issue` 32 到 79，`predispatch_lead_minutes` 0.0 到 2340.0。合计 444,281,629 字节。 |
| `window_60d_20260811_20261009\_build_stats.json` | 同结构，5 个文件，60 天，合计 101,692,749 字节。 |
| `window_60d_20260811_20261009\p5min_vic1_partial\_days_done.json` | 回填进度：DISPATCHIS 与 P5MIN 各覆盖 2026-08-25 到 09-21（`P5MIN` 每天 3456 行）。 |
| `window_60d_20260811_20261009\p5min_vic1_partial\_days_done.json` | 同上并加长到 **2026-10-06**。 |

---

## 第二节 历史上试过哪些预测器

「已归档」列：是 = 在 `Predicitor\archive\` 或该功能已被显式放弃；否 = 在 `Predicitor\` 在役目录里。

### 2.1 当前入口 `run_predictor_suite.m` 实际计算的 8 个

| # | 名称 | 结构 | 输入 | 结果或结论 | 已归档 |
|---|---|---|---|---|---|
| 1 | Persistence(yest) | 昨天同槽位原样搬运 | `y_prev(u)`，即每槽位前一天的原始价 | 120 天跨槽位中位数 5min 到 12h 全为 **47.7**、24h **59.0** $/MWh（`HANDOVER.md:85`）。对提前量完全平。 | 否 |
| 2 | Rolling template | 每槽位 28 天滚动均值，逐点更新（先进先出环缓冲） | 最近 28 天同槽位原始价 | 中位数 7 档全为 **45.0** $/MWh（`HANDOVER.md:86`）。六模型旧基准里 2 周合并 RMSE **46.4**，是旧口径最好（`Ash_20260915\Report.txt:117`）。 | 否 |
| 3 | Theta-y tracker | 每槽位一个标量增益 θ(s) 乘昨天同槽位价，θ 由标量 RLS 学 | 前一天同槽位价作回归量、当天真实价作目标；λ=0.98 | 中位数 7 档全为 **45.6** $/MWh（`HANDOVER.md:87`）。旧基准 2 周 **49.7**，比 persistence 好 2.9%（`Ash_20260915\Report.txt:94`）。 | 否 |
| 4 | T+AR4 | 滚动模板 + **一条日内连续残差 AR(4)**，系数向量 RLS 每 5 分钟更新，288 步迭代递推 | 残差 `r = y − T_pre`；回归量是紧邻的 4 个残差 | 中位数 5min **9.8** / 30min 15.2 / 1h 20.4 / 3h 34.3 / 6h 44.6 / 12h 48.7 / 24h **45.1**（`HANDOVER.md:89`）。短档强、6h 后被模板追平，是全部结论里最稳的一条。 | 否 |
| 5 | Carry-forward | 把最新观测值平推 288 步，对 h 完全平 | `y(t)` 最新价 | 中位数 9.9 / 13.3 / 16.6 / 29.9 / **46.3** / **58.8** / 47.7（`HANDOVER.md:90`）。短档第二好，6h 起最差。 | 否 |
| 6 | T+DMS4 refit | 模板 + **直接多步 OLS**（DMS），每个提前量一组系数，14 天窗口每天 00:05 重估；回归量含截距、模板、4 个残差滞后、4 个差分滞后 | 钳位价序列 `yc_all`、其一阶差分、残差序列、模板快照 | 中位数 9.8 / 15.1 / 19.4 / 30.5 / 37.2 / 41.6 / **41.4**（`HANDOVER.md:91`）。长档明显优于 T+AR4。 | 否 |
| 7 | CF+DMS4 refit | carry-forward + 同一套直接多步 OLS（用差分滞后，不用模板） | 同上，但锚点是当前价不是模板 | 中位数 9.0 / 13.4 / 16.8 / 30.0 / 46.3 / 58.8 / 47.7（`HANDOVER.md:92`）。短档最好，长档塌回 carry-forward 水平。 | 否 |
| 8 | Anchor-mix refit | `y(k+h) = c_h + a_h·y(k) + b_h·T + Σφ·r + Σψ·Δy`，**每个提前量独立一组系数**，每天重估（14 天窗） | 钳位价、模板快照、4 个残差滞后、4 个差分滞后 | 中位数 9.0 / **13.1** / 17.3 / **29.2** / **35.8** / **40.6** / **40.9**（`HANDOVER.md:93`），7 档里赢 5 档。每提前量赢下的槽位数 113/130/83/91/158/157/142（`HANDOVER.md:99-105`）。**已知缺陷：a_h 在长提前量处出问题**（见第四节）。 | 否 |

### 2.2 在役目录里但 `run_predictor_suite.m` 不调用

| 名称 | 结构 | 输入 | 结果或结论 | 已归档 |
|---|---|---|---|---|
| Blend A | 每槽位凸组合 `w·T + (1−w)·r̂`，w 由标量 RLS 学后裁到 [0,1] | 模板 `T`、残差 AR 预测 `r̂`、二者的一步前向对 | 旧基准 2 周 RMSE **55.6**、MAE 41.3、Bias **+23.1**；5min 38.0、24h 62.6（`Ash_20260915\Report.txt:54`）。全线不如其组成部分。`archive\README.md:11` 说明原因：把**水平** T 与**校正量** r̂ 做凸组合，参数化本身不可能赢；实测权重停在 **0.46**（中位数）。 | 初始化函数在 `archive\Blend_TemplateAR\`；但 `Shared\predict_blend.m` 与 `Shared\update_blend_weights.m` 仍在在役 `Shared\` 里，且**没有任何在役调用点**（全项目仅 `archive\run_predictor_benchmark_v1.m` 调用） |
| Blend B | 同上，第一分量换成 `θ(s)·y_yesterday` | 昨天跟踪预测、残差 AR 预测 | 旧基准 2 周 **61.4**、Bias **+29.3**；5min 43.6、24h 68.6（`Ash_20260915\Report.txt:55`）。 | 初始化函数在 `archive\Blend_YT_AR\`；同上的死件问题 |
| 纯 AR(p)（中心化） | `r(t) = Σφ_j r(t−j) + e`，无模板无截距，递推 288 步 | 减去 1 月均值的中心化序列 | 阶数扫描 p=1..10：总 RMSE AR(1) **51.63**、AR(3) **51.04**（最好）、AR(4) **51.84**、AR(10) **65.29**。24h 档 AR(10) 涨到 **94.89**。信号 std 58.0 $/MWh。结论 `Best overall: AR(3)`。 | 是（`archive\AR_RLS_predictor\run_ar_order_sweep.m`） |
| AR(4) + 全体日模板 | 全体 1 月均值模板 + AR(4) 残差递推 | 1 月全月模板（不分类） | 7 天 RMSE **43.6**、MAE 28.1（`Ash_20260820\AR_Predictor+RLS\Report.txt:32`） | 是（`run_prediction_experiment.m`） |
| AR(4) + 区分模板（固定 1 月） | 工作日/周末两套模板，固定不更新 | 1 月按类分模板 | 7 天 RMSE **43.8**、MAE 30.1；24h 档 **24.8**，是六者中最好的长档 | 是 |
| AR(4) + 类内 7 天窗 | 工作日取最近 7 个工作日、周末取最近 7 个周末日 | 类内 7 天滚动窗 | 7 天 RMSE **54.3**、MAE 35.1（最差） | 是 |
| AR(4) + 类内 28 天窗 | 类内 28 天滚动窗 | 类内 28 天 | 7 天 RMSE **44.5**、MAE 30.4 | 是 |
| AR(4) + 截断 EWMA | `w_k = (1−α)^k`，α=0.15、ε=0.01 → K=28 个类内天，权重低于 ε 的彻底丢弃 | 类内日 profile 缓冲 | 7 天 RMSE **46.3**、MAE 32.4 | 是（`init_ewma_state.m` + `update_template_ewma.m` + `weighted_profile_mean.m`） |
| 不分 vs 分工作日周末（89 天） | 同上 A/B 两套模板，28 天窗，89 天测试 | 2026-02-01 到 05-01 | Overall A **134.0** / B **278.5**；Weekdays A 149.0 / B 327.1；Weekends A 84.1 / **46.4**。24h 档 A 383.3 / B **1039.7**。结论：分法救周末、伤工作日，不是明确的净胜。 | 是（`run_template_class_long_test.m`） |
| 更新节奏扫描 | 纯 AR(4)，每隔 K 步重发一次预测 | K = 1, 6, 12, 72, 288 | 总 RMSE：5 min **26.8** / 30 min 29.2 / 1 h 34.1 / 6 h 57.2 / 24 h 51.8。同提前量对照表显示 1 步档 5min 26.8 对 30min 档 15.5，说明「总 RMSE 混了起点时段与提前量」；按起点时段分开后 24h 档只有 00-06h 有值（51.8）。 | 是（`run_update_cadence_sweep.m`） |
| 移动平均滤波 | 在线环形缓冲窗口均值 | 新数据点、窗口大小 | 用于滤波对比：RMSE **31.518** $/MWh（`Ash_20260812\AR+RLS+P_Controller...\Report.txt:25`） | 是（`archive\Testing_Filter\apply_moving_average.m`） |
| 移动中值滤波 | 在线环形缓冲窗口中值 | 同上 | RMSE **33.475** $/MWh | 是（`apply_median_filter.m`） |
| 自适应 RLS AR(p) 滤波 | AR(p) 系数 RLS 在线估计；带分母闸、岭阻尼 `P+=εI`（ε=1e-6）、迹上限 1e6、条件数软重启（阈 1e10）、梯度裁剪 ±0.5 | 新数据点、状态、λ=0.98、δ=100、p=4 | RMSE **33.147** $/MWh | 是（`apply_rls_filter.m`）。旧 AR 扫描/节奏扫描都靠它。 |
| 谐波状态空间卡尔曼（方案 A） | 水平 + 3 阶谐波 + 残差 AR(4) 的状态空间，卡尔曼滤波在线更新，`P` 闭式递推给理论预测误差带 | 1 月训练（OLS 谐波 + AR(4) + 逐日系数差分估 Q + 滤波预热）；测试期每天 00:00 发 288 步 | 7 天整体 RMSE **56.3**、MAE 41.5；信号 std 58.0；95% 带覆盖率 **99.9%**（分档全 100%，说明 Q/R 标定过宽）。1 月谐波 OLS R² 只有 **0.098**。分档 RMSE 18.4 / 35.0 / 49.3 / 64.5 / 41.3。 | 否（`Predicitor\Kalman_predictor\`，`archive\README.md:17` 说「仍在役，协议不同，单独运行」） |
| T+ARX（接 AEMO P5 偏差项） | 计划把 `g_{t+h|t} = π_{t+h|t} − T(s_{t+h})` 作为外生回归量融入 | AEMO P5 官方 5 分钟预测 + 自建模板 | **只有文档，没有实现代码。** 实测（`TODO.md:28-30`）：8/25-9/22 同批起点，第一小时 pooled RMSE 16.72 → 加 P5 后 **15.51（−7.2%）**，权重 5min 0.26 → 45min 0.55；但固定权重有一天翻车（09-17 **−33%**），朴素在线 RLS 又超配（**16.86**）。`build_update_deck.py:490` 的后续结论是否定的：把 g 当回归量只把样本外增益从 **−4.3%** 抬到 **+2.7%**；`build_update_deck.py:504` 与 `:524` 都写 "keep P5 out of the eight models" / "P5 stays out of the eight models"。 | 未实现（P5 融合分支已被显式放弃） |
| 按提前量分段融合 | 想法：≤10 min 用 carry-forward，>10 min 用 T+AR(4)，把「修正后 AEMO」当候选之一 | — | 只有文档（`ERROR_STUDY.md:165-166`、`TODO.md:203-204`），未实现 | 未实现 |
| lead-time 混合 | 想法：按提前量在 AR 与模板之间混，而不是一套 per-slot 权重 | — | 只在 `deck_text.md:409-410` 的 Next steps 里提了一句，未实现 | 未实现 |

---

## 第三节 Kalman 与 Theta-y 两个模型的数学结构逐符号说明

### 3.1 Theta-y tracker（`Predicitor\ThetaY_Tracker\`，3 个文件）

来源：`init_theta_tracker.m:1-31`、`update_theta_tracker.m:1-28`、`predict_theta_tracker.m:1-26`、`Shared\rls_scalar_step.m:1-31`。调用点在 `run_predictor_suite.m:110,141,176,200`。

模型方程：

```
ŷ(t+h|t) = θ(s(t+h)) · y(s(t+h) − 288)
```

逐符号：

| 符号 | 代码名 | 含义 | 取值 / 初值 |
|---|---|---|---|
| `t` | `idx` | 当前预测起点在整条流里的下标 | 从热身末开始 |
| `h` | `hv = (1:288)'` | 提前量，5 分钟步数 | 1 到 288 |
| `s` | `s = slot_seq(idx)` | 起点所在的一天内槽位 | 1 到 288。`get_slot_index` 把 00:00 映射到 **288**（`get_slot_index.m:18`），00:05 映射到 1 |
| `u(h)` | `target_slots(s,288,288)` | 第 h 步目标槽位 | `u = mod(s − 1 + (1:288)', 288) + 1`，所以 `u(1) = s + 1`（`target_slots.m:15`） |
| `θ(s)` | `tracker.theta` | **每槽位一个标量增益**。这是「theta」的全部含义：它只回答「昨天的同槽位价，今天要乘几倍才接近今天」。不是模板系数，不是 AR 系数，也不是槽位本身。 | 初值 **1**（`init_theta_tracker.m:27`）；θ=1 时模型退化成 persistence |
| `y(s+h−288)` | `tracker.y_prev(s)` | 该槽位**前一天**的原始价 | 初值 0，配合 `tracker.has_prev` 标志；只在 has_prev 为真时才当回归量用（`update_theta_tracker.m:19`） |
| `x` | `x = tracker.y_prev(slot)` | RLS 的回归量，即 24 小时滞后的同槽位价 | 标量 |
| `y` | `y_true` | 该槽位**当天**到达的真实原始价 | 标量 |
| `λ` | `tracker.lambda` | RLS 遗忘因子 | **0.98** |
| `δ` | `rls_delta` | 初始协方差尺度 | **100** |
| `P(s)` | `tracker.P` | 每槽位一个标量协方差 | 初值 δ=100；上限 1e8（`rls_scalar_step.m:28-30`） |
| `K` | — | 标量 RLS 增益 | `K = P·x / (λ + P·x²)` |
| `ŷ` | `y_hat` | 一步先验预测 | `ŷ = θ·x` |

更新律（`rls_scalar_step.m:16-30`）：

```
denom = λ + P·x²          （若 < 1e-10 则跳过本次更新）
K     = P·x / denom
θ_new = θ + K·(y − θ·x)
P_new = (1 − K·x)·P / λ   （再截到 ≤ 1e8）
```

关键性质：

- **每槽位每天最多更新一次**。因为回归量是「昨天同槽位」，而 `y_prev` 在每次更新末尾被当前值覆盖（`update_theta_tracker.m:26`），所以要等一整天才会再次成为有效回归量。
- 更新**在吃数阶段**做（`run_predictor_suite.m:176`），预报在之后发（`run_predictor_suite.m:200`），符合 suite 的「先吃后预测」信息集。
- **预测与提前量无关**。`predict_theta_tracker` 只用 `θ(u)` 与 `y_prev(u)`，不递归、不衰减，所以它的 RMSE 对 h 是一条平线（实测 7 档全 45.6，`HANDOVER.md:87`）。
- 它用的全是**原始价**。`θ` 的估计与 `y_prev` 都不经过钳位，只有打分时才把 `θ(u)·y_prev(u)` 与目标一起裁剪（`run_predictor_suite.m:212-213`）。

### 3.2 Kalman 谐波状态空间预测器（`Predicitor\Kalman_predictor\`，5 个 .m）

来源：`build_harmonic_ss_model.m`（训模）、`make_harmonic_C.m`（观测矩阵）、`kalman_filter_step.m`（一步滤波）、`kalman_predict_288.m`（288 步预测）、`run_kalman_prediction.m`（驱动与出图）。

**观测方程与状态**

```
y(t) = μ(t) + Σ_{k=1..K} [ a_k(t)·sin θ_k(t) + b_k(t)·cos θ_k(t) ] + r(t)
x     = [ μ, a1, b1, a2, b2, a3, b3, r_t, r_{t−1}, r_{t−2}, r_{t−3} ]'     (11×1)
y(t) = C(t)·x(t)
```

逐符号：

| 符号 | 代码名 | 含义 | 取值 / 初值 |
|---|---|---|---|
| `t` | — | 5 分钟采样时刻 | — |
| `slot(t)` | `slot` | 一天内第几个 5 分钟槽位 | 1 到 288，由 `get_slot_index` 给；00:00 记 288 |
| `θ_k` | `theta = 2π(slot−1)/288` | 第 k 阶谐波的相位 | 槽位 1（00:05）相位为 **0**（`build_harmonic_ss_model.m:120-123`）。注意不是 `2π·slot/288` |
| `y(t)` | `price_hist` / `y_obs` | 观测到的**原始**电价（不钳位） | $/MWh |
| `K` | `n_harm` | 谐波阶数 | 默认 **3**，`run_kalman_prediction.m:60` 传 3 |
| `p` | `ar_order` | 残差 AR 阶数 | 默认 **4**，`run_kalman_prediction.m:61` 传 4 |
| `nx` | `model.nx` | 状态维数 | `1 + 2K + p = 11` |
| `μ` | `x(1)` | 水平/趋势状态，随机游走 | 初值 = 1 月谐波 OLS 的截距，实测 **38.6** |
| `a_k, b_k` | `x(2..2K+1)` | 第 k 阶谐波的正弦 / 余弦系数 | 初值 = 1 月谐波 OLS 系数，实测 a=[-18.9 -0.9 2.5]、b=[28.5 -18.9 -4.0] |
| `r_t` | `x(i_ar)`，`i_ar = 1+2K+1 = 8` | 残差状态，即 AR 块的第一个分量 | 初值 0；`C` 里第 8 位是 1，所以 r(t) 直接进观测 |
| `φ` | `model.phi` | 残差 AR(p) 的最小二乘系数（在谐波残差上拟合） | 实测 [0.822 0.204 -0.131 0.022] |
| `σ_ε` | `model.sigma_eps` | 残差 AR 的扰动标准差 | 实测 **33.8** $/MWh |
| `A` | `model.A` | 状态转移矩阵，分块对角、线性时不变 | 见下 |
| `Q` | `model.Q` | 过程噪声 | 见下 |
| `R` | `model.R` | 观测噪声 | `max(σ_ε²·1e-3, 1e-4)`。理论上是 0（出清价精确观测），取小值只为数值稳定 |
| `C(t)` | `make_harmonic_C` | 1×nx 观测行向量 | `[1, sinθ1, cosθ1, ..., sinθK, cosθK, 1, 0, ..., 0]`，第一个 1 给 μ、最后一个 1 给 r_t（`make_harmonic_C.m:21-26`） |
| `x0, P0` | `model.x0, model.P0` | 用 1 月数据逐点滤波预热后的初始状态与协方差 | `P` 初值 `σ_ε²·I`（`build_harmonic_ss_model.m:106`） |

**A 的三个分块**（`build_harmonic_ss_model.m:82-92`）：

- 趋势块：`A(1,1) = 1`（随机游走）。
- 谐波块 k：`[[cos ω_k, sin ω_k], [−sin ω_k, cos ω_k]]`，`ω_k = 2πk/288`。性质是 `A^h` 的谐波块等于旋转 `h·ω_k` 角，`A^288` 回到单位阵，所以 24 小时预测的谐波相位自洽。这一条被实测验证：`A^288` 谐波块与单位阵偏差 **2.31e-14**（`Ash_20260820\...\Report.txt:27`）。
- AR 块：伴随矩阵。第一行是 `φ'`，下面 `p−1` 行是移位单位阵。

**Q 的构造**：

```
Q = diag([q_step(1), q_step(2..2K+1), σ_ε², 0, ..., 0])
q_step = max( var( 逐日重拟合的谐波系数的一阶差分, 0, 2 ) / 288, 1e-6 )
```

即过程噪声不是拍的，是拿「每天重拟合一次谐波系数的日间变化量」除以 288 当作每步噪声（`build_harmonic_ss_model.m:67-79`）。

**滤波一步**（`kalman_filter_step.m:20-30`）：

```
x(t|t−1) = A·x(t−1|t−1)
P(t|t−1) = A·P(t−1|t−1)·A' + Q        （随后对称化）
S        = C·P(t|t−1)·C' + R
K_k      = P(t|t−1)·C' / S
innov    = y(t) − C·x(t|t−1)
x(t|t)   = x(t|t−1) + K_k·innov
P(t|t)   = (I − K_k·C)·P(t|t−1)        （随后对称化）
```

**288 步预测**（`kalman_predict_288.m:38-50`）：

```
x̂(t+h|t)  = A·x̂(t+h−1|t)              逐次左乘 A
P(t+h|t)  = A·P(t+h−1|t)·A' + Q        闭式递推
slot_pred = mod(slot_now − 1 + h, 288) + 1
C         = make_harmonic_C(model, slot_pred)
ŷ(t+h)    = C·x̂(t+h|t)                 即 pred_mean
σ_ŷ(h)    = sqrt( C·P(t+h|t)·C' + R )   即 pred_sd，95% 带 = ±1.96σ
```

另有 `pred_harm`：把 `C` 的第 `i_ar` 位（残差分量）置 0 再乘状态，得到 μ + 谐波、不含 AR 残差的部分（`kalman_predict_288.m:48-49`）。它用来回答「周期结构本身捕捉了多少」。

**协议与结果**：1 月训练、2 月 1 到 7 日测试，**每天 00:00 用当前滤波状态做一次 288 步预测**，当天数据逐点到达时在线滤波更新（`run_kalman_prediction.m:92-115`）。实测整体 RMSE 56.3、95% 带覆盖率 99.9%。覆盖率接近 100% 说明 Q/R 标定过宽，理论带没有实际约束力。

**未能确认的两点**：

1. `run_kalman_prediction.m` 里没有钳位。它的打分用原始价，而 `run_predictor_suite.m` 用钳位价，两者的 RMSE 不可直接比。`archive\README.md:17` 说它「协议不同」正是此意，但没有明说不钳位。
2. 教授要的「theory prediction error」是否就指 `pred_sd`，文档里只有 `run_kalman_prediction.m:17` 的一句注释（「→ 教授要的 "mathematics solution for theory prediction error"」）作依据，**未能确认**是否有更正式的表述。

---

## 第四节 文档与代码之间的矛盾点

### 4.1 模型个数：同一件事有 6、8、9 三种说法

| 说的地方 | 说的个数 | 与代码是否一致 |
|---|---|---|
| `Predicitor\run_predictor_suite.m:22-26` 顶部注释 `MODELS` | **9**（1 Persistence / 2 Rolling template / 3 Theta-y tracker / 4 T+AR(4) forecast-first / 5 T+AR(4) ingest-first / 6 Carry-forward / 7 T+DMS4 / 8 CF+DMS4 / 9 Anchor-mix） | **不一致** |
| `Predicitor\run_predictor_suite.m:98-100` 的 `names` 与 `n_models = numel(names)` | **8**（"Persistence(yest)","Rolling template","Theta-y tracker","T+AR4","Carry-forward","T+DMS4 refit","CF+DMS4 refit","Anchor-mix refit"） | 这是代码实际算的个数 |
| `Weekly\EMPC\2026-10-08\deck\build_update_deck.py:323-335` | **8**（页面标题 `build_update_deck.py:325` 写 "The eight models"，`:480` "Full 8 by 7 table"） | 与代码一致 |
| `Weekly\EMPC\2026-10-08\handover_new_section.md:23`（= `Weekly\EMPC\2026-09-23\HANDOVER.md:23`） | **9**（"9 个模型 × 120 天 × 288 起点 × 288 步"） | **不一致** |
| `README.md:81`、`README.md:93`、`README.md:278` | **6**（"six online predictors"、"The Six Predictors"） | **不一致**，这是 2026-09-15 版的旧口径 |
| `deck_text.md:5`、`:245`、`:249`、`:265`；`Github_Code.txt:12`；`Weekly\EMPC\2026-09-23\deck\build_week2_deck.py:266,269` | **6** | **不一致**，同上 |
| `Predicitor\archive\run_predictor_benchmark_v1.m:159` `n_models = 6` | **6** | 与它自己的 6 个模型一致 |

连带的两处：

- `run_predictor_suite.m:210` 的 `map = [3 2 4 5 6 7 8]` 是**对 8 元素 `names` 的下标**，不是对顶部注释 9 个模型的下标。同一个文件里 `4` 在两处含义不同（顶部是 forecast-first，`map` 里是 T+AR4 ingest-first）。
- `handover_new_section.md:88`（= `HANDOVER.md:88`）的表里有 `T+AR4（先预测）` 一行，`HANDOVER.md:99-105` 的槽位数表里也有 `T+AR4先预测` 一列。**当前代码不计算这个模型**，`Weekly\EMPC\2026-10-08\predictor\suite_console.txt` 又只有 6 行 `feature('HotLinks',0);cd(...)`、没有任何 suite 输出，所以这一行数字的来源**未能确认**（可能是 `run_predictor_suite.m` 的某个中间版本，也可能是别处转录）。

### 4.2 顶部注释里的 forecast-first 模型（模型 4）在代码里不存在

- `run_predictor_suite.m:13-14` 写 "Model 4 keeps the older forecast-first convention for reference (see Fig. 5)"。
- `handover_new_section.md:60` 写「模型 4 保留旧的"先预测后吃数"口径作对照（图 F5）」，`HANDOVER.md:111` 还给了数字「5 分钟档 11.05 → 9.76（约 −12%）」。
- 代码里**没有** forecast-first 的预报路径。`rhat_prev` 与 `have_prev` 在 `:117` 声明、在 `:207` 赋值，**此后从未被读**，是给这个模型留的死变量。
- `Weekly\EMPC\2026-10-08\predictor\figures\` 里也**没有** `F5_information_set.png`；`TODO.md:48-49` 把它和 F1-F4 一起列为「已出 5 张」，但该目录只有 D/G/H/I/J 系列共 21 张。

### 4.3 Anchor-mix 的正则化已经写好，但没被启用

- `Predicitor\Anchor_AR_predictor\fit_anchor_mix.m:48-49` 声明 `convex (1,1) logical = false` 与 `shrink (1,1) double = 0` 两个开关，并在 `:82-97` 完整实现了「凸形式 + 岭惩罚」两条路径。
- `Predicitor\run_predictor_suite.m:183` 的调用只传 8 个位置参数（`yc_all, dc_all, r_seq, T_snap, day_col, idx, refit_days*n_slots, p`），所以 `convex` 取默认 **false**、`shrink` 取默认 **0**，即**无正则的最小二乘**。
- 这正好命中 `TODO.md:16-20`（A1-1）与 `handover_new_section.md:113-114` 记的问题。`fit_anchor_mix.m:16-19` 自己也把病因写在注释里：无约束最小二乘在 11 个共线回归量上会把 `a_h + b_h` 推到 **1.117**（6 小时处）、把 `b_h` 推成负值（24 小时处）。
- 结论：A1-1 的「加正则化」这条待办，代码侧已经做完，缺的是在 `run_predictor_suite.m:183` 把两个开关传进去。

### 4.4 Anchor-mix 系数的两个数字来源不一致

- `handover_new_section.md:113-114`（= `HANDOVER.md:113-114`）与 `TODO.md:17` 说：`a_h`（当前价权重）在 **15–18 小时**提前量处变成 **−0.08**，`a_h + b_h` 掉到 **0.45**。
- `Weekly\EMPC\2026-10-08\deck\deck_numbers.py:46` 给的 120 次每日重估均值是：h=288 时 `(c,a,b) = (15.17, 0.820, −0.068)`，`a+b = 0.752`；h=144 时 `(11.53, 0.194, 0.651)`，`a+b = 0.845`。
- `Weekly\EMPC\2026-10-08\deck\PPT_NUMBERS.md:309` 解释了差异的来源：「表中是 120 次每日重估的均值；**单日在 15 到 18 小时提前量会跑成负值**」。所以 −0.08 是**单日重估值**、0.820 是**120 天均值**，两者口径不同。
- 但 **0.45** 这个数在 `deck_numbers.py`、`PPT_NUMBERS.md`、`fit_anchor_mix.m` 里都找不到。文档自己给的另一个数（6 小时处 1.117）与 `deck_numbers.py` 的 h=72（6 小时）`a+b = 1.108` 也对不上（1.117 对 1.108）。这两个数**未能确认**。

### 4.5 已声称修好的旧路径，其实只剩一处没修；已声称没修的，其实已经修好了

| 文档说的 | 实测 |
|---|---|
| `handover_new_section.md:120-122`（= `HANDOVER.md:120-122`）与 `TODO.md:80-83`（A3-4）说 `Online_Data_Capture_Script/aemo_config.py` 的 `OUTPUT_DIR` **仍指向已不存在的旧路径** `C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\AEMO_Data`。 | `Online_Data_Capture_Script\aemo_config.py:14` 已经是 `Path(r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data")`。git 提交 `cb09da2`（"Predictor suite rework: lead-aware atlas, new models, capture path fix"）改了 `aemo_config.py` 2 行。**这条待办已经不成立。** |
| — | 反过来，三处在役或声明在役的代码**仍**硬编码旧路径：`Predicitor\Kalman_predictor\run_kalman_prediction.m:28`（`archive\README.md:17` 说 Kalman_predictor「仍在役」）、`Weekly\EMPC\2026-09-23\predictor\weekly_p5_compare.m:44`、`Simulation_Log\convert_figs_to_png.m:4`。归档脚本里还有 5 处：`archive\run_predictor_benchmark_v1.m:50`、`run_ar_order_sweep.m:25`、`run_update_cadence_sweep.m:24`、`run_template_class_long_test.m:38`、`run_prediction_experiment.m:48`。 |

### 4.6 `rls_vector_step.m` 的注释还停在已被删除的「跨天 AR」上

- `Predicitor\Shared\rls_vector_step.m:7-8` 写：「Used by the per-slot **cross-day** AR(p): phi holds the **same slot's residuals on the previous p days**.」
- 实际调用点是 `run_predictor_suite.m:133` 与 `:168`，传进去的 `hist` 是**紧邻的日内残差**，由 `run_predictor_suite.m:136` 与 `:171` 的 `hist = [r; hist(1:end-1)]` 维护。
- `README.md:130` 与 `README.md:220` 都明说跨天回归量「added no skill and was removed」。`Template_AR_predictor\init_template_ar.m:16-19` 也写同样的话。
- 结论：这句注释描述的是已退休的设计，与在役用法矛盾。

### 4.7 Theta-y tracker 的模型在 deck 里被描述错了

- `Weekly\EMPC\2026-10-08\deck\build_update_deck.py:329`：`("Theta-y tracker", "theta_y", "template plus the tracked level state")`。它说 theta-y 是「模板加被跟踪的水平状态」。
- 真实模型是 `ŷ(t+h|t) = θ(s+h)·y(s+h−288)`（`Predicitor\ThetaY_Tracker\init_theta_tracker.m:4`、`predict_theta_tracker.m:4`），**与模板无关**。template 是另一个独立模型（`names(2)`）。
- `README.md:99` 给的公式是对的，所以这是 deck 生成脚本单方面的错误。

### 4.8 README 的目录与文件名已过期

| README 说 | 实测 |
|---|---|
| `README.md:280`：「`run_predictor_benchmark.m` — the single entry point」 | 在役入口是 `Predicitor\run_predictor_suite.m`。旧基准已改名 `Predicitor\archive\run_predictor_benchmark_v1.m`（`TODO.md:69`）。 |
| `README.md:283-284`：把 `init_template_ar.m` / `update_template_ar.m` / `predict_template_ar.m` 列在 `Shared/` 下，称「core building blocks shared by all predictors」 | 三个文件在 `Predicitor\Template_AR_predictor\`，不在 `Shared\`。而且 `run_predictor_suite.m` **完全没有调用它们**：模板与残差 AR 在 `:105,125-140,162-175,189-196` 内联重写了。`Shared\` 里真实存在的是 `get_slot_index.m`、`target_slots.m`、`rls_scalar_step.m`、`rls_vector_step.m`、`predict_blend.m`、`update_blend_weights.m`。 |
| `README.md:290`、`README.md:292`：`Blend_TemplateAR/`、`Blend_YT_AR/` 列在 `Predicitor/` 下 | 两者都在 `Predicitor\archive\` 下，且 `archive\README.md:11-12` 说它们是已退休的 Blend A/B。 |
| `README.md:296`、`README.md:300`：`AR_RLS_predictor/`、`Testing_Filter/` 列在 `Predicitor/` 下 | 两者都在 `Predicitor\archive\` 下。 |
| `README.md:246-248`：`Decision/`、`MPC/`、`Online_Data_Capture_Script/` 三个目录标 "empty — to be populated" | `Decision\decision_mpc.m` 是 69 行可运行 MILP；`MPC\` 有 5 个版本子目录；`Online_Data_Capture_Script\` 有 5 个 `.py` 加 `.bat` 与 `requirements.txt`。 |
| `README.md:249-252` 的目录树 | 漏了 `Shared/`、`PriceClamp/`、`Template_AR_predictor/`、`ThetaY_Tracker/`、`Anchor_AR_predictor/`、`archive/`，也没写后来新增的 AEMO 数据集。 |
| `README.md:20`：「Model the electricity price forecast error with parameterised models such as AR and ARMA」 | ARMA 在整个仓库里没有实现，**未能确认**在别处是否存在。 |
| `README.md:57-73` 的 Changelog | 仍是占位模板（`### [YYYY-MM-DD] — Predicitor: AR(4) + RLS + daily-template version` 加 "Placeholder summary"），没有真实条目。 |

### 4.9 归档 README 里的悬空引用

- `Predicitor\archive\README.md:11`：「见 `../docs/` 或 HANDOVER 的 T+ARX 章节」。
- `Predicitor\` 下**没有 `docs\` 目录**（只有 `Anchor_AR_predictor\`、`archive\`、`Kalman_predictor\`、`PriceClamp\`、`Shared\`、`Template_AR_predictor\`、`ThetaY_Tracker\` 与 `run_predictor_suite.m`）。这是悬空引用。

### 4.10 被当作「完整控制台输出」的文件是空的

- `Weekly\EMPC\2026-09-23\MIGRATION.md:81` 写 `benchmark_console.txt  六模型基准完整控制台输出`；`Weekly\EMPC\2026-09-23\HANDOVER.md`（历史版本 §2.2）也把它列为产出。
- 实测该文件 **0 字节**。`TODO.md:85-87`（A3-5）已经记了这条待办，仍未处理。
- 同样的问题在 2026-10-08 侧更严重：`Weekly\EMPC\2026-10-08\predictor\suite_console.txt` 只有 6 行 `feature('HotLinks',0);cd(...)`。`PPT_NUMBERS.md:314` 自己承认了这一点：「`suite_console.txt` 只含 6 行 `feature('HotLinks',0);cd(...)`，没有 suite 的实际输出」，并把 4 组数字的来源栏标成「用户提供」。也就是说，**当前 8 模型套件的全部结果数字在仓库里没有可复核的原始输出**。

### 4.11 HANDOVER 与 deck 的 Anchor-mix 中位数列有 4 格不一致

- `PPT_NUMBERS.md:334` 的自动对照表标出：`Anchor-mix refit` 一行「一致 = **否**」。HANDOVER 给 9.0 / 13.1 / 17.3 / 29.2 / 35.8 / 40.6 / 40.9，deck 给 9.0 / 13.0 / 17.3 / 29.0 / 35.8 / 40.6 / 41.1。差异在 0.1 到 0.2。
- `PPT_NUMBERS.md:336` 给的解释是「同一套件两次运行的重估差异」，并声明「本版一律采用用户给定的值」。其余 7 个模型逐条一致。
- 由于 4.10 里那份空的控制台输出，这两列**都无法从仓库产物复核**。

### 4.12 AEMO P5 的误差数字有三套并存，TODO 只记了两套

| 来源 | 5 min RMSE | 55 min RMSE | ACF(1) | 同号段均值 | 样本 |
|---|---|---|---|---|---|
| `Weekly\EMPC\2026-09-23\data_audit\scripts\error_summary.json:15-20` | **14.973** | **42.186** | **0.682** | **6.152** | 窗口 2026-08-25 到 09-22，n=96702，n_test=2419 |
| `Weekly\EMPC\2026-09-23\predictor\p5_vs_tar_report.txt:11,21` | **13.78** | **33.25** | — | — | 测试集 17050 行，起点 2026-09-16 14:25 到 09-21 23:55 |
| `Weekly\EMPC\2026-10-08\deck\deck_numbers.py:66-70` 的 `P5["new"]` | **15.18** | **41.97** | **0.626** | **5.83** | 窗口 2026-08-25 到 2026-10-06，平衡面板 12373 起点 / 148476 行 |
| `Weekly\EMPC\2026-10-08\deck\deck_numbers.py:137-142` 的 `DEPRECATED` | 旧值 17.7 → 权威 15.18 | 旧值 26.4 → 权威 41.97 | 旧值 0.50 → 权威 0.626 | 旧值 5.05 → 权威 5.83 | 这 4 个数在 deck 中出现 0 次 |

- `TODO.md:96-97`（A4-3）只记了前两套的冲突（它写「`ERROR_STUDY.md`（14.97→42.19、ACF 0.682、6.152）」与「汇报里的（11→17.7→26.4、ACF 0.50、同号段 5.05）」），并说「两者必须统一后再汇报」。
- 实际上 2026-10-08 的 deck 已经引入了**第三套**（15.18/41.97/0.626/5.83），并把 17.7/26.4/0.50/5.05 标为废弃。A4-3 的措辞没有跟上。**三套数字的口径差异（窗口长度、面板是否平衡）足以解释全部差异，但无法从仓库产物复核第三套**（见 4.10）。

### 4.13 `target_slots` 的「一格偏移」已确实修好（这条不是矛盾，是为了纠正可能的误判）

- `TODO.md:76-78`（A3-3）与 `handover_new_section.md:73-75` 说注释写 `u(1) = origin_slot + 1`、代码给 `origin_slot`，已修。
- 实测：`Predicitor\Shared\target_slots.m:7` 注释写 `u(1) = origin_slot + 1`；`:15` 代码 `u = mod(origin_slot - 1 + (1:horizon)', n_slots) + 1;` 展开即 `u(1) = origin_slot + 1`（含跨日回绕）。**注释与代码一致，修复成立。**
- git 佐证：提交 `44c1fde` 的版本是 `... + (1:horizon)' - 1, ...`（u(1) = origin_slot），提交 `cb09da2` 删掉了那个 `- 1`。工作树与 HEAD 无差异。
- 另外 `script` 里 `map` 与 `target_slots` 的用法都按修好的语义走，没有残留的错位调用。

### 4.14 2026-10-08 目录里的两份文档是 2026-09-23 目录的子串

- `Weekly\EMPC\2026-10-08\handover_new_section.md` 的文件内容等于 `Weekly\EMPC\2026-09-23\HANDOVER.md` 的第 1 到 137 行。
- `Weekly\EMPC\2026-10-08\todo_new_section.md` 的文件内容等于 `Weekly\EMPC\2026-09-23\TODO.md` 的第 1 到 103 行。
- 两者都是提交 `cb09da2` 一起建立的（`HANDOVER.md` 358 行、`TODO.md` 252 行、两份副本 137 与 103 行）。所以 2026-10-08 的「新章节」并没有独立于 2026-09-23 的权威副本；两份内容会各自漂移。这不是错误，但引用时要知道改哪一份才算数。

### 4.15 一处代码内部的小问题

- `Predicitor\archive\AR_RLS_predictor\run_prediction_experiment.m:222` 的 `fprintf` 格式串有 6 个转换符（`%0s %60s %8s %8s %8s %8s`）但只给了 5 个参数（`'Model', '1h', '3h', '6h', '12h', '24h'`）。MATLAB 会让格式串循环使用，所以这一行表头会少打一列，与下一行 6 列的数据表头错位。不影响数字，只影响可读性。

---

## 第五节 材料里提到、但当前 `run_predictor_suite.m` 没有使用的数据源或想法

### 5.1 仓库里已有、但套件完全没读的数据源

`run_predictor_suite.m:50` 只读 `AEMO_Data` 目录下 `PRICE_AND_DEMAND_*VIC1*.csv`（A 类月度历史），取 `.time` 与 `.price`。以下都在同一仓库里，套件一个都没碰。

| 数据源 | 规模与窗口（照抄 `_build_stats.json` / `README.md` / `_days_done.json`） | 为什么值得用 |
|---|---|---|
| `AEMO_Data\window_120d_20260201_20260601\` | 15 个 CSV，DISPATCHIS + P5MIN + PREDISPATCH，5 区域，窗口 2026-02-01 到 2026-06-01（**与套件的 120 天窗口完全重合**）。`predispatch_identity_violations: 0`，`periods_per_issue` 32 到 79，`predispatch_lead_minutes` 0.0 到 2340.0（39.0 小时）。`total_bytes` 444281629 | 这是唯一与套件测试窗口同期的官方预测集。A1-3 的 T+ARX 需要它才能在同一窗口内跑完整 120 天，而 `TODO.md:31` 说现在 `window_60d_20260811_20261009\p5min_vic1_partial\` 只有 8/25 到 9/22。 |
| `AEMO_Data\window_60d_20260811_20261009\` | PD7DAY，60 天 2026-08-11 到 10-09，每天 3 个 run（共 180 个），5 区域各 63,240 行，合计 316,200 行 34.38 MB（34375434 字节），最大 lead **183.0 小时** | 唯一能覆盖 39 到 183 小时提前量的官方产品。套件只跑到 24 小时，MPC 的 48 小时视野没有对应数据。 |
| `AEMO_Data\window_60d_20260811_20261009\` | PREDISPATCH，同 60 天窗口，每天 48 个 run，5 区域各 159,840 行，合计 799,200 行 101.69 MB（101692749 字节），最大 lead 39.0 小时，**未钳位** | 与 PD7DAY 同窗口、同时间轴，可直接逐点对比发布节奏与 horizon 的取舍。 |
| `AEMO_Data\window_60d_20260811_20261009\p5min_vic1_partial\` | DISPATCHIS + P5MIN，2026-08-25 到 09-21（`_days_done.json`，P5MIN 每天 3456 行） | P5 误差研究的配对数据。套件不读。 |
| `AEMO_Data\window_60d_20260811_20261009\p5min_vic1_partial\` | 同上并延长到 **2026-10-06**（含 2026-09-22 到 10-06 的 DISPATCHIS 与 P5MIN） | 补齐了 deck 新窗口（8/25 到 10/6）所需的后半段。 |
| `AEMO_Data\dispatch_actual.csv` | 2880 数据行（文件 2881 个 LF，320,916 字节） | 抓取链路修好后重建的真在线实际价。`AUDIT.md:169-171` 说它此前是废的，现在可用，但套件仍只用月度 CSV。 |
| `AEMO_Data\p5min_forecast.csv` | 3600 数据行（394,133 字节） | 官方 5 分钟预测的滚动 store。 |
| `AEMO_Data\predispatch_forecast.csv` | 2975 数据行（340,772 字节） | 官方 30 分钟预测的滚动 store。 |
| `AEMO_Data\capture_state.json` | 1309 行 86,872 字节 | 抓取批次的 generation 记账，可用于判断「同一区间被重跑过几次」。 |
| `AEMO_Data\PRICE_AND_DEMAND_*_VIC1.csv` 的 `TOTALDEMAND` 列 | `load_aemo_data.m:98` 会返回 `.demand` | 套件在 `run_predictor_suite.m:51` 只取 `.time` 与 `.price`，**需求列一次都没用**。`AUDIT.md:57-61` 还提醒 B 类的 `Scheduled Demand` 不等于 `REGIONSUM.TOTALDEMAND`，别混用。 |
| 五个区域的 CSV（NSW1/QLD1/SA1/TAS1） | 120 天套与 60 天套都有全五区 | 套件是 VIC1 单区。`ERROR_STUDY.md:163` 与 `TODO.md:202` 都说要扩到五个区域。 |

### 5.2 文档里提到、代码里没实现的想法

| 想法 | 出处 | 现状 |
|---|---|---|
| **T+ARX：把 AEMO P5 偏差项当外生回归量** `g_{t+h|t} = π_{t+h|t} − T(s_{t+h})` | `TODO.md:27-32`（A1-3） | 代码里没有实现。已实测的数字：第一小时 pooled RMSE 16.72 → **15.51（−7.2%）**，权重从 5min 的 0.26 涨到 45min 的 0.55；固定权重在 09-17 翻车 **−33%**，朴素在线 RLS 超配到 **16.86**。而 `build_update_deck.py:490,504,524` 的后续结论是**否定**的：把 g 当回归量只把样本外增益从 **−4.3%** 抬到 **+2.7%**，R² 从 h=1 的 0.178 掉到 h=11 的 0.012，最终「P5 stays out of the eight models」。两处结论口径不同，**未能确认**哪一个是最终裁决。 |
| **多 X：`OPERATIONAL_DEMAND_POE50`、P5MIN 的 `AVAILABLEGENERATION`** | `TODO.md:34-37`（A1-4） | 未实现。仓库里也没有这两列的数据文件。 |
| **γ 换 RLS 版**（更快的自适应） | `TODO.md:36` | 未实现。 |
| **对 `σ_h(s)` 建模，给 MPC 分布而不是点** | `TODO.md:36` | 未实现。只有 Kalman 预测器有 `pred_sd`（`kalman_predict_288.m:46`）与 95% 带，但那个模型不在套件里，且实测覆盖率 99.9%（带子过宽）。 |
| **图集跑成多窗口做稳定性检查** | `TODO.md:39-40`（A1-5） | 现在只有 2026-02-01 到 06-01 一个 120 天窗口。月度数据到 2026-08-09，还可再切 2 个窗口。 |
| **维州 2026 公共假日表，强制映射为周末类** | `TODO.md:42-43`（A1-6）、`archive\AR_RLS_predictor\get_day_class.m:11-12` 的注释 | 未实现。而且 `run_predictor_suite.m` **完全不调用 `get_day_class`**，模板是无分类的全局 per-slot 滚动均值（`run_predictor_suite.m:105,137-139`）。`get_day_class.m:11-13` 自己也说「当前归为工作日；2 月测试期无公共假日，只影响 1 月训练模板的纯净度」。 |
| **日型分类模板（工作日/周末两套）** | `archive\AR_RLS_predictor\build_daily_template.m`、`init_ewma_state.m`、`update_template_ewma.m` | 已归档。实测结论是混合的：89 天测试里周末从 A 的 84.1 降到 B 的 46.4，工作日从 149.0 涨到 327.1（`Ash_20260827\Predicitor_Long_Term_Test\Report.txt:5-7`）；24h 档 B 甚至到 1039.7。 |
| **截断 EWMA 模板**（α=0.15、ε=0.01、K=28 个类内天，权重低于 ε 彻底丢弃） | `archive\AR_RLS_predictor\init_ewma_state.m:1-25` | 已归档。7 天 RMSE **46.3**，比 28 天窗的 44.5 差（`Ash_20260820\AR_Predictor+RLS\Report.txt:36`）。 |
| **给价格先做滤波**（移动平均 / 移动中值 / RLS AR(p)） | `archive\Testing_Filter\` 三个文件 | 已归档。三种滤波的 RMSE 是 31.518 / 33.475 / 33.147 $/MWh（`Ash_20260812\AR+RLS+P_Controller...\Report.txt:25-27`）。套件直接在有噪原价上建模板与残差。 |
| **按提前量分段选模型**（≤10 min carry-forward，>10 min T+AR(4)，修正后 AEMO 作候选） | `ERROR_STUDY.md:165-166`、`TODO.md:203-204`（P2-3） | 未实现。套件是用一个模型跑完 288 档。 |
| **按提前量混合，而不是一套 per-slot 权重** | `deck_text.md:409-410`（Next steps 第 5 条） | 未实现。Anchor-mix 是「每个提前量一组独立系数」，方向已接近，但不是文档说的那种显式混合律。 |
| **把误差修正按提前量衰减到 0 的权重显式写成公式** | `ERROR_STUDY.md:88-89`、`TODO.md:205-206`（P2-4） | 未实现。实测是「在半小时附近穿过零点」，不是平缓衰减。 |
| **给 MPC 做一次成本对比**（RMSE 降了不等于省钱） | `ERROR_STUDY.md:155`、`TODO.md:207`（P2-5）、`handover_new_section.md:67-69` | 未实现。套件只出 RMSE/MAE/bias 与「赢下槽位数」，没有任何成本指标。`handover_new_section.md:67-69` 已经写出了接口形态：MPC 阶段成本是 `RRP/1000 × 46 kW × 5/60 × u_k`，对价格线性、决策二进制，所以最优解等价于挑最便宜的区间。 |
| **节假日处理** | `deck_text.md:403-404`（Next steps） | 同 A1-6。 |
| **完成谐波状态空间卡尔曼，作为长期模型的备选** | `deck_text.md:405-406`（Next steps） | 代码完整但协议不同，且 `run_kalman_prediction.m:28` 路径过期。`README.md:331` 把 Kalman 列为 Predicitor 的「initial version」。 |
| **把预测器接进 MPC 层并验证成本节省** | `deck_text.md:407-408`（Next steps）、`TODO.md:207` | 未实现。`MPC\Basic 1.2\README.md:5` 明说自己是「离线 perfect-information 验证」，`:108` 说接入点应在 `simulate_basic_mpc.m` 组装 `window.price` 之前。 |
| **用 GitHub Actions 自动跑 Python 抓取** | `deck_text.md:401-402`（Next steps）、`TODO.md:74` | 未实现。`Online_Data_Capture_Script\start_capture.bat` 是手工双击的入口。 |
| **P5 只是 AEMO 的一个产品，预调度（30 分钟粒度、48 小时视野）没进对照** | `ERROR_STUDY.md:153-154` | 现在仓库里已有预调度数据（见 5.1），但套件与误差研究都还没用它。 |
| **把预测器输出喂给 Decision** | `Decision\decision_mpc.m:14-15` 的注释「后续替换成predictor输出」 | 未实现。该文件里的价格是硬编码的 12 个数。 |
| **MPC 自带的数据副本** | `MPC\Basic 1.1.1\data\`、`Basic 1.2\data\`、`Basic 1.3\data\` 各有 `PRICE_AND_DEMAND_202602_VIC1.csv`（369,387 字节） | MPC 侧读的是自己的副本，与 `AEMO_Data` 的同名文件是两份物理拷贝。套件读 `AEMO_Data`。两份是否始终一致**未能确认**（未逐字节比对）。 |

---

## 附：本次调研未能确认的事项（汇总）

1. `handover_new_section.md:88` / `HANDOVER.md:88` 里 `T+AR4（先预测）` 那一行数字的来源。当前代码不算这个模型，且 `suite_console.txt` 没有 suite 输出。
2. `HANDOVER.md:114` / `TODO.md:17` 里 `a_h + b_h = 0.45` 这个值的来源。`deck_numbers.py` 与 `fit_anchor_mix.m` 里都找不到；`fit_anchor_mix.m:17` 说的是 6 小时处 **1.117**，`deck_numbers.py` 的 h=72 给 **1.108**。
3. `README.md:20` 提到的 ARMA 模型在仓库里的位置。未搜到实现。
4. 2026-10-08 deck 第三套 P5 数字（15.18 / 41.97 / 0.626 / 5.83）的原始产出文件。`PPT_NUMBERS.md:314` 自己承认找不到，来源栏标「用户提供」。
5. `run_predictor_suite.m` 与 `archive\run_predictor_benchmark_v1.m` 在 2026-10-08 之后的实际运行结果。仓库里没有一次非空的 suite 控制台输出。
6. `Weekly\EMPC\2026-10-08\predictor\figures\` 里的 F1-F4 是否存在过。`TODO.md:48-49` 说已出 5 张 `F1..F5`，实际目录只有 D/G/H/I/J 系列。
7. `MPC\Basic 1.x\data\PRICE_AND_DEMAND_202602_VIC1.csv` 与 `AEMO_Data\PRICE_AND_DEMAND_202602_VIC1.csv` 是否逐字节相同。未比对（两者报告的大小都是 369,387 字节，但这不足以定论）。
