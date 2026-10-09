# AEMO 120 天区域电价与预测数据(2026-02-01 至 2026-06-01)

本目录是从 NEMWEB 公共归档重新抓取并重排的数据,窗口 2026-02-01 00:00 至
2026-06-01 00:00,共 120 天,覆盖 5 个区域,每区域一个文件,共 15 份 CSV。

## 一、时区口径

**全部时间戳是 NEM 时间(AEST,UTC+10,全年不随夏令时偏移),文件中没有时区后缀。**
NEMWEB 原始报表就是 NEM 时间;解析时显式关闭了 Australia/Sydney 本地时间换算
(`aemo_config.USE_AUS_LOCAL_TIME = False`),因为本机夏令时会让同一份数据在一年内
两次改变时基。读文件时请直接按 UTC+10 解释,不要叠加夏令时。

## 二、数据来源

三个数据集都取自 NEMWEB ARCHIVE 的日报表目录:

| 数据集 | 归档目录 | 归档文件粒度 | 报表 |
|---|---|---|---|
| 5 分钟实际价 | `Reports/ARCHIVE/DispatchIS_Reports/` | 每日一个 zip | `PUBLIC_DISPATCHIS_YYYYMMDD.zip` |
| 5 分钟预测 | `Reports/ARCHIVE/P5_Reports/` | 每日一个 zip | `PUBLIC_P5MIN_YYYYMMDD.zip` |
| 30 分钟预测 | `Reports/ARCHIVE/Predispatch_Reports/` | **每 7 天一个 zip** | `PUBLIC_PREDISPATCH_YYYYMMDD_YYYYMMDD.zip` |

30 分钟预测这一族**没有日报**,归档是 7 天区间的周包,按 2025-09-21 起每 7 天切块。
按天拼文件名会得到 404,这是抓取时踩过的坑。

## 三、行数与体积

| 数据集 | 每区域行数 | 每区域文件大小 | 5 区域合计行数 | 5 区域合计大小 |
|---|---|---|---|---|
| 5 分钟实际价 | 34,538 | 3.78 至 3.82 MB | 172,690 | 19.0 MB |
| 5 分钟预测 | 414,432 | 44.14 至 44.60 MB | 2,072,160 | 222.1 MB |
| 30 分钟预测 | 319,680 | 40.29 至 40.78 MB | 1,598,400 | 203.2 MB |

**本目录 15 份 CSV 合计 444.3 MB(444,281,629 字节)。**

### 覆盖完整性与缺口

窗口内三个数据集的时间轴逐点核对过。**PREDISPATCH 无缺口。**
5 分钟实际价与 5 分钟预测在 **2026-03-10 有一段缺口,这是 AEMO 归档本身缺报表,
不是抓取或解析丢的**。

- `PUBLIC_DISPATCHIS_20260310.zip` 里只有 **267** 个报表(正常 288 个),
  缺 2026-03-10 18:35 到 20:25 共 **21** 个 5 分钟区间。
- `PUBLIC_P5MIN_20260310.zip` 里只有 **264** 个报表,缺 2026-03-10 18:35 到 20:30
  共 **24** 个发布点。

除这一段外没有整天缺失,也没有其它散点缺失。窗口起点 2026-02-01 00:00 那个批次
因为归档按发布日归档、落在 2026-01-31 的包里,已额外补抓 2026-01-31 的
`P5MIN` 与 2026-01-25 至 01-31 的 `PREDISPATCH` 周包补齐。

各数据集实际发布点个数:

- 5 分钟实际价:每区域 34,538 个 5 分钟区间(预期 34,559,缺 21)。
- 5 分钟预测:每区域 34,536 个发布点(预期 34,560,缺 24)。
- 30 分钟预测:每区域 5,760 个发布点(预期 5,760,缺 0)。

## 四、发布点与目标时间的配对规则

NEMWEB 每条报表带两个时间戳:报表有效时刻(批次键,文件名前 12 位)与文件生成时刻
(文件名后 14 位)。两者都是 NEM 时间。本目录沿用项目现成文件的口径:

- `dispatch_120d_*.csv`:`settlement_date` 是 5 分钟结算区间的**结束**时刻。
- `p5min_120d_*.csv`:`effective_time` 是报表有效时刻,即批次键;
  `interval_datetime` 是该批 12 个 5 分钟区间的**结束**时刻。
  每个发布点恰好 12 行,`interval_datetime − effective_time` 取 0 到 55 分钟。
- `predispatch_30min_*.csv`:`effective_time` 是报表有效时刻;
  `target_datetime` 是该周期 30 分钟区间的**结束**时刻。

实测文件生成时刻比有效时刻早:P5MIN 平均 **4.2 分钟**(16,680 份报表),
PREDISPATCH 平均 **28.0 分钟**(范围 26.1 到 28.9 分钟,336 份报表)。
因此若要从**真实发布瞬间**算提前量,P5MIN 约 4 到 59 分钟,PREDISPATCH 约 28 分钟起。
本目录按需求方要求保留 `effective_time` 作为批次键,与现成文件完全一致;
生成时刻存在中间库里(`report_generated_time`),只是没有作为成品列输出。

### `target_datetime` 的算法与校验

`target_datetime` 直接取报表自身的 `PERIODID`。归档里 PREDISPATCH 的 `PERIODID`
**本身就是时间戳**,不是序号。同时输出 1 起始、零填充的序号 `period_id`,与现成
`predispatch_forecast.csv` 同构。两者的关系是:

```
target_datetime = effective_time + 30 分钟 x (period_id - 1)
```

**注意是 `period_id - 1`,不是 `period_id`。** 实测 336/336 个批次里第 1 个周期
**恰好等于** `effective_time`,若按 `effective_time + 30 x period_id` 填写,整列会
系统性晚 30 分钟。构建脚本对每一行都做了这条恒等式校验。

校验结果:恒等式违例 0 行。

## 五、30 分钟预测的实际 horizon(与 48 小时的偏差)

**需求方原以为每个发布点给出 48 小时(96 个周期)的预测。实测不成立。**

对归档全部 336 个批次逐批统计,周期数在 **32 到 79** 之间,对应 15.5 到 39.0 小时。
相对 `effective_time` 的提前量是 0 到 2340 分钟。

决定性规则是:**预测收尾对齐到有效时刻之后第一个至少能容纳 32 个半小时周期
(15.5 小时)的 NEM 04:00 边界。** 因此周期数恰好取遍 32 到 79,每个半小时槽对应
一个固定值,7 天逐槽完全一致。13:00 是断崖:12:30 的 15.5 小时刚好够 32 周期,
13:00 只剩 15.0 小时不够,于是跳到再下一个 04:00,跨度从 15.5 小时直接变成 39.0 小时。

**96 个周期(48 小时)在本期 5,760 个批次中一次都没有出现,最大是 79 个周期(39.0 小时)。**
所以:**30 分钟粒度、48 小时提前量的 AEMO 区域电价在 NEMWEB 全站不存在。**

**实际影响:用本数据做长提前量对比时,可用最大 lead 是 2340 分钟(39.0 小时),
典型约 27 小时;48 小时那个对比点上没有 AEMO 数据可比,这不是我们截断的结果。**

### 有效时刻到周期数的对照表

每个发布点的行数**不相等**,按 lead 筛数据前请先查这张表。

| 有效时刻 | 周期数 | 跨度(小时) | 收尾 |
|---|---|---|---|
| 00:00 | 57 | 28.0 | +1 天 04:00 |
| 00:30 | 56 | 27.5 | +1 天 04:00 |
| 01:00 | 55 | 27.0 | +1 天 04:00 |
| 01:30 | 54 | 26.5 | +1 天 04:00 |
| 02:00 | 53 | 26.0 | +1 天 04:00 |
| 02:30 | 52 | 25.5 | +1 天 04:00 |
| 03:00 | 51 | 25.0 | +1 天 04:00 |
| 03:30 | 50 | 24.5 | +1 天 04:00 |
| 04:00 | 49 | 24.0 | +1 天 04:00 |
| 04:30 | 48 | 23.5 | +1 天 04:00 |
| 05:00 | 47 | 23.0 | +1 天 04:00 |
| 05:30 | 46 | 22.5 | +1 天 04:00 |
| 06:00 | 45 | 22.0 | +1 天 04:00 |
| 06:30 | 44 | 21.5 | +1 天 04:00 |
| 07:00 | 43 | 21.0 | +1 天 04:00 |
| 07:30 | 42 | 20.5 | +1 天 04:00 |
| 08:00 | 41 | 20.0 | +1 天 04:00 |
| 08:30 | 40 | 19.5 | +1 天 04:00 |
| 09:00 | 39 | 19.0 | +1 天 04:00 |
| 09:30 | 38 | 18.5 | +1 天 04:00 |
| 10:00 | 37 | 18.0 | +1 天 04:00 |
| 10:30 | 36 | 17.5 | +1 天 04:00 |
| 11:00 | 35 | 17.0 | +1 天 04:00 |
| 11:30 | 34 | 16.5 | +1 天 04:00 |
| 12:00 | 33 | 16.0 | +1 天 04:00 |
| 12:30 | 32 | 15.5 | +1 天 04:00 |
| 13:00 | 79 | 39.0 | +2 天 04:00 |
| 13:30 | 78 | 38.5 | +2 天 04:00 |
| 14:00 | 77 | 38.0 | +2 天 04:00 |
| 14:30 | 76 | 37.5 | +2 天 04:00 |
| 15:00 | 75 | 37.0 | +2 天 04:00 |
| 15:30 | 74 | 36.5 | +2 天 04:00 |
| 16:00 | 73 | 36.0 | +2 天 04:00 |
| 16:30 | 72 | 35.5 | +2 天 04:00 |
| 17:00 | 71 | 35.0 | +2 天 04:00 |
| 17:30 | 70 | 34.5 | +2 天 04:00 |
| 18:00 | 69 | 34.0 | +2 天 04:00 |
| 18:30 | 68 | 33.5 | +2 天 04:00 |
| 19:00 | 67 | 33.0 | +2 天 04:00 |
| 19:30 | 66 | 32.5 | +2 天 04:00 |
| 20:00 | 65 | 32.0 | +2 天 04:00 |
| 20:30 | 64 | 31.5 | +2 天 04:00 |
| 21:00 | 63 | 31.0 | +2 天 04:00 |
| 21:30 | 62 | 30.5 | +2 天 04:00 |
| 22:00 | 61 | 30.0 | +2 天 04:00 |
| 22:30 | 60 | 29.5 | +2 天 04:00 |
| 23:00 | 59 | 29.0 | +2 天 04:00 |
| 23:30 | 58 | 28.5 | +2 天 04:00 |

统计口径:窗口内 5,760 个批次,120 天,每个半小时槽全期一致。
周期数范围 32 到 79,跨度 15.5 到 39.0 小时;达到 96 周期的批次 0 个,
达到或超过 90 周期的 0 个。

### 查证过程与证据

1. `PREDISPATCHFCST` 全文只有两张表(`PREDISPATCH/FCAS_REQ_CONSTRAINT` 48,906 行、
   `PREDISPATCH/FCAS_REQ_RUN` 1 行),**没有区域价格表**,不能当价格源。它的 FCAS 表
   `INTERVAL_DATETIME` 去重后是 **66 个**、区间严格 30 分钟、同样在 04:00 收尾,
   说明整个 predispatch 解算的所有表都在那个时点结束,报表里没有藏着更长的解。
   它那个 `RRP` 列是按 FCAS 品种逐约束的辅助服务价,不是区域能量价。
2. 归档周包 `PUBLIC_PREDISPATCH_20260201_20260207.zip` 内是 **336 个成员**,每个成员
   一份**单 run** 报表(抽查 0/168/335 号,`distinct PREDISPATCHSEQNO` 均为 1、
   `RUNNO` 均为 1、5 个区域)。探测库 336 个 `effective_time`,相邻间隔严格 30 分钟
   共 335 次,**一个都没漏**。
3. `CASESOLUTION` 的 20 列逐列打印过,没有任何声明 horizon、周期总数或结束时刻的
   字段,唯一权威是 `PERIODID` 跨度。
4. ARCHIVE 下 15 个预调度相关目录全部探过,**只有 `PREDISPATCH` 与 `PREDISPATCHIS`
   带区域 `RRP`**。`SEVENDAYOUTLOOK_FULL` 确实有 296 个区间(约 7 天)的 30 分钟数据,
   但列是 `REGIONID, CALENDAR_DATE, SCHEDULED_DEMAND, SCHEDULED_CAPACITY,
   NET_INTERCHANGE, SCHEDULED_RESERVE, INTERVAL_DATETIME`,**只有需求与备用、没有价格**;
   `PDPASA/REGIONSOLUTION` 45 列无 `RRP`,且收尾规则与 PREDISPATCH 逐槽相同。

### 怎么自己算 lead

CSV 里保留了 `period_id` 与 `target_datetime`,于是

```
lead_minutes = (target_datetime - effective_time) 换算成分钟
             = 30 x (period_id - 1)
```
两种算法结果完全一致,构建时已逐行校验。

## 六、价格是真值还是预测值

- `dispatch_120d_*.csv` 与 `p5min_120d_*.csv` 里的 `rrp` 是**市场出清的原始 RRP**,
  全精度,单位为 $/MWh。`dispatch` 那份是真实发生的结算价,`p5min` 那份是当时
  发布的 5 分钟预测价。
- `predispatch_30min_*.csv` 里的 `rrp` 是**发布当时的 30 分钟预测价**,不是真值。
  同一个目标时刻会被多个发布点反复预测,`effective_time` 不同即不同次预测。

## 七、是否钳位

**未做任何钳位。** 负价、零价、极值原样保留。实测各区域 `rrp` 的最小值与最大值见
`_verify_report.json` 的 `dispatch_rrp` 与 `predispatch_rrp`。
同样未做任何插值、未补齐缺失时刻、未截断 horizon。

## 八、拆分规则

按「数据集 x 区域」拆成 15 份 CSV,每份一个区域,不做第二层拆分,不用 gzip,
保证 pandas 与 Excel 都能直接打开。文件名单一含义:

```
dispatch_120d_<REGION>.csv            5 分钟实际价
p5min_120d_<REGION>.csv               5 分钟预测
predispatch_30min_120d_<REGION>.csv   30 分钟预测
```

`<REGION>` 取 `NSW1` `QLD1` `SA1` `TAS1` `VIC1`。
全部文件为 UTF-8 无 BOM、LF 行尾、逗号分隔,第一行为表头。

## 九、列结构

- `dispatch_120d_<REGION>.csv`
  `settlement_date, region_id, rrp, eep, total_demand, run_no, dispatch_interval, intervention, source_file`
- `p5min_120d_<REGION>.csv`
  `effective_time, region_id, interval_datetime, rrp, total_demand, intervention, source_file`
- `predispatch_30min_120d_<REGION>.csv`
  `effective_time, region_id, target_datetime, period_id, rrp, eep, total_demand, run_no, intervention, source_file`

前两份的列与项目现成文件 `AEMO_Data/dispatch_actual.csv`、
`AEMO_Data/p5min_forecast.csv` 完全一致;第三份在现成
`AEMO_Data/predispatch_forecast.csv` 的基础上**新增 `target_datetime`**,免去二次加工。

## 十、已知不足

1. 30 分钟预测没有 48 小时,最大 39.0 小时,原因见第五节,不是本次截断造成的。
2. horizon 长度随发布时刻变化(32 到 79 个周期),各发布点的行数不相等,
   按发布点分组时不要假定固定长度。
3. 窗口按**发布时刻**过滤,因此窗口末尾几个发布点的目标时刻会落到 2026-06-01 之后。
   这是为了保住完整 horizon,没有截断。
4. `period_id` 是针对每个 `(effective_time, region_id)` 重新编号的 1..N 序号,
   不是 AEMO 的原始 PERIODID 字面值。原始值可以从
   `target_datetime - effective_time` 反推。
5. 归档数据是 AEMO 发布后的静态快照,不含事后价格修订(price revision)。
   若需要修订后的最终价,要用 Adjusted_Prices 报表另行比对。
6. 本目录 15 份 CSV 合计 444.3 MB,如果以后只用于程序读取,换成发布附件或
   列式格式会更省仓库体积。

## 十一、复现

中间件与脚本在 `C:\Ash\.dsh-scratch\aemo_120d\`(不在仓库内)。

```
python fetch_all.py --start 20260201 --end 20260601 \
    --regions NSW1,QLD1,SA1,TAS1,VIC1 \
    --out <store> --products DISPATCHIS,P5MIN,PREDISPATCH \
    --shard 0 --shards 6
python merge_stores.py --store <store>
python slot_table.py   --store <store> --out <slot_table.json>
python build_final.py  --store <store> --out <本目录>
python verify_deliverables.py --out <本目录> --report <verify.json>
python gap_analysis.py --out <本目录> --report <gaps.json>
python make_readme.py --build <build.json> --verify <verify.json> \
    --slots <slot_table.json> --gaps <gaps.json> --out <本目录>/README.md
```

抓取限速 2 秒一个请求,单个归档最多重试 3 次,遇到 403/404 立即放弃。
解析复用项目自带的 `Online_Data_Capture_Script/aemo_parser.py`,列名与时间语义
与在线抓取工具完全一致。
