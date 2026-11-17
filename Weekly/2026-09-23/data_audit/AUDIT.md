# 数据审计 —— AEMO 电价数据三源比对与抓取链路体检

> 2026-09-23 周 ｜ 工作区 `C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project`
> 所有数字都可由 `scripts/` 下的脚本重放得到。**本文件不含待办**（待办去 `../TODO.md`）。

---

## 0. 一句话结论

**月度 VIC1 文件与 AEMO 实时报表价格本来就没有分歧** —— 逐点差异只有 2 位小数
的发布精度（平均 0.0005~0.0019 $/MWh，最大 0.005 $/MWh）。

真正的分歧来自**我们自己的抓取链路**：
1. 解析器不去引号 ⇒ `dispatch_actual.csv` 的 `settlement_date` 全空 ⇒ 去重键塌陷
   ⇒ **这个 store 永远只剩 5 行**（每区域 1 行），从建库那天起就一直在丢数据；
2. 抓取脚本默认把 NEM 时间改写成悉尼本地时间 ⇒ 夏令时期间与训练数据差 **12 个槽位**。

---

## 1. 数据清点：AEMO_Data 里到底有几种东西

四类，来源、粒度、时间跨度完全不同，此前混在一个目录里：

| 类 | 文件 | 生成方式 | 粒度 | 覆盖 | 关键列 |
|---|---|---|---|---|---|
| **A 月度历史** | `PRICE_AND_DEMAND_YYYYMM_VIC1.csv` × 8 | AEMO 数据看板 → Historical (aggregated) price & demand，按月下载 | 5 min，区间**结束**时刻 | 2026-01-01 00:05 ~ 2026-08-09 00:00（63,360 点） | `REGION, SETTLEMENTDATE, TOTALDEMAND, RRP, PERIODTYPE`（`TRADE`） |
| **B 看板 dispatch 导出** | `NEMPRICEANDDEMAND_{REGION}_{stamp}.csv` × 2 | 数据看板 → Price and demand → Dispatch → 下载 | 5 min（ACTUAL）+ 30 min（FORECAST） | 约 30~48 h 滚动窗 | `Settlement Date, Spot Price ($/MWh), Scheduled Demand/Generation, Semi Scheduled Generation, Net Import, Type` |
| **C 脚本抓取** | `zip_cache/{DISPATCHIS,P5MIN,PREDISPATCHIS}/` + `dispatch_actual.csv` / `p5min_forecast.csv` / `predispatch_forecast.csv` + `capture_state.json` | `Online_Data_Capture_Script` 轮询 NEMWEB CURRENT 列表 | 5 min / 30 min | 缓存 2026-09-13 11:35 ~ 2026-09-15 11:30 | 自定 schema（见 §2） |
| **D 一次性原始件** | 根目录 3 个 `PUBLIC_*.CSV`（DISPATCHIS / P5MIN / PREDISPATCH_LEGACY） | 早期手工下载留档 | 原始报表 | 2026-09-04 单点 | NEMWEB C/I/D 记录 |

缓存规模：DISPATCHIS **576** 个 zip / 11.6 MB，P5MIN **60** 个 / 12.5 MB，
PREDISPATCHIS **10** 个 / 6.3 MB。

---

## 2. 三源口径对照

### 2.1 时间戳与区间
- 全部是 **5 分钟、区间结束（interval-ending）** 时刻；`00:05` 是当天第一个区间，
  `24:00` 是最后一个。
- A 的格式 `2026/03/01 00:05:00`；B 的格式 `DD/MM/YYYY HH:MM`（**没有秒**）；
  C 由抓取脚本写成 `YYYY-MM-DD HH:MM:SS`。
- **A 与 C 的「同一时刻」在夏令时期间不是同一个物理时刻** —— 见 §3.5。

### 2.2 电价列
| 源 | 列名 | 精度 | 含义 |
|---|---|---|---|
| A | `RRP` | 2 位小数 | 最终结算用的 5 分钟区域参考价 |
| B | `Spot Price ($/MWh)` | 5~7 位有效数字 | 原始 dispatch RRP |
| C | `rrp` | 全精度 | 直接取自 `DISPATCH/PRICE` 表的 `RRP` |

**实测**：A 就是 C（与 NEMWEB 归档）**四舍五入到 2 位小数**。7 月三天逐点比对
平均差 0.0005 / 0.0019 / 0.0007 $/MWh，最大 0.0049 —— 全部落在 2 位小数的舍入界内。
168 / 287 与 178 / 287 的样本值本来就只有 2 位小数，因此逐字节相同。

### 2.3 需求列
- A `TOTALDEMAND`（MW）≡ C `total_demand`（取自 `DISPATCH/REGIONSUM`），
  对齐后 **平均差 0.0000、相关系数 1.000000**。
- B 的 `Scheduled Demand (MW)` **不等于** `REGIONSUM.TOTALDEMAND`：
  NSW1 平均差 125.2 MW、QLD1 平均差 425.0 MW。它是「计划需求」口径，不是运行需求。
  **接预测器时不要混用这两列。**

### 2.4 RUNNO
- 归档里每天都存在多个 report 覆盖同一区间（每小时 12 个 report，每个都带当区间及后续的
  `DISPATCH/PRICE` 行）。取 **RUNNO 最大**者即最后一次成功求解。
- **6 个抽样日的 RUNNO 恒为 1**，没有发生重跑，因此「取最大 RUNNO」在样本上退化为无操作。
  月度文件是否等于「最终 RUNNO」这一条**本样本无法证伪**（见 TODO P1-4）。

### 2.5 单位
三源都是 `$/MWh`，无换算差异。价格可以为负（实测最低 −969.97 $/MWh），
上限受市场价帽约束（实测最高 19,069.69 $/MWh，出现在 1 月训练期内）。

---

## 3. 抓取链路的五个实测缺陷

### D1 `_split_record` 不去引号 —— **数据毁灭级**
`aemo_parser.py` 原来用 `line.split(",")` 切记录。NEMWEB 的 D 记录把**所有时间字段用
双引号包起来**：

```
D,DISPATCH,PRICE,5,"2026/09/04 03:55:00",1,NSW1,20260903287,...
```

`strip()` 不剥引号 ⇒ `parse_nem_datetime('"2026/09/04 03:55:00"')` 返回 `None`
⇒ `format_output_time(None)` 返回 `""`。

后果分三处：
- `dispatch_actual.csv` 的 `settlement_date` **全部为空**。该 store 的去重键是
  `(settlement_date, region_id)`，键塌陷后**每来一个新观测就把上一分钟的挤掉**，
  于是文件永远只有 **5 行**（5 个区域各 1 行）。
- `p5min_forecast.csv` 的 `interval_datetime` **3600/3600 全空**。
- `predispatch_forecast.csv` 的 `period_id` **1925/1925 全空**。

复现证据：`scripts/parser_replay.txt`（修复前）第 1、2、3 节。

### D2 `%Y%m%d%H%M%S` 没有宽度闸 —— 序号码被吃成时间
`PREDISPATCHSEQNO` 是 `yyyymmddhh` 的 **10 位序号**（实测 `2026091515`），
而 `parse_nem_datetime` 的回退链里有 `%Y%m%d%H%M%S`。Python 的 strptime 字段正则
允许 1 位数的月/日/时，于是 `2026091515` 被以 **4+2+1+1+1+1** 的回溯方式吃下：

```
parse_nem_datetime('2026091515') -> datetime(2026, 9, 1, 5, 1, 5)
```

store 里因此写着 `predispatch_seqno = '2026-09-01 05:01:05'` 这种**根本不存在的时间**，
而且每半小时的批次恰好 +1 秒（05:00:06, 05:00:07, …, 05:01:05）。

### D3 表选择选中了没有需求列的那张表
新版 PREDISPATCHIS 把区域表拆成两张：
- `PREDISPATCH/REGION_PRICES` —— 有 `RRP`、`EEP`，**没有** `TOTALDEMAND`
- `PREDISPATCH/REGION_SOLUTION` —— 有 `TOTALDEMAND`，**没有** `RRP`

旧代码要求的列集合 `{REGIONID, PERIODID, RRP}` 只能命中 `REGION_PRICES`，
于是 `total_demand` **1925/1925 全空**。

### D4 `PERIODID` 在新格式里不是时间戳
新版 `PERIODID` 是 30 分钟时段序号（`01`、`02`…），旧版才是时间戳。
原代码一律走 `_format_column`（datetime 格式化）⇒ 全部变成 `""`。

### D5 `USE_AUS_LOCAL_TIME = True` —— **最隐蔽的一个**
`aemo_config.py:73-76` 说：NEMWEB 时间戳是 NEM 标准时间（AEST/UTC+10，不随夏令时平移），
若为 `True` 则**转换成 Australia/Sydney 本地时间**。出厂默认就是 `True`。

「悉尼本地时间 − NEM 时间」在**夏令时期间 = +1 h**，其余时间 = 0 h。
⇒ **同一个 store 一年里会在两个时基之间跳一次**，而预测器的训练数据（A 类月度文件）
与 AEMO 归档**始终是 NEM 时间**。

实测（`scripts/timebase_verdict.txt`）：

| 日期 | 悉尼时区 | 开转换时最佳对齐 | 关转换时最佳对齐 |
|---|---|---|---|
| 2026-01-15 | AEDT | **+60 min** | 0 min |
| 2026-02-15 | AEDT | **+60 min** | 0 min |
| 2026-03-15 | AEDT | **+60 min** | 0 min |
| 2026-04-04 | AEDT（DST 结束前一天） | **+60 min** | 0 min |
| 2026-04-06 | AEST | 0 min | 0 min |
| 2026-05-15 / 07-15 / 08-05 | AEST | 0 min | 0 min |

关掉转换后**八个月份全部在 0 对齐**，平均差 0.0007~0.0019 $/MWh = 纯舍入。
⇒ 偏移**完全由这一行配置造成**，AEMO 两侧数据本身同源同基。

> 排查过程留痕：第一版比对脚本直接复用了项目解析器，于是把解析器自己造成的 1 小时
> 偏移读成了「AEMO 月度文件有时基问题」。是靠**交叉验证**翻案的 ——
> ① 归档 4 月 5 日（DST 切换日）的日包成员名是干净的 5 分钟阶梯、无重复/缺失小时，
> 证明归档是固定偏移时基；② 把 `USE_AUS_LOCAL_TIME` 关掉后八个月份全部归零，
> 证明偏移是本地注入的。**读自己产出的数据时要先怀疑自己的读取层。**

---

## 4. 看板导出的 dispatch 文件（B 类）到底是什么

`NEMPRICEANDDEMAND_NSW1_202609101245.csv`：367 行，
`Type = {ACTUAL: 288, FORECAST: 79}`，步长 `{5 min: 287, 30 min: 78, 15 min: 1}`。

- **ACTUAL 段（288 行）与 NEMWEB 归档逐点完全相同**：交集 135 行（受归档只覆盖单日限制），
  完全相等 **135/135 = 100%**，平均差 0.000000，最大差 0.000000。
- **FORECAST 段是 30 分钟步长的预调度预测**，5 分钟段与 30 分钟段接在一起
  （衔接处出现一个 15 分钟步长）。

⇒ B 类导出 = **DISPATCHIS 实际值 + PREDISPATCHIS 预测值**的拼接，是看板自己做的合并。
对预测器而言它的价值在于：**它是「同一时间轴上实际与官方预测并排」的现成样例**，
正是教授要的误差矩阵的雏形，但只有 ~30 小时、且要手工点下载，不能当数据源。

---

## 5. 对预测器的影响

1. **`dispatch_actual.csv` 目前是废的**（5 行）。所有依赖「在线实际价」的东西
   （AEMO 误差配对、在线 RLS 更新、MPC 的实时期望）都拿不到数据。
   这是 D1 的直接后果，与 AEMO 无关。
2. **时基不一致是定时炸弹**。`run_predictor_benchmark.m` 用 A 类月度文件
   （NEM 时间）训练，若将来把 C 类抓取数据（默认悉尼本地时间）接进去，
   夏令时期间会整体错 **12 个槽位**；`get_slot_index()` 会把同一个物理时刻
   映射到两个不同的 slot，日周期模板 `T(s)` 直接错位。
3. **价格精度不是问题**。A 类 2 位小数 vs 归档全精度，对 RMSE 的影响在
   0.002 $/MWh 量级，而当前最好模型的 5 min RMSE 是 **15.8 $/MWh** —— 差 4 个数量级，
   可以忽略。**这一点直接回答了教授「月度 RRP 与实时价格为什么不一致」：
   不一致的是我们自己造的，不是价格本身。**

---

## 6. 本周预测器基线数字（重跑 `run_predictor_benchmark.m`）

协议：Jan 1–30 在线热启（8,640 点）→ Jan 31 起每个 5 分钟观测重发 288 步预测
（4,320 个起点）→ 评分 2026-02-01~02-14（4,032 点），价格钳位到滚动 30 日 Q1/Q99。

| 模型 | RMSE 2 周 | MAE | Bias | 5 min | 1 h | 3 h | 6 h | 24 h |
|---|---|---|---|---|---|---|---|---|
| Persistence（昨日同时刻） | 51.2 | 38.8 | −5.2 | 51.2 | 51.2 | 51.2 | 51.2 | 51.2 |
| Rolling template | **46.4** | **36.6** | +9.6 | 46.4 | 46.4 | 46.4 | 46.4 | 46.4 |
| Theta-y tracker | 49.7 | 37.3 | +13.6 | 49.7 | 49.7 | 49.7 | 49.7 | 49.7 |
| **Template + AR(4)** | 51.9 | 37.5 | +1.0 | **15.8** | **28.0** | **39.4** | 50.3 | 58.5 |
| Blend A | 55.6 | 41.3 | +23.1 | 38.0 | 43.9 | 49.1 | 53.8 | 62.6 |
| Blend B | 61.4 | 45.5 | +29.3 | 43.6 | 49.5 | 55.5 | 59.9 | 68.6 |

钳位后信号标准差 51.3 $/MWh —— **RMSE 接近这个值就等于没有预测能力**。
Persistence / Template / Theta-y 的 RMSE 对提前量是平的（它们只携带日周期信号），
只有 T+AR(4) 随提前量变化。

- 最佳 5 min / 30 min / 1 h / 3 h：**T+AR(4)**（15.8 / 23.4 / 28.0 / 39.4）
- 最佳 6 h / 12 h / 24 h：**Rolling template**（46.4，全程不变）
- 相对 Persistence：T+AR(4) 在 5 min 上 **+69.2%**，但在 24 h 上 **−14.3%**；
  两周总 RMSE **−1.4%**（比 Persistence 还差）

图：`../predictor/figures/bench_week_aligned.png` / `bench_rmse_lead.png` /
`bench_rmse_slot.png` / `bench_rmse_matrix.png`
控制台原始输出：`../predictor/benchmark_console.txt`

### 解读
- **T+AR(4) 的 4 小时分界线是真的**：6 h 处 50.3 已越过模板的 46.4，
  残差 AR 的递归在 3~6 h 之间衰减到 0，之后纯粹是模板在扛。这与教授的判断一致
  —— **AR 只值短期那一段**。
- **两周总 RMSE 上 T+AR(4) 反而输给模板**，因为它把 288 个提前量一视同仁地平均了。
  教授明确说过「不要从 288 维结果里挑选最小误差作为总体准确率」，同理也不能反过来
  用两周平均去否定它 —— **必须按提前量分别报告**。
- **Blend A/B 全线不如其组成部分**，说明按 slot 自适应的凸组合权重没有学到东西
  （Bias 分别 +23.1 / +29.3，权重明显偏到了错误的一侧）。这条线可以先放下。

---

## 7. 因此决定的下一步

1. **先修数据再谈模型**：重跑抓取，让 `dispatch_actual.csv` 真正开始累积（TODO P1-1/P1-2）。
2. **时基拍板**（TODO TD-1）：推荐全线统一 NEM 时间。
3. **预测版本保留放长**（TODO TD-3），否则误差矩阵只有 5 小时历史，做不了。
4. **误差模型只做前 12 步**，基线是 AEMO P5 官方预测本身，评测按提前量分档。
5. RUNNO 普查（P1-4）确认「最终值」口径 —— 这是误差 `e(k,k_i)` 定义的合法性前提。

---

## 附：产物清单

```
data_audit/
  AUDIT.md                     ← 本文件
  scripts/aemo_probe.py            + aemo_probe_report.txt      文件清点与原始记录结构
  scripts/store_diagnosis.py       + store_diagnosis.txt        三个 store 的字段体检
  scripts/parser_replay.py         + parser_replay.txt          用现行解析器重放原始 zip
  scripts/compare_sources.py       + compare_report.txt         三源比对（主报告）
                                   + figures/F1..F3.png
  scripts/dst_probe.py             + dst_probe.txt              归档日包的 DST 连续性
  scripts/timebase_census.py       + timebase_census.txt        逐月时基普查（开转换）
  scripts/timebase_verdict.py      + timebase_verdict.txt       开关转换对照（判决）
  scripts/january_offset_look.py   + january_offset_look.txt    1 月偏移的原始数值对照
  scripts/archive_zip_probe.py     + archive_zip_probe.txt      归档双层 zip 结构
  scripts/network_probe.py         + network_probe_report.txt   NEMWEB 可达性与归档规模
  scripts/_mplcache/                                            matplotlib 字体缓存（可删）
```
原始归档缓存：`AEMO_Data/archive_cache/PUBLIC_DISPATCHIS_YYYYMMDD.zip` × 16（约 91 MB）
