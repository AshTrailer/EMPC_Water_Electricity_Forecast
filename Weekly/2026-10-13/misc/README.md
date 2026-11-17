# 电价预测器数据调研(2026-10-13)

本次调研的落点。**主报告已按你的要求移入项目:**
`C:\Ash\Projects\EMPC_Water_Electricity_Forecast\AEMO_Data\REPORT_预测器数据与长期优化_20261013.md`

## 主报告

1210 行,九节,含两轮文献、全库扫描、T 的量化实测。

| 节 | 内容 |
|---|---|
| 0 | 结论摘要,十条 |
| 1 | 48 小时数据到底有没有;120 天 5760 个 run 的实测;官方定义;面板文案的来源;「5 分钟与 30 分钟分别指什么」 |
| 2 | 同一份 pre-dispatch 文件里带着的 127 列基本面,以及抓取成本 |
| 3 | T 的量化:误差正交分解、条件化模板公式、实测结果、负面结果、滚动起点的水平 nowcast |
| 4 | NEMWEB 全库扫描,103 个目录,`PREDISPATCH|PRICESENSITIVITIES` 的 43 个情景 |
| 5 | 金融量化与电价预测文献,16 篇,链接逐条验活,含第二轮补漏的四个源与三条自我纠正 |
| 6 | 代码与文档现状盘点,含 online script 解析器的实测 |
| 7 | 行动清单,分三梯队加一节「不要做」 |
| 8 | 待确认项 |
| 附录 A | 复现脚本清单 |

## 本次新增到 EMPC 项目的文件

除主报告外,新建了这些。**既有文件一件都没有改动。**

| 路径 | 内容 |
|---|---|
| `Predicitor\Level_Offset_predictor\` | init / update / predict,模板加昨日日均水平项 |
| `Predicitor\Multi_Window_predictor\` | init / update / predict,7/28/56/112 天多窗口模板集成 |
| `Predicitor\run_level_multiwindow_test.m` | 120 天对照测试,7 个模型同一张 288x288 误差图集 |
| `AEMO_Data\PRICE_AND_DEMAND_202509..202512_VIC1.csv` | 补 4 个月历史价,暖机从 31 天拉到 153 天。多窗口要有完整窗口才有意义 |
| `AEMO_Data\level_multiwindow_figs\` | 测试输出的图与误差图集 |

## 本次实测的核心数字

| 项 | 数字 |
|---|---|
| pre-dispatch 前瞻跨度 | 15.5 至 39.0 小时,5760 个 run 无一到 48 小时,终点全在 NEM 04:00 |
| 面板导出的预测段 | 52 个 30 分钟点,26 小时 |
| 24 小时跨度 RMSE,T | 43.85 $/MWh |
| 条件化 T 后的 RMSE | 36.57 $/MWh,降 16.6% |
| 日度胜率 | 99 天里 72 天赢 |
| 水平分量占比 | 57.7% |
| 形状分量占比 | 42.3% |
| 模板水平误差 | 常数 34.60,不随观测增多而改善 |
| 当日已观测 75% 时的水平误差 | 7.62 |
| 叠加屋顶光伏的增量收益 | 0.2% |
| 按星期几分型的模板 | 比 T 差 3.4% |
| 电价敏感性情景数 | 每区域每周期 43 个,VIC1 专属为情景 29 至 43 |
| 解析器实测 | 260 行,5 区域乘 52 周期,`rrp` 与 `total_demand` 各 260/260 非空 |

## 目录

| 目录 | 内容 | 体积 |
|---|---|---|
| `lit\` | 文献调研。`_pdf\` 原文,`_txt\` 抽出的正文,`_pdf_manifest.json` 验活的 URL,`GAPS.md` 第二轮补漏 | 17.3 MB |
| `dashboard\` | AEMO 数据面板接口核查。`FINDINGS.md` 是结论,`raw\` 原始件,`js\` 脚本 | 16.5 MB |
| `nemweb\` | NEMWEB 结构与字段核查。脚本与日志在根,抓下来的 zip 样本已清 | 1.1 MB |
| `rtpv\` | VIC1 屋顶光伏预测,96957 行 | 6.0 MB |
| `sweep\` | 全库 103 个目录的扫描结果 `sweep.json` 与日志 | 0.2 MB |
| `reports\` | EMPC 项目文档与历史代码通读,`FINDINGS.md` | 0.1 MB |

## 复现脚本

都在本目录根下。

| 文件 | 作用 |
|---|---|
| `horizon_audit_120d.mjs` | 逐 run 统计 120 天 pre-dispatch 的前瞻跨度 |
| `decompose.py` | 水平方差与形状均方误差的正交分解 |
| `conditional_T.py` | 条件化模板的完整对照实验。支持原始价与钳位价、00:00 与 23:30 两个信息集 |
| `conditional_T_pv.py` | 加入屋顶光伏预测的叠加实验 |
| `rolling_level.py` | 滚动起点下的水平可预测性实测 |
| `sweep_all.mjs` | 全库扫描 |
| `fetch_rtpv.mjs` | 从归档抓屋顶光伏周包并解嵌套 zip |
| `nemweb_peek.mjs` | 读 NEMWEB zip,列出表名、列名、行数 |
| `nemweb_extract.mjs` | 按表名与区域抽取数据 |
| `nemweb_scan.mjs` `nemweb_dir.mjs` `nemweb_list.mjs` | 目录枚举与体积统计 |
| `sens_dump.mjs` | 打印 PREDISPATCH 价格敏感度的 43 个情景 |
| `pdftext.mjs` | 从 PDF 抽文本 |
| `verify_online_script.py` | 用项目自己的 `aemo_parser` 解析真实 PREDISPATCHIS,只读 |

## EMPC 仓库状态

本次调研**没有改动 EMPC 项目下任何既有文件**。

核对结果:Git 里已跟踪的文件无一处于删除状态。
另外本次修复了一处早先误删:`AEMO_Data` 下 5 个已跟踪文件
(`NEMPRICEANDDEMAND_NSW1_202609101245.csv`、`NEMPRICEANDDEMAND_QLD1_202609040310.csv`
与 3 个 `PUBLIC_*.CSV`)曾被当成缓存删掉,现已用 `git checkout --` 恢复,内容与 HEAD 一致。

未跟踪的新文件 `AEMO_Data/NEMPRICEANDDEMAND_VIC1_202610130200.csv` 是你自己下载的那一份,未动。

## 数据来源与前提

- 时间戳一律 NEM 时间(AEST,UTC+10,全年不随夏令时偏移)。
- pre-dispatch 归档是 7 天一个 125 至 135 MB 的 zip 包,不是日报,按天拼文件名会 404。
- `PredispatchIS_Reports` 与 `Predispatch_Reports` 是同一份数据的两种命名,不要同时抓。
- ROOFTOP_PV 的周包是嵌套 zip,外层 zip 里每个文件还是 zip。
