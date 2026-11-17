# AEMO 数据面板「Forecast Spot price … Next 48 hours」判定

实测时点：2026-10-13 01:44 至 02:05 NEM 时间（UTC+10）。本机本地时间是 UTC+11，两者差 1 小时，本文所有时刻除注明外都是 NEM 时间。

## 0. 结论速览

1. 面板上的「Forecast Spot price (Forecast price Pre-dispatch 30 min)」就是 NEMWEB 的 PREDISPATCHIS，底层 MMS 表是 PREDISPATCHPRICE，没有第二个来源。
2. 面板写的「Next 48 hours」不是这条曲线实际能画到的长度。实测该曲线当时只画到未来 26.3 小时。
3. AEMO 没有任何产品定义为「30 分钟粒度、覆盖未来 48 小时、州级电价」。
4. 30 分钟粒度的州级电价预测有两档：PREDISPATCHIS 覆盖近端，实测跨度 17.0 至 39.5 小时；PD7DAY 覆盖 7 天，一天只跑 3 次。
5. 要把跨度做到 48 小时且保住 30 分钟粒度，只能把 PREDISPATCHIS 与 PD7DAY 拼起来。面板自己没有这么做。

## 1. 判定对象

面板页面自己写的文案，取自该页正文：

- 「Pricing data - current and historical spot price (5 min) and Forecast Spot price (Forecast price Pre-dispatch 30 min). Next 48 hours.」
- 「Demand data - current and historical demand (5 min) and Forecast Scheduled Demand (Scheduled Demand Pre-dispatch 30 min). Last 24 hours.」
- 「Dispatch – This data is updated at 5 minute intervals … Last 48 hours」
- 「Data source (MMS tables and fields): TradingPrice.RRP (Spot price 5 min), PreDispatchPrice.RRP (Forecast Spot price), DispatchRegionSum.ClearedSupply (Scheduled Demand 5 min), PredispatchRegionSum.ClearedSupply (Scheduled Demand Pre-dispatch).」

页面地址：https://www.aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/data-dashboard-nem
该页对非浏览器客户端返回 403（Cloudflare），浏览器打开正常，以上正文是在已开着的浏览器里取到的。

判据：供货方自己声明 Forecast Spot price 的来源字段是 PreDispatchPrice.RRP。

## 2. 面板真实结构

外层的 aemo.com.au 页面只是外壳，图表在跨域 iframe 里：

- iframe 地址：https://dashboards.public.aemo.com.au/price-and-demand?Elec_enabled=Yes&Gas_enabled=No&Elec_location=NSW,QLD,SA&Gas_location=TAS,VIC,WA
- 技术栈实测：Vue 3 加 PrimeVue 加 amCharts 5。图表画在 canvas 上，class 为 am5-layer-0 的三个 canvas，1925×703。
- 区域控件实测取值：下拉框值 VIC1，显示文字 VIC。所以题目里的「VIC1」对应面板上的 VIC。
- 模式控件实测：下拉框标签 Pre-Dispatch。它的取值来自 config.json 的 ElectricityPeriods，Pre-Dispatch 对应 30MIN，Dispatch 对应 5MIN。

判据：config.json 原文 `"ElectricityPeriods":[{"label":"Pre-Dispatch","value":"30MIN"},{"label":"Dispatch","value":"5MIN"}]`，以及 `"NemRegions":[{"label":"VIC","value":"VIC1"},…]`。

## 3. 面板调用的后端接口清单

实测手段：在 iframe 里包住 XMLHttpRequest.prototype.open/send，再点区域页签触发重新取数，读出真实请求。同时在 JS 主包 `https://dashboards.public.aemo.com.au/assets/index-DzwJm2qq.js` 里检索路径字面量补全清单。

本页实际发起的请求：

- `GET https://dashboards.public.aemo.com.au/config.json`
- `GET https://dashboards.public.aemo.com.au/NEM/v1/PWS/NEMDashboard/priceAndDemand?timescale=30MIN`
- `GET https://dashboards.public.aemo.com.au/NEM/v1/PWS/NEMDashboard/cumulativePrice`
- `GET https://dashboards.public.aemo.com.au/NEM/v1/PWS/NEMDashboard/marketPriceLimits`

主包里声明但本次页面未发起的同族接口：

- `/NEM/v1/PWS/NEMDashboard/sevenDayOutlook`（「7-Day Outlook」页签用，我另行直接抓过，见 Q2）
- `/NEM/v1/PWS/NEMDashboard/elecSummary`
- `/NEM/v1/PWS/NEMDashboard/fuelMix?type=`
- `/NEM/v1/PWS/NEMDashboard/renewablePenetration`
- `/NEM/v1/PWS/NEMDashboard/dailyAveragePrices?year=`
- `/NEM/v1/PWS/NEMDashboard/monthlyAveragePrices?year=`
- `/NEM/v1/PWS/NEMDashboard/annualAveragePrices`
- `/NEM/v1/PWS/NEMDashboard/Lor/LorDemand`
- `/FPP/v1/PWS/NEMDashboard/…`、`/GAS/v1/PWS/NEMDashboard/…`、`/WEM/v1/PWS/WEMDashboard/…`

取数鉴权：以上接口不带 `x-api-key` 一律 401。密钥就明文写在 `config.json` 的 `xApiKey` 字段里。没有 CSV 接口，面板的下载按钮走客户端 `exportCSV` 生成 Blob。

判据：401 响应原文 `API-Key is not passed, invalid or expired`；config.json 里 `"xApiKey": "0ae2748cec08449bb5b3b31b577f71e2"`；主包里 `getApiResponse(e,t,n,r,i){…headers:{Accept:"*/*","x-api-key":$j.data.xApiKey}…}`。

## 4. 接口实测数字

抓取时点 2026-10-12T15:44:20Z，即 2026-10-13 01:44:20 NEM。

`priceAndDemand?timescale=30MIN`，HTTP 200，402304 字节，1705 条记录，覆盖 NSW1/QLD1/SA1/TAS1/VIC1 五个区。字段为 settlementDate、regionId、rrp、totalDemand、periodType、netInterchange、scheduledGeneration、semiScheduledGeneration、apcFlag。

VIC1 内部构成：

- ACTUAL 288 点，步长实测全为 5 分钟，从 2026-10-12 01:50 到 2026-10-13 01:45，正好过去 24 小时。
- FORECAST 53 点，步长实测全为 30 分钟，从 2026-10-13 02:00 到 2026-10-14 04:00。
- 相对抓取时点 01:44:20，这条曲线实际画到未来 26 小时 16 分。
- 五个区的 FORECAST 首末时刻完全相同，说明窗口是服务端统一裁的，不是各区自己算的。

`priceAndDemand?timescale=5MIN`，HTTP 200，678442 字节，2880 条记录。periodType 全部是 ACTUAL，没有任何 FORECAST。VIC1 576 点，步长全为 5 分钟，从 2026-10-11 01:50 到 2026-10-13 01:45，正好过去 48 小时。

判据：上面每个点数与步长都是对报文逐点算的，不是文档抄的。

这条数字对照面板文案很关键：Dispatch 模式的「48 hours」是真实存在的，但那 48 小时是历史，不是预测。

## 5. NEMWEB 原始产品实测

先纠正目录名。任务背景里给的两个目录名都不存在，返回 404：

- 实测 404：`https://www.nemweb.com.au/Reports/CURRENT/PREDISPATCHIS_Reports/`
- 实测 404：`https://www.nemweb.com.au/Reports/CURRENT/PD7DAY_Reports/`
- 正确目录：`https://www.nemweb.com.au/Reports/CURRENT/PredispatchIS_Reports/`
- 正确目录：`https://www.nemweb.com.au/Reports/CURRENT/PD7Day/`

抓取方式是自己下 zip、按中央目录解 entry、单遍扫 MMS 扁平 CSV。CSV 的列名在 I 行，不在 C 行，C 行是文件头。

### 5.1 PREDISPATCHIS

- 文件：`PUBLIC_PREDISPATCHIS_202610130200_20261013013152.zip`，发布时刻 2026-10-13 01:31:52 NEM。
- 表 `PREDISPATCH|REGION_PRICES` 的 VIC1 且 INTERVENTION=0：53 行，PERIODID 取值为 1 到 53，首 2026/10/13 02:00:00，末 2026/10/14 04:00:00。
- 与面板接口逐点一致：02:00 的 RRP 两边都是 0.01。这就是「同一个产品」的直接证据。
- 发布节奏：实测相邻发布间隔恒为 0.50 小时，即 30 分钟一次。当前目录保留 672 个 zip。

跨度随一天中的时刻变。抽 40 小时内的 17 次发布逐个量 VIC1 电价表的末点：

| 发布时刻(NEM) | 末预测时刻 | 点数 | 最大跨度(小时) |
| --- | --- | --- | --- |
| 10-11 10:01 | 10-12 04:00 | 36 | 17.97 |
| 10-11 12:32 | 10-13 04:00 | 79 | 39.46 |
| 10-11 22:31 | 10-13 04:00 | 59 | 29.47 |
| 10-12 03:31 | 10-13 04:00 | 49 | 24.47 |
| 10-12 11:01 | 10-13 04:00 | 34 | 16.98 |
| 10-12 13:32 | 10-14 04:00 | 77 | 38.46 |
| 10-13 01:31 | 10-14 04:00 | 53 | 26.47 |

17 次抽样合计：跨度最小 16.98 小时，最大 39.46 小时，点数 34 到 79，末点每次都落在 04:00。

末点永远落在 04:00 的原因在官方定义里：交易日是 04:00 到次日 04:00。

### 5.2 PD7Day

- 文件：`PUBLIC_PD7DAY_20261012174724_0000000542519877.zip`，发布时刻 2026-10-12 17:47:24 NEM。
- 表 `PD7DAY|PRICESOLUTION` 的 VIC1 且 INTERVENTION=0：357 行，步长实测全为 30 分钟，首 2026/10/12 18:00:00，末 2026/10/20 04:00:00，时间跨度 178.00 小时。
- 发布频率实测：从文件名时间戳读最近 10 次为 10-09 17:42、10-10 07:11、10-10 12:43、10-10 17:42、10-11 07:11、10-11 12:43、10-11 17:42、10-12 07:11、10-12 12:48、10-12 17:47，即一天 3 次。

注意 PD7DAY 的文件名第一段时间戳就是运行时刻，没有单独的时段前缀，跟 PREDISPATCHIS 的命名规则不同。

### 5.3 P5MIN

- 文件：`PUBLIC_P5MIN_202610130155_20261013015034.zip`。表 `P5MIN|REGIONSOLUTION` 的 VIC1：12 点，步长实测全为 5 分钟，首 2026/10/13 01:55:00，末 2026/10/13 02:50:00，跨度 55 分钟。
- 发布节奏实测：相邻发布间隔 0.08 小时，即 5 分钟一次。

## 6. 官方定义

AEMO 自己的 MMS 数据说明页（Pre-dispatch）原文：

- 30 分钟档：「This file contains 30-minute predispatch (forecast) data by region to the end of the next market day and is updated half hourly.」
- 5 分钟档：「This file contains 5-minute predispatch (forecast) data by region, showing short term price and demand forecasts looking out one hour ahead. The information is updated every 5 minutes.」

地址：https://www.aemo.com.au/Energy%20systems/Electricity/National%20Electricity%20Market%20NEM/Data%20NEM/Market%20Management%20System%20MMS%20data/Pre%20dispatch
该页同样对非浏览器客户端返回 403，正文是在浏览器里取到的。

国家电力规则 NER 第 3 章 3.8.20(a)，现行合并版原文：

「AEMO must prepare and publish a pre-dispatch schedule covering each trading interval of the period commencing from the next trading interval after the current trading interval up to and including the final trading interval of the last trading day for which all valid dispatch bids and dispatch offers have been received in accordance with the timetable and applied by the pre-dispatch process.」

判据：规则里根本没有「40 小时」或「48 小时」这种固定小时数。跨度取决于「下一个交易日的报价是否已收到并用进 pre-dispatch」。全文检索 `40hours` 与 `48hours` 均 0 命中。
来源：https://www.aemc.gov.au/sites/default/files/2023-06/Final%20consolidated%20rule.pdf

同条 3.8.20(b)：pre-dispatch 的分辨率是「one 30-minute period」，外加发布后头 60 分钟用「one trading interval」即 5 分钟。这解释了面板文案里「a mix of 5 minute and 30 minute data intervals」的说法。

AEMO Spot Market Operations Timetable（v1.12，2025 年 12 月 2 日）给出的官方栏目「Period covered」：

- 交易日定义：「trading day: The 24-hour period from 0400 hrs to 0400 hrs the following day」
- 30 分钟 pre-dispatch：「Period covered: Current 30-minute period until end of Day 0」；频率「Every 3 hours as a minimum Rules requirement. Current system target is half hourly.」
- 5 分钟 pre-dispatch：「Period covered: At least the next hour」；频率「Every 3 hours as a minimum Rules requirement. Current system target is every 5 minutes.」

来源：https://aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2023/reliability-forecasting-guidelines-and-methodology-consultation/final/spot-market-operations-timetable.pdf

MMS Data Model Report：

- 表 PREDISPATCHPRICE：「PREDISPATCHPRICE updates with every thirty-minute predispatch run.」字段 PREDISPATCHSEQNO 说明为「Unique identifier of predispatch run in the form YYYYMMDDPP with 01 at 04:30」。
  来源：https://visualisations.aemo.com.au/aemo/nemweb/mmsdatamodelreport/electricity/mms%20data%20model%20report_files/MMS_276.htm
- 表 P5MIN_REGIONSOLUTION：「The five-minute predispatch (P5Min) is a MMS system providing projected dispatch for 12 Dispatch cycles (one hour)… covering the next hour, a total of twelve periods.」并注明 updates every 5 minutes。
  来源：https://visualisations.aemo.com.au/aemo/nemweb/MMSDataModelReport/Electricity/MMS%20Data%20Model%20Report_files/MMS_240.htm

判据小结：30 分钟更新一次这个说法对，官方目标就是 half hourly，实测也是严格 30 分钟。但「48 小时」在规则与官方表格里都没有出现过。

## 7. 三个问题的回答

### Q1 AEMO 是否存在「30 分钟粒度、覆盖未来 48 小时」的州级电价预测产品

不存在。

- 30 分钟粒度的州级电价预测产品只有两个。PREDISPATCHIS 实测跨度 16.98 至 39.46 小时，官方描述是「to the end of the next market day」，更新频率 30 分钟。PD7DAY 实测跨度 178.00 小时，粒度 30 分钟，但一天只跑 3 次。
- 5 分钟粒度的是 P5MIN，官方描述「looking out one hour ahead」，实测 12 点 55 分钟，更新 5 分钟一次。
- 规则层面没有小时数指标，只有「覆盖到已收到报价的最后一个交易日结束为止」。所以「48 小时」既不是保证值，也不是设计值，只是 30 分钟档在最好情况下可能接近的上界。
- 最接近该宣称的是 PREDISPATCHIS。它在单个产品里做不到 48 小时。

### Q2 面板的「Next 48 hours」靠什么凑出来

没有凑。实测结论是文案夸大，理由三条：

1. 这条曲线的唯一数据源是 `priceAndDemand?timescale=30MIN`。主包里的取数后处理是 `i.value = e.data.items.filter(e=>e.regionId===m.value)`，按区域过滤后原样交给图表，没有重采样，也没有第二次合并。
2. 该报文实测 VIC1 的 FORECAST 只到 2026-10-14 04:00，距抓取时点 26 小时 16 分。图表画的就是这批点。
3. 面板上确实有 7 天数据，但它在另一个页签，走 `/NEMDashboard/sevenDayOutlook`，实测返回 175 条、每区 35 条，即 7 天乘 5 个 dataType，一天一条，粒度是天，不是 30 分钟。它没有被并入这张电价曲线。

那「48」这个数字从哪来：两种都说得通，且都能实测到。一是 Dispatch 模式的真实 48 小时历史，实测 576 点乘 5 分钟正好 48 小时，文案里 Dispatch 那段写的也是「Last 48 hours」。二是按 AEMO 对 30 分钟 pre-dispatch 的描述「to the end of the next market day」推算，从交易日刚开始时算确实接近 48 小时。两者都不是这条曲线当时的实际长度。

### Q3 要把跨度推到 48 小时并保持 30 分钟粒度，可用的官方数据组合

用 PREDISPATCHIS 加 PD7DAY 拼接，两段都是 30 分钟粒度、都是州级 RRP。

- 近端用 PREDISPATCHIS，30 分钟粒度，30 分钟刷新一次，实测覆盖到 04:00 边界。
- 远端用 PD7DAY，30 分钟粒度，实测 357 点覆盖 178.00 小时，末端同样落在 04:00。
- 实测重叠证据：2026-10-13 02:00 时点，PREDISPATCHIS 覆盖到 2026-10-14 04:00，PD7DAY 覆盖 2026-10-12 18:00 到 2026-10-20 04:00。两者并集连续覆盖未来 48 小时无缺口。

拼接必须处理的三个接缝：

1. 切换点定在 PREDISPATCHIS 末点，即 04:00 边界，不要按固定小时数切。
2. PREDISPATCHIS 末点会随时刻漂移，实测 17.0 至 39.5 小时，所以切换点是动态的。
3. PD7DAY 一天只跑 3 次，实测最近一次运行时刻到使用时可能已过去数小时，远端段的近端部分比 pre-dispatch 陈旧。两个产品对未来同一时刻可能给不同价格，重叠区要定死以哪个为准。

可以用 PREDISPATCHIS 让拼接点之前的时段达到 5 分钟粒度，因为规则 3.8.20(b) 规定发布后头 60 分钟是 trading interval 分辨率。本次抓到的 30MIN 报文里 ACTUAL 段是 5 分钟、FORECAST 段是 30 分钟，没有出现 5 分钟的预测段，所以这一条本次未实测到。

不要用面板自己的 sevenDayOutlook 接口做这件事，实测它是按天的，粒度不够。

## 8. 不确定与未证实

1. 我没有实测到任何一次 pre-dispatch 覆盖到「下一个交易日结束」。40 小时抽样窗口里最大只有 39.46 小时。所以「最好情况下能到 45 至 48 小时」这一步我没有验证，只是官方描述与规则允许它发生。要证实需要连续采样一整天以上。
2. 我没有找到 AEMO 任何一处用「40 小时」描述 pre-dispatch 跨度。规则、官方时刻表、MMS 数据模型三处都没有这个数字。所以「40 小时」这个流行说法我无法给出官方出处。
3. pre-dispatch 跨度在一天中扩到下一交易日的具体触发时刻，我只定位到区间，没有定位到时刻。实测 10-11 在 11:01 与 12:32 之间扩，10-12 在 11:01 与 13:32 之间扩。触发原因我按规则推测与下一交易日报价收到并被采用有关，这一条未证实。
4. 面板 KPI 卡片写「FORECAST PRICE (/MWh - NEXT 30MIN)」，与文案的 Next 48 hours 互相矛盾。我没有去判定哪个是有意的，只报实测事实。
5. 面板显示的是否为时权价格，以及它如何加权，本次没有验证。

## 9. 复现方法

脚本都在 `C:\Ash\_research_20261013\dashboard\js\`，抓到的原始件在 `C:\Ash\_research_20261013\dashboard\raw\`。

- `cdp2.mjs`：帧感知的 CDP 求值器。原 cdp-eval.mjs 只能在顶层上下文求值，够不到跨域 iframe，所以另写了这个，用 `--frames` 列帧，用 `--frame` 点名。
- `04_hook.js`、`15_hook2.js`：在 iframe 里钩 XMLHttpRequest，抓面板自己发出的请求。
- `10_fetch_api.mjs`：抓面板接口，含 x-api-key。
- `18_nemweb2.mjs`：下 zip、解 entry、单遍扫 MMS CSV，量 PREDISPATCHIS 与 PD7Day。
- `20_horizon.mjs`：抽 40 小时内 17 次 PREDISPATCHIS 发布，量跨度分布。
- `21_p5_pd7.mjs`：量 P5MIN 与 PD7Day 的粒度、跨度、发布节奏。
- `33_pdf.mjs`、`35_official.mjs`、`36_timetable.mjs`、`37_timetable2.mjs`：抓 AEMC 规则与 AEMO 时刻表的 PDF 并取正文。
- `40_verify.mjs`：引用验活。

引用验活结果：本文所有链接实测可访问，只有两个 www.aemo.com.au 的 HTML 页面（数据面板页、Pre-dispatch 数据说明页）对非浏览器客户端返回 403，浏览器访问正常，本文从其正文取的话都已在浏览器内取到。

留存与清理：raw 目录保留面板报文 priceAndDemand_30MIN.json 与 priceAndDemand_5MIN.json、PREDISPATCHIS 原始 CSV、P5MIN 原始 CSV、主包 index-DzwJm2qq.js、AEMC 规则与 AEMO 时刻表的取字文本。删掉了 47 MB 的 PD7DAY 原始 CSV 与几个 PDF 二进制件，这两类都能用 18_nemweb2.mjs 与 33_pdf.mjs 重新抓到，本文引用的数字都已在上面写死。清理后该目录 16.5 MB。
