# AEMO PD7DAY 7 天预调度电价(2026-08-11 至 2026-10-09,60 天)

**本目录窗口是 2026-08-11 到 2026-10-09,共 60 天,与同仓库的
`AEMO_Data/predispatch_120d_20260201_20260601`(2026-02-01 到 2026-06-01,
120 天)**窗口不同**。PD7DAY 只存在于 NEMWEB 的 CURRENT 目录,ARCHIVE 没有这个
产品,所以拿不到那 120 天。**两套窗口的交集为空,不可按同一时间轴直接对比。**

## 一、窗口差异与可对比范围(先看这一节)

| 数据集 | 窗口 | 天数 | 30 分钟预测可用最大 lead |
|---|---|---|---|
| `predispatch_120d_20260201_20260601` | 2026-02-01 至 2026-06-01 | 120 | 39.0 小时 |
| `predispatch_20260811_20261009` | 2026-08-11 至 2026-10-09 | 60 | 39.0 小时 |
| **本目录 `pd7day_20260811_20261009`** | **2026-08-11 至 2026-10-09** | **60** | **183.0 小时** |

**交集为空。** 2026-02-01 至 06-01 与 2026-08-11 至 10-09 没有任何重叠,谁也不能
当谁的子集,不能拼成一条连续时间轴。

可执行的结论:

1. **120 天窗口内,可用最大 lead 是 PREDISPATCH 的 39.0 小时**(见那套的 README)。
2. **39 到 48 小时这一段,只在 2026-08-11 到 10-09 这 60 天里有数据**(PD7DAY)。
3. 两套要对比,只能各自在**自己的窗口内**做,不能混在同一个时间轴上。

## 二、时区口径

**全部时间戳是 NEM 时间(AEST,UTC+10,全年不随夏令时偏移),文件中没有时区后缀。**
原始报表就是 NEM 时间,解析时显式关闭了 Australia/Sydney 本地时间换算
(`aemo_config.USE_AUS_LOCAL_TIME = False`)。读文件时按 UTC+10 解释,不要叠加夏令时。

## 三、数据来源

```
https://www.nemweb.com.au/Reports/CURRENT/PD7Day/
文件形如 PUBLIC_PD7DAY_YYYYMMDDHHMMSS_<id>.zip
```

每个 zip 里只有一个 CSV 成员。只用其中 `PD7DAY/PRICESOLUTION` 一张表;
`CASESOLUTION`、`MARKET_SUMMARY`、`CONSTRAINTSOLUTION`(约 29.9 万行)、
`INTERCONNECTORSOLUTION` 都不要。

**ARCHIVE 里没有 PD7Day 目录**,已列出 ARCHIVE 完整根目录确认。因此可得的范围就是
CURRENT 当时留存的范围,本次为 2026-08-11 07:08 到 2026-10-09 17:42。

## 四、行数与体积

| 区域 | 行数 | 文件大小 |
|---|---|---|
| NSW1 | 63,240 | 6.90 MB |
| QLD1 | 63,240 | 6.85 MB |
| SA1 | 63,240 | 6.84 MB |
| TAS1 | 63,240 | 6.89 MB |
| VIC1 | 63,240 | 6.90 MB |

**合计 5 份 CSV,316,200 行,34.38 MB(34,375,434 字节)。**

覆盖完整性:**180 个 run,60 天每天 3 个,无缺口**;5 个区域时间轴逐点一致。

## 五、列结构与与另三套的差异

列名对应关系:

| 本目录列 | 来自 PD7DAY 的哪个字段 |
|---|---|
| `effective_time` | `PRICESOLUTION.RUN_DATETIME`(批次键) |
| `region_id` | `PRICESOLUTION.REGIONID` |
| `target_datetime` | `PRICESOLUTION.INTERVAL_DATETIME`(区间**结束**时刻) |
| `period_id` | **本脚本补的 1..N 序号**,按 `target_datetime` 排序,不是 AEMO 原始字段 |
| `rrp` | `PRICESOLUTION.RRP`,单位 $/MWh,**未钳位** |
| `intervention` | `PRICESOLUTION.INTERVENTION` |
| `source_file` | 该 run 对应的 CURRENT zip 文件名 |

**PD7DAY 的 `PRICESOLUTION` 只有 16 列,已确认没有 `EEP`、没有 `TOTALDEMAND`、
也没有 `RUNNO`**,所以本目录这三列缺席。逐条对照:

| 列 | dispatch / p5min(120 天套) | predispatch_30min(120 天套) | **本目录 PD7DAY** |
|---|---|---|---|
| `settlement_date` | 有 | 无 | 无(本产品用 `target_datetime`) |
| `effective_time` | p5min 有 | 有 | **有** |
| `interval_datetime` | p5min 有 | 无 | 无(本产品用 `target_datetime`) |
| `target_datetime` | 无 | 有 | **有** |
| `period_id` | 无 | 有(AEMO 原始值即时间戳,序号为派生) | **有(完全为派生)** |
| `rrp` | 有 | 有 | **有** |
| `eep` | 有 | 有 | **无** |
| `total_demand` | 有 | 有 | **无** |
| `run_no` | 有 | 有 | **无** |
| `dispatch_interval` | 有 | 无 | 无 |
| `intervention` | 有 | 有 | **有** |
| `source_file` | 有 | 有 | **有** |

## 六、horizon:按 run 时刻变化,不是固定值

**每个 run 的周期数不相等**,按 lead 筛数据前请先查这张表。

| run 时刻 | 周期数 | 跨度(小时) | 收尾 | 全期 run 数 |
|---|---|---|---|---|
| 07:30 | 330 | 164.5 | 04:00 | 60 |
| 13:00 | 367 | 183.0 | 04:00 | 60 |
| 18:00 | 357 | 178.0 | 04:00 | 60 |

统计口径:180 个 run,周期数 330 到 367,跨度 164.5 到 183.0 小时;步长去重后**只有 30.0 分钟**
(共 315,300 个间隔全部为 30 分钟);每个 run 的首个目标时刻**恒等于** `effective_time`,
末个目标时刻**恒为 04:00**。

**注意:367 个周期 / 183.0 小时只是 13:00 那个 run 的值,不是通用值。**
07:30 的 run 是 330 周期 / 164.5 小时,18:00 的 run 是 357 周期 / 178.0 小时。

## 七、独立校验与交叉验证

自校验(读的是成品 CSV 本身,不是中间件)结果:

- 5 份文件,合计 316,200 行,**PROBLEMS: 0**。
- 每区域 180 个 run、63,240 行;`period_id` 在每个 run 内是连续的 1..N;
  run 内步长去重只有 30.0 分钟;首目标恒等于 `effective_time`;末目标恒为 04:00;
  无重复 `(effective_time, target_datetime)` 键;无空值;每份文件只有 1 个区域。
- 产物为 UTF-8 无 BOM、LF 行尾、逗号分隔,表头与规格一致。
- `rrp` 实测范围 −1000.00000 到 23200.00000,负价保留,**未做任何钳位**。

交叉验证(时间轴是否正确)—— 因为没有 120 天的 PD7DAY,只能拿实际价验证:

对照数据:`AEMO_Data/forecast_actual_extend_20261008/dispatch_5min.csv`
(VIC1,2026-08-25 00:05 至 2026-10-07 00:00,12,384 行)。

- PD7DAY VIC1 有 **45,322** 个目标时刻落在这段窗口内,其中 **45,322** 个在 5 分钟实际价网格上
  **精确匹配到同一个目标时刻(100.0%)**,说明目标时间轴与实际价对齐,没有错位。
- 短 lead(≤120 分钟)RMSE = **23.733**;长 lead(>1440 分钟)RMSE = **6415.162**;
  **两者之比 = 0.0037**。短 lead 明显更好,符合预期。
  (若短 lead 反而更差,就说明时间轴错位;这里没有。)
- 逐目标日均值对实际价的相关系数在 **lag 0 处最高(0.5086505700962767)**,lag ±1 天明显更低
  (0.11570379633622771 / 0.2597436415362062),lag ±2 天为负 → **不存在整天错位**。
- 短 lead 的量级也对得上:预测均值 40.23 对实际均值 38.83。

**关于长 lead 的量级(必须说明)**:全部 lead 合起来看,PD7DAY 的均值是 1808 $/MWh,
实际价均值只有 49.2,看着差 30 多倍。逐 lead 拆开就清楚了:

| lead | 行数 | 均值 | **中位数** | p90 | 最大值 | 超过 1000 的占比 |
|---|---|---|---|---|---|---|
| 0–2 h | 720 | 42.86 | 24.44 | 118.50 | 220.76 | 0.0% |
| 2–6 h | 1,440 | 40.91 | 18.69 | 120.85 | 290.84 | 0.0% |
| 6–12 h | 2,160 | 57.24 | 61.10 | 123.24 | 553.11 | 0.0% |
| 12–24 h | 4,320 | 54.07 | 15.17 | 118.50 | 23199.92 | 0.3% |
| 24–48 h | 8,640 | 940.97 | 50.94 | 372.38 | 23200.00 | 6.1% |
| 48–96 h | 17,280 | 2386.92 | 50.94 | 18185.89 | 23200.00 | 15.0% |
| 96 h 以上 | 28,680 | 1996.12 | 50.94 | 3067.78 | 23200.00 | 12.6% |

**中位数在所有 lead 上都稳定在 51 到 61 $/MWh 之间,只有均值被长 lead 的尖峰尾巴抬高。**
超过 48 小时的周期里有 12% 到 15% 落在 1000 $/MWh 以上,并顶到 23200 的天花板。
所以这不是单位错、也不是时间轴错,而是 AEMO 这份 7 天展望在长提前量上大量给出稀缺
价格。用均值比较会被这条尾巴带偏,**比较时请用中位数或按 lead 分层**。

## 八、为什么本目录只有 60 天(证据)

需求方希望 PD7DAY 覆盖 2026-02-01 到 06-01 那 120 天。查证结论是**做不到**,证据如下:

1. **ARCHIVE 没有 PD7Day 目录**,已列出 ARCHIVE 完整根目录逐个确认。
2. ARCHIVE 里覆盖那 120 天、且有长 horizon 的产品只有两个,都已全量查过:
   - `SEVENDAYOUTLOOK_FULL`:扫了周包 `PUBLIC_SEVENDAYOUTLOOK_FULL_20260201.zip` 的
     **全部 336 个成员**,**只有 1 种 `I,` 表头行**,即全报表只有一张表
     `SEVENDAYOUTLOOK/PEAK`,7 列 `REGIONID, CALENDAR_DATE, SCHEDULED_DEMAND,
     SCHEDULED_CAPACITY, NET_INTERCHANGE, SCHEDULED_RESERVE, INTERVAL_DATETIME`。
     **没有任何价格列**;296 个区间、严格 30 分钟、跨度 147.5 小时(约 6.15 天)。
     另外对 40 个成员的原始文本做 `RRP` 子串扫描,命中 0。
   - `SEVENDAYOUTLOOK_PEAK`:同样全量扫,只有 1 种 `I,` 行,表 5 列
     `REGIONID, DATATYPE, DATAVALUE, CALENDAR_DATE, PRETTYDATE`。它是键值型,
     所以把 `DATATYPE` 的**完整取值域**列了出来,只有 5 个:
     `Net Interchange`、`Scheduled Capacity`、`Scheduled Demand`、
     `Scheduled Reserve`、`Trading Interval` —— **没有一个是价格**。
3. 带区域电价的产品只有 `PREDISPATCH` 与 `PREDISPATCHIS`,而它们的 horizon 最长 39.0 小时。

**因此:在 ARCHIVE 覆盖的 120 天窗口内,不存在任何 horizon 超过 48 小时、且带区域电价
的产品。** 这不是抓取取舍,是数据源的边界。以后有人再问,看这一节即可,不必重查。

## 九、是否钳位

**未做任何钳位。** 负价、零价、极值原样保留(`rrp` 实测 −1000.00000 到 23200.00000)。
同样未做插值、未补齐缺失时刻、未截断 horizon。

## 十、拆分规则与编码

按区域拆成 5 份,不做第二层拆分,不用 gzip,保证 pandas 与 Excel 都能直接打开:

```
pd7day_30min_<REGION>.csv
```

`<REGION>` 取 `NSW1` `QLD1` `SA1` `TAS1` `VIC1`。
全部文件为 UTF-8 无 BOM、LF 行尾、逗号分隔,第一行为表头。

## 十一、已知不足

1. 窗口只有 60 天,且与那套 120 天**交集为空**,不能混在同一时间轴对比。
2. 每天只有 3 个 run(约 07:30 / 13:00 / 18:00),不是 30 分钟滚动一次;
   做逐点对比时同一目标时刻只会被预测 3 次。
3. `period_id` 是本脚本补的序号,不是 AEMO 原始字段。
4. 本产品没有 `EEP`、`TOTALDEMAND`、`RUNNO`,不能参与需要这些列的对比。
5. 长 lead 的均值被稀缺尖峰尾巴抬高,比较时请用中位数或按 lead 分层。
6. CURRENT 是滚动目录,今天的 60 天明天可能就少一天;需要更长历史只能等 ARCHIVE
   开始收这个产品,或在它出现于 CURRENT 时持续抓取。
7. 未取 Adjusted_Prices,不含事后价格修订。

## 十二、复现

中间件与脚本在 `C:\Ash\.dsh-scratch\aemo_120d\`(不在仓库内)。

```
python fetch_pd7day.py --out <store> --cache <zips> \
    --shard 0 --shards 3 --purge-zips
python build_pd7day.py --store <store> --out <本目录>
python verify_deliverables.py --out <本目录> --report <verify.json>
python crossval_pd7day.py --pd7 <本目录> \
    --actual AEMO_Data/forecast_actual_extend_20261008/dispatch_5min.csv
```

抓取限速 1.5 秒一个请求,单个归档最多重试 3 次,遇到 403/404 立即放弃。
解析复用项目自带的 `Online_Data_Capture_Script/aemo_parser.py`。
解析前会把报表文本裁剪到只剩 `PRICESOLUTION`,因为原文 98.8% 是
约 29.9 万行的 `CONSTRAINTSOLUTION`,不含价格。
