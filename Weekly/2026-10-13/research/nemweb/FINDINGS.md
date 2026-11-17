# NEMWEB 48 小时预测数据判定

调查时间:2026-10-13 02:35 至 04:00 AEDT(NEM 时间 2026-10-13 01:35 至 03:00)
产出目录:`C:\Ash\_research_20261013\nemweb\`
抓取方式:全部 HTTPS + Node 全局 fetch(`01`–`04` 号 `.mjs` 脚本),未使用 curl.exe 或 Invoke-WebRequest
EPMC 目录:只读,未修改任何既有文件

---

## 摘要(三条最关键的数字)

1. **2026-10-12 00:00 至 2026-10-13 02:00 的 53 个 PREDISPATCHIS 文件,horizon 最大 39.0 小时、最小 15.5 小时、中位 27.0 小时;53 个文件里 horizon 超过 40 小时的 = 0 个,达到 48 小时的 = 0 个。** PREDISPATCH(不带 IS)的 53 个文件结果**逐槽完全相同**。
2. **53/53 个文件的 horizon 结束时刻全部是 NEM 04:00**,没有一个例外;horizon 周期数取遍 32 到 79。
3. **30 分钟粒度 + 州级电价的序列里,horizon 最长的是 PD7DAY 的 183.0 小时**(每天只发布 3 次);30 分钟节奏发布的 PREDISPATCH/PREDISPATCHIS 上限就是 **39.0 小时**。ROOFTOP_PV_FORECAST 虽然到 191.5 小时且是 30 分钟粒度,但**只有光伏功率,没有电价**。

**结论:AEMO 官方面板写的「Forecast price Pre-dispatch 30 min. Next 48 hours.」在 NEMWEB 的 30 分钟节奏产品上无法复现。** 30 分钟一更新、带州级电价的 PREDISPATCH/PREDISPATCHIS 实测上限是 39.0 小时,不是 48 小时。**48 小时这个数,在本次全库实测里没有出现过一次。**

---

## 一、CURRENT 根目录完整枚举

`https://www.nemweb.com.au/Reports/CURRENT/` 根页面共 104 条 href,**去重后 103 个子目录,一个不漏**(清单见 `current_dirs.json`,含每个目录的文件数与最新文件名)。

- **有数据(至少 1 个 zip):70 个**
- **无数据(0 个 zip):33 个**,其中 18 个改为只放 csv(如 `Ancillary_Services_Payments` 30 个 csv、`SRA_Results` 1356 个 csv),15 个完全为空(如 `Auction_Units_Reports`、`Bidmove_Summary`、`Causer_Pays_*`、`Market_Notice`、`Operational_Demand`、`Weekly_Bulletin`)。

**枚举深度的一处重要修正**:`ROOFTOP_PV` 在根枚举里显示 0 个 zip,但它**不是空目录**,而是里面还有 4 个子目录:

```
Reports/CURRENT/ROOFTOP_PV/ACTUAL          (1344 zip)
Reports/CURRENT/ROOFTOP_PV/ACTUAL_AREA     (1344 zip)
Reports/CURRENT/ROOFTOP_PV/FORECAST        (672 zip)
Reports/CURRENT/ROOFTOP_PV/FORECAST_AREA   (672 zip)
```

ARCHIVE 下同样是这 4 个子目录。所以任务是二层路径,`ROOFTOP_PV_FORECAST_Reports` 对应的真实路径是 `Reports/CURRENT/ROOFTOP_PV/FORECAST/`。

**任务里给的目录名有几个在 NEMWEB 上不存在**,实际对应关系:

| 任务里的名字 | NEMWEB 实际目录 | 状态 |
|---|---|---|
| `P5MIN_Reports` | `P5_Reports` | 存在 |
| `DISPATCHIS_Reports` | `DispatchIS_Reports` | 存在 |
| `STPASA_Reports` | `Short_Term_PASA_Reports` | 存在 |
| `MTPASA_Reports` | `Medium_Term_PASA_Reports` | 存在 |
| `BIDMOVE_Reports` | `Bidmove_Complete`(另有 `Bidmove_Summary` 为空) | 存在 |
| `CONSTRAINT_Reports` | `Weekly_Constraint_Reports`(1 个 zip);`CSC_CSP_ConstraintList` 为空 | 部分存在 |
| `INTERMITTENTGEN_Reports` | **不存在**;最接近的是 `Next_Day_Intermittent_Gen_Scada` | **无** |
| `ROOFTOP_PV_FORECAST_Reports` | `ROOFTOP_PV/FORECAST`(二层) | 存在 |
| `ROOFTOP_PV_ACTUAL_Reports` | `ROOFTOP_PV/ACTUAL`(二层) | 存在 |
| `PD7DAY_Reports` | `PD7Day` | 存在 |
| `PD7DAYIS_Reports` | **不存在**,没有 PD7Day 的 IS 版本 | **无** |

---

## 二、PREDISPATCHIS 逐文件 horizon 审计(53 个文件)

窗口 2026-10-12 00:00 至 2026-10-13 03:00 NEM。**实际抓到 53 个文件,effective stamp 从 202610120000 到 202610130200。**
注意:抓取时 NEM 时间是 2026-10-13 01:35,所以 **02:30 与 03:00 两个半点的文件当时尚未发布**,不是我漏抓。抓取结束再次列目录确认:`PredispatchIS_Reports` 最新 effective stamp = `202610130200`。

逐个文件从原始字节解析结果(全部 53 个文件,见 `horizon_predispatchis.json`):

| 指标 | 值 |
|---|---|
| 文件数 | 53 |
| horizon 最小 | **15.500 小时** |
| horizon 中位 | **27.000 小时** |
| horizon 最大 | **39.000 小时** |
| horizon 平均 | 27.226 小时 |
| **horizon > 40 小时的文件数** | **0** |
| **horizon ≥ 48 小时的文件数** | **0** |
| horizon 结束时刻的取值集合 | **只有 `04:00`(53/53)** |

最大 horizon 的文件:`PUBLIC_PREDISPATCHIS_202610121300_20261012123236.zip`(13:00 那个 run,39.0 小时)。

每半小时槽的 period 条数(53 个文件覆盖 48 个槽,首尾几个槽出现两次):

```
00:00 → 57 周期 / 28.0 h     12:30 → 32 周期 / 15.5 h
00:30 → 56 / 27.5            13:00 → 79 周期 / 39.0 h   ← 全场最大
01:00 → 55 / 27.0            13:30 → 78 / 38.5
…                            …
12:00 → 33 / 16.0             23:30 → 58 / 28.5
```

规律与早先在 2026-02 至 06 窗口测到的完全一致:**horizon 收尾对齐到有效时刻之后第一个至少能容纳 32 个半小时周期(15.5 小时)的 NEM 04:00 边界**,所以周期数恰好取遍 32..79。

---

## 三、PREDISPATCH(不带 IS)同样审计,以及两者的差别

`Reports/CURRENT/Predispatch_Reports/` 的 53 个文件(`PUBLIC_PREDISPATCH_<eff>_<gen>_LEGACY.zip`)审计结果:

| 指标 | PREDISPATCHIS | PREDISPATCH(legacy) |
|---|---|---|
| 文件数 | 53 | 53 |
| horizon 最小 / 中位 / 最大 | 15.5 / 27.0 / **39.0** h | 15.5 / 27.0 / **39.0** h |
| horizon > 40 h | **0** | **0** |
| horizon ≥ 48 h | **0** | **0** |
| horizon 结束时刻 | 04:00(53/53) | 04:00(53/53) |
| 48 槽 → 周期数映射 | 与上面完全相同 | 与上面完全相同 |

**两者 horizon 与周期数逐槽一致,没有任何差别。**

**差别只在表结构与字段表达方式:**

| 维度 | PREDISPATCHIS | PREDISPATCH(LEGACY) |
|---|---|---|
| 表数 | 6 | 6 |
| 区域价格表 | `REGION_PRICES`(35 列,含 RRP/EEP/RRP1..RRP8/各 FCAS RRP) | `PDREGION`(115 列,单表含 RRP 与 TOTALDEMAND) |
| 区域需求/发电表 | `REGION_SOLUTION`(127 列) | 合并进 `PDREGION` |
| 解算表 | `CASE_SOLUTION`(20 列) | `CASESOLUTION`(20 列,字段相同) |
| 联络线表 | `INTERCONNECTOR_SOLN`(23 列) | `PDINT`(16 列) |
| 约束表 | `CONSTRAINT_SOLUTION`(14 列) | `PDCONS`(8 列) |
| IS 独有 | `LOCAL_PRICE`(7 列,逐 DUID 的本地价调整) | 无 |
| legacy 独有 | 无 | `PDIREGION`(5 列)、`PDIINT`(5 列) |
| `PERIODID` 含义 | **序号** `01..NN` | **时间戳** |
| `PREDISPATCHSEQNO` | 10 位 `yyyymmddhh`(hh 是半小时序号,如 `2026101315`) | 时间戳字符串 `YYYY/MM/DD HH:MM:SS` |
| 区域数 | 5 | 5 |

字段清单见 `inventory_predispatchis.json` 与 `inventory_predispatch.json`。

---

## 四、48 小时到底有没有

**在本次实测范围内:没有。**

- 30 分钟节奏发布、带州级电价的 `PREDISPATCHIS` 与 `PREDISPATCH`:53 + 53 = **106 个文件,horizon 上限 39.0 小时,超过 40 小时的 0 个**。
- 回查已交付的 120 天窗口(2026-02-01 至 06-01)5 个区域共 **28,800 个 run**:horizon 15.5 至 39.0 小时,**超过 40 小时的 0 个,达到 48 小时的 0 个**。
- 全库范围内 30 分钟粒度、且带州级电价的,**只有 PD7Day 超过 40 小时**(164.5 至 183.0 小时),但它**每天只发布 3 次**,不是 30 分钟一更新。

所以能给出的最准确说法是:

> **30 分钟一更新的州级电价预测,AEMO 实测上限是 39.0 小时,不存在 48 小时的那一档。**
> 想要 48 小时以上、30 分钟粒度的州级电价,只能用 PD7Day(183.0 小时),但它的更新节奏是每天 3 次。

关于 AEMO 官方面板那句「Forecast Spot price (Forecast price Pre-dispatch 30 min). Next 48 hours.」:本次在 NEMWEB 上**没能找到任何能复现「48 小时」的 30 分钟节奏产品**。可能的原因是面板把「30 分钟」理解成**数据粒度**、把「48 小时」当成产品设计上界(本期实测上界是 39.0 小时),也可能面板指的是另一个产品。**这一点我拿不到直接证据,不能断言原因,只能说结论无法在 NEMWEB 数据上复现。**

---

## 五、其他报告的样本实测

每个目录抓最新的 1 份(`samples_manifest.json`、`rooftop_manifest.json`),字段清单见 `fields.json`。

| 报告 | 更新节奏 | 时间粒度 | 实测 horizon | 有电价 | 有需求 | 有光伏 | 有风电 |
|---|---|---|---|---|---|---|---|
| `PredispatchIS_Reports` | 30 分钟 | 30 分钟 | 15.5–39.0 h | **有** | 有 | 有(SS_SOLAR_*) | 有(SS_WIND_*) |
| `Predispatch_Reports` | 30 分钟 | 30 分钟 | 15.5–39.0 h | **有** | 有 | 无 | 无 |
| `PD7Day` | **每天 3 次** | 30 分钟 | **164.5–183.0 h** | **有** | 无 | 无 | 无 |
| `P5_Reports` | 5 分钟 | 5 分钟 | 0.9 h(55 分钟) | **有** | 有 | 有 | 有 |
| `DispatchIS_Reports` | 5 分钟 | 5 分钟 | 单点(实际值) | **有** | 有 | 有 | 有 |
| `ROOFTOP_PV/FORECAST` | 30 分钟 | 30 分钟 | **191.5 h** | **无** | 无 | **有(功率)** | 无 |
| `ROOFTOP_PV/ACTUAL` | 30 分钟 | 30 分钟 | 单点(实际值) | 无 | 无 | 有(功率) | 无 |
| `Short_Term_PASA_Reports` | 30 分钟 | 30 分钟 | 143.5 h(样本) | **无** | 有 | 有 | 有 |
| `PDPASA` | 30 分钟 | 30 分钟 | 26.0 h(样本) | **无** | 有 | 有 | 有 |
| `Medium_Term_PASA_Reports` | 不定期 | 天/周 | 样本为长期 | 无 | 有 | 无 | 无 |
| `PREDISPATCHFCST` | 30 分钟 | 30 分钟 | 26.0 h(样本) | **无区域电价** | 无 | 无 | 无 |
| `DISPATCHFCST` | 5 分钟 | 5 分钟 | 单点 | **无区域电价** | 无 | 无 | 无 |
| `P5MINFCST` | 5 分钟 | 5 分钟 | 0.9 h | **无区域电价** | 无 | 无 | 无 |
| `SEVENDAYOUTLOOK_FULL` | 30 分钟 | 30 分钟 | 147.5 h | **无** | 有 | 无 | 无 |
| `Public_Prices` | 每天 | 5 分钟 | 23.9 h(一天) | **有** | 有 | 无 | 无 |
| `HistDemand` | 每天 | 30 分钟 | 单日 | 无 | 有 | 无 | 无 |
| `Bidmove_Complete` | 每天 | 事件 | 不适用 | 有(报价) | 无 | 无 | 无 |
| `Next_Day_Intermittent_Gen_Scada` | 每天 | 5 分钟 | 单日 | 无 | 无 | 无 | 有(SCADA) |
| `Weekly_Constraint_Reports` | 每周 | — | 不适用 | 无 | 无 | 无 | 无 |
| `Vwa_Fcas_Prices` | 每天 | 30 分钟 | 单日 | 有(FCAS) | 无 | 无 | 无 |

**四个 `*FCST` 目录值得单独点名**:`PREDISPATCHFCST`、`DISPATCHFCST`、`P5MINFCST` 三个都**只有 `FCAS_REQ_CONSTRAINT` 与 `FCAS_REQ_RUN` 两张表**,是辅助服务需求报表,**没有区域能量电价,也没有区域需求/光伏/风电**。名字里的 "FCST" 容易被误当成电价预测,实际不是。

---

## 六、需求 / 光伏 / 风电 / 可用发电量 / 备用 的字段清单

字段名全部来自实际解析。**单位说明:NEMWEB 报表 CSV 里没有任何单位元数据**,下表单位取自 AEMO MMS 数据模型的命名约定,不是从文件里读出来的。

### 6.1 PREDISPATCHIS `REGION_SOLUTION`(127 列,等价于 PREDISPATCHREGIONSUM)

| 类别 | 字段 | 单位 |
|---|---|---|
| 需求 | `TOTALDEMAND`, `DEMANDFORECAST`, `DEMAND_AND_NONSCHEDGEN` | MW |
| 光伏 | `SS_SOLAR_UIGF`, `SS_SOLAR_CLEAREDMW`, `SS_SOLAR_COMPLIANCEMW`, `SS_SOLAR_AVAILABILITY` | MW |
| 风电 | `SS_WIND_UIGF`, `SS_WIND_CLEAREDMW`, `SS_WIND_COMPLIANCEMW`, `SS_WIND_AVAILABILITY` | MW |
| 可用发电 | `AVAILABLEGENERATION`, `AVAILABLELOAD`, `DISPATCHABLEGENERATION`, `DISPATCHABLELOAD`, `UIGF`, `DECAVAILABILITY`, `SEMISCHEDULE_CLEAREDMW`, `SEMISCHEDULE_COMPLIANCEMW` | MW |
| 储能/WDR | `BDU_ENERGY_STORAGE`, `BDU_MIN_AVAIL`, `BDU_MAX_AVAIL`, `BDU_CLEAREDMW_GEN`, `BDU_CLEAREDMW_LOAD`, `BDU_INITIAL_ENERGY_STORAGE`, `WDR_INITIALMW`, `WDR_AVAILABLE`, `WDR_DISPATCHED` | MWh(ENERGY_STORAGE)/ MW(其余) |
| 备用与 FCAS | `LOWER5MINDISPATCH/IMPORT/LOCALDISPATCH/LOCALPRICE/LOCALREQ/PRICE/REQ/SUPPLYPRICE`, 同样的 `LOWER60SEC*`、`LOWER6SEC*`、`LOWERREG*`、`RAISE5MIN*`、`RAISE60SEC*`、`RAISE6SEC*`、`RAISEREG*`,以及 `RAISE/LOWER 1SEC...`、`*ACTUALAVAILABILITY` | MW(DISPATCH/REQ/IMPORT 类)、$/MW(*PRICE 类) |
| 联络线 | `NETINTERCHANGE` | MW |
| 盈余 | `LORSURPLUS`, `LRCSURPLUS`, `EXCESSGENERATION` | MW |
| 时间 | `PREDISPATCHSEQNO`, `RUNNO`, `REGIONID`, `PERIODID`, `INTERVENTION`, `LASTCHANGED`, `DATETIME` | — |

### 6.2 DISPATCHIS `REGIONSUM`(126 列,等价于 DISPATCHREGIONSUM)

字段家族与上面**几乎逐一对齐**,差异只在:

| 类别 | 字段 | 单位 |
|---|---|---|
| 需求 | `TOTALDEMAND`, `DEMANDFORECAST`, `DEMAND_AND_NONSCHEDGEN` | MW |
| 光伏 | `SS_SOLAR_UIGF`, `SS_SOLAR_CLEAREDMW`, `SS_SOLAR_COMPLIANCEMW`, `SS_SOLAR_AVAILABILITY` | MW |
| 风电 | `SS_WIND_UIGF`, `SS_WIND_CLEAREDMW`, `SS_WIND_COMPLIANCEMW`, `SS_WIND_AVAILABILITY` | MW |
| 可用发电 | `AVAILABLEGENERATION`, `AVAILABLELOAD`, `DISPATCHABLEGENERATION`, `DISPATCHABLELOAD`, `UIGF`, `SEMISCHEDULE_CLEAREDMW`, `SEMISCHEDULE_COMPLIANCEMW` | MW |
| 时间 | `SETTLEMENTDATE`(**取代** PREDISPATCH 的 `DATETIME`) | — |
| 独有 | `AGGEGATEDISPATCHERROR`(注意原表就是这个拼写)与 `AGGREGATEDISPATCHERROR` **两列并存** | MW |

DISPATCHIS 里**没有** `LORSURPLUS`/`LRCSURPLUS` 之外的 PASA 类字段,也**没有** `BDU_*` 之外的差异;`DISPATCHABLEGENERATION` 与 `AVAILABLEGENERATION` 都有。

### 6.3 ROOFTOP_PV_FORECAST `FORECAST`(8 列,全部字段)

| 字段 | 含义 | 单位 |
|---|---|---|
| `VERSION_DATETIME` | 该次预报的版本时刻 | NEM 时间 |
| `REGIONID` | 区域(**只有区域版有**;AREA 版是 `AREAID`) | — |
| `INTERVAL_DATETIME` | 目标区间结束时刻 | NEM 时间 |
| `POWERMEAN` | 光伏功率期望值 | **MW** |
| `POWERPOE50` | 50% 概率(中位)光伏功率 | MW |
| `POWERPOELOW` | 下界光伏功率 | MW |
| `POWERPOEHIGH` | 上界光伏功率 | MW |
| `LASTCHANGED` | 行最后修改时刻 | NEM 时间 |

**ROOFTOP_PV_FORECAST 里没有任何电价字段,也没有需求或风电**:只有 4 个光伏功率列。AREA 版把 `REGIONID` 换成 `AREAID`,其余 7 列相同。

### 6.4 ROOFTOP_PV_ACTUAL `ACTUAL`(6 列)

`INTERVAL_DATETIME`, `REGIONID`(AREA 版为 `AREAID`), `POWER`(MW), `QI`(质量标志), `TYPE`, `LASTCHANGED`。

### 6.5 其他带需求/光伏/风电的长 horizon 报表

- `SEVENDAYOUTLOOK_FULL/PEAK`(7 列,**147.5 h**):`SCHEDULED_DEMAND`(MW)、`SCHEDULED_CAPACITY`(MW)、`NET_INTERCHANGE`(MW)、`SCHEDULED_RESERVE`(MW)。**无电价。**
- `PDPASA/REGIONSOLUTION`(45 列,26.0 h):`DEMAND10/50/90`(MW)、`SS_SOLAR_UIGF/CAPACITY/CLEARED`(MW)、`SS_WIND_UIGF/CAPACITY/CLEARED`(MW)、`AGGREGATECAPACITYAVAILABLE`、`AGGREGATEPASAAVAILABILITY`、`SURPLUSCAPACITY/RESERVE`(MW)、`LCR/LCR2`。**无电价。**
- `Short_Term_PASA_Reports/REGIONSOLUTION`(45 列,样本 143.5 h):与 PDPASA 同名同结构。**无电价。**
- `Medium_Term_PASA_Reports/REGIONRESULT`(36 列):`DEMAND`(MW)、`TOTALAVAILABLEGENMIN/10/50/90/MAX`(MW)、`TOTALINTERMITTENTGEN10/50/90`、`TOTALSCHEDULEDGEN10/50/90`、`AGGREGATEINSTALLEDCAPACITY`(MW)。**无电价。**

---

## 七、已交付 120 天 CSV 的回查对照

对 `AEMO_Data\window_120d_20260201_20260601\` 的 5 个区域文件**只读**解析(5,760 run × 5 区域 = **28,800 run**):

| 指标 | 值 |
|---|---|
| 周期数 | 32 到 79 |
| horizon | **15.5 至 39.0 小时**,中位 27.2 |
| horizon > 40 小时 | **0** |
| horizon ≥ 48 小时 | **0** |
| horizon 结束时刻 | **只有 04:00** |

**48 个半小时槽 → 周期数的映射,与 2026-10-12 当天 CURRENT 实测的结果逐个槽对比:48/48 完全相同,0 处差异。**

所以:**那 120 天数据没有发生任何程度的 horizon 截断。** 它的 horizon 形态与今天 CURRENT 的实际发布完全同构。早先「48 小时不存在」的结论,这一次用 106 个 CURRENT 实测文件 + 28,800 个历史 run 独立复现了。

---

## 八、本次调查的边界与拿不到的东西

1. **窗口尾部未发布**:任务要求抓到 2026-10-13 03:00,但抓取时(2026-10-13 01:35 NEM)只发布到 **02:00**,02:30 与 03:00 的文件当时不存在。这 53 个文件覆盖 2026-10-12 全天 + 2026-10-13 前 2 小时。
2. **单位不是从文件读的**:NEMWEB CSV 无单位元数据,第六节的单位来自 AEMO MMS 命名约定,标了「约定」而非「实测」。
3. **STPASA 归档样本只扫了 1/744 个成员**:`PUBLIC_STPASA_20260801.zip` 是 225 MB 的月度包,全量扫描超过 25 分钟 CPU 仍未完成,因此改为只解析第 1 个成员。表中 STPASA 的 143.5 h 是**该样本**的值,不代表全包。
4. **没有拿到 AEMO 官方面板那句话的出处**:我只证明 NEMWEB 数据不支持「30 分钟更新 + 48 小时」,无法说明面板文案为何这么写。
5. `Weekly_Constraint_Reports` 的样本 `2026.zip` 解析出 0 张表(结构与其他报告不同),未深究。
6. **EPMC 目录只读的核对**:本次调查对 `C:\Ash\Projects\EMPC_Water_Electricity_Forecast` 的
   全部访问都是读取(解析 120 天 CSV、pd7day CSV),没有写入、没有删除。但调查期间该仓库的
   工作区确实发生了变化,且不是本次调查造成的:
   - 新增 `AEMO_Data/NEMPRICEANDDEMAND_VIC1_202610130200.csv`(22,958 字节,写入时刻
     2026-10-13 03:00:47,正是本次调查进行中)。
   - `AEMO_Data/NEMPRICEANDDEMAND_NSW1_202609101245.csv`、`NEMPRICEANDDEMAND_QLD1_202609040310.csv`、
     `PUBLIC_DISPATCHIS_202609040355_0000000535967869.CSV`、`PUBLIC_P5MIN_202609040400_20260904035533.CSV`、
     `PUBLIC_PREDISPATCH_202609040400_20260904033205_LEGACY.CSV` 五个文件在 `git status` 里显示为已删除。
   - 判据:在线抓取工具(`capture_state.json`、`p5min_forecast.csv`、`predispatch_forecast.csv`)
     的最后写入时间仍是 **2026-09-24**,调查期间没有 python 进程在跑,所以这些变化既不是本次调查
     也不是那个在线脚本造成的,应当是另一个任务或另一个写入方所为。**我没有动过这些文件。**

---

## 九、产出文件清单

| 文件 | 内容 |
|---|---|
| `current_dirs.json` | CURRENT 全部 103 个子目录 + 文件数 + 最新文件名 |
| `dir_probes.json` | ROOFTOP_PV 二层结构探针 + ARCHIVE 根目录 68 项 |
| `manifest_predispatchis.json` / `manifest_predispatch.json` | 两个产品各 53 个文件的下载清单 |
| `predispatchis/` / `predispatch/` | 各 53 个原始 zip(52.3 MB / 23.7 MB) |
| `horizon_predispatchis.json` / `horizon_predispatch.json` | 逐文件 horizon 审计明细 |
| `inventory_predispatchis.json` / `inventory_predispatch.json` | 两种布局的表与列清单 |
| `samples/` | 22 个报告的样本 zip |
| `inventory_samples.json` / `inventory_stpasa.json` | 样本的表/列/行数/时间形态 |
| `fields.json` | 按需求/光伏/风电/可用发电/备用分组的字段清单 |
| `compare.json` | 48 槽对照 + 120 天回查 + PD7DAY 汇总 |
| `01`–`07` 号脚本 | 枚举、抓取、解析、对照(.mjs 负责全部抓取) |
