# 交接报告 PPT 2026-10-14(第二次交接)

压缩上下文之后继续做 PPT 用的。**先读完这一份再动手。**

工程根 `C:\Ash\Projects\EMPC_Water_Electricity_Forecast`。PPT 的活全在 `Weekly\2026-10-13\deck\` 下。

配套两份:**`Weekly\2026-10-13\deck\PPT_PLAN_20261014.md`**(原始规划,含决策与渲染缺陷一节)、**`Weekly\2026-10-13\HANDOVER_60天7日图集_数据与结论_20261014.md` 第 10 节**(口径更正)。

---

## 0 一句话

把三份英文旧稿 59 页原封不动搬成一份,再加 51 页新内容,合成 113 页的单一 deck。**已完成 S0 冻结取数、S1 搬运、S2 新内容前 9 页,合计已产出 71 页(62 搬运 + 9 新)。剩下 S3 预测器二十页、S4 结构说明与图十七页、S5 结论五页与合并、S6 全量自检。**

---

## 1 现在在哪儿

| 段 | 状态 | 产物 | 页 |
|---|---|---|---|
| S0 冻结与取数 | 完成 | 52 个公式过 lint 与渲染加 7 张样张;`deck_numbers_60d.json` | |
| S1 搬运 | 完成,六项判据全过 | `deck_A_carry.pptx`,`slide_origin.json` | 1 至 62 |
| S2 新内容骨架 | 完成,9 页逐页看过 | `deck_B_new.pptx`,`schematics/` 两张 | 63 至 71 |
| **S3 预测器二十页** | **未开工,下一步** | | 72 至 91 |
| S4 结构说明与图 | 未开工 | | 92 至 108 |
| S5 结论与合并 | 未开工 | | 109 至 113 |
| S6 全量自检 | 未开工 | | |

搬运页 1 至 62 的构成:导航页 1 → 旧稿 2 至 27(`Capstone_Forecasting_Deck`,26 页)→ 导航页 28 → 旧稿 29 至 50(`Capstone_Weekly_2026-09-23`,22 页)→ 导航页 51 → 旧稿 52 至 62(`Capstone_Update_2026-10-08_EN`,11 页)。

---

## 2 硬规矩

### 2.1 评价口径,三条

**一、预测误差只能在二维面上比较。** 两个维度是预测的时刻与预测的提前量。**整图 RMSE 任何情况下都不作判据**,只在确认一次改动没动到别处时当指纹用。

**二、合法对象只有四样。** 整张二维误差面;固定提前量下那 288 个时刻的剖面;固定时刻下那 376 个提前量的剖面;以及对整张面做一次逐格计数。

**三、逐格计数也不是结论。** 它把"在哪些格子上赢"压掉了。实例:推荐的组合在 24 小时轴上是 86.5% 的格子更低,拉到 7.6 天轴上是 54,208 比 54,080。

**只有相对比较,没有绝对比较。** 任何"某模型最好"必须带上它是哪一维、取哪个切片。**图与结论必须成对。**

### 2.2 PPT 侧的四条硬判据

- **六色**:`1E2761` `E9A820` `1B2430` `5A6B7B` `C9D4DE` `FFFFFF`。别的颜色一律不许出现。
- **公式一律透明底 PNG**,经 `render_formula.render()` 渲染,`alpha_min == 0`。
- **公式正下方必须有符号表**,覆盖该页公式里出现的每一个符号。
- **文本 run 里不得出现 `_ ^ \ $ { }`**。下标只允许是真下标(run 上写 `baseline="-25000"`),文件名的下划线也不许写。

---

## 3 决策(已定,不要再问)

| 项 | 决定 |
|---|---|
| D1 搬哪几份 | **只搬英文那三份**,中文 `Capstone_Forecasting_v1.pptx` 不搬 |
| D2 导航页 | 加,每份旧稿前一页,共 3 页,**不标注是新加的** |
| D3 配色 | 严格 6 色。卡片白底加 `C9D4DE` 边框 |
| D4 页数 | 完整档 113 页 |
| D5 缺的数 | 已补:16 个模型全部有数 |
| D6 示意图 | 画,已画两张 |

---

## 4 资产

### 4.1 已产出的 deck

| 文件 | 页 | 内容 |
|---|---|---|
| `deck/deck_A_carry.pptx` | 62 | 旧稿搬运版,判据全过 |
| `deck/deck_B_new.pptx` | 9 | 新内容 63 至 71 页 |
| `deck/deck_A_carry.pptx` + 后续 | | 最终合成件还没做 |

### 4.2 工具

| 文件 | 作用 | 判据 |
|---|---|---|
| `deck/deck_formulas.py` | 52 个公式串,mathtext 安全 | 字典,一处登记 |
| `deck/check_formulas.py` | lint + 渲染 + 样张 | 退出码 0;52 条全过 |
| `deck/deck_numbers_60d.json` | **deck 引数的唯一来源** | 由 MATLAB 取数产出,48 KB |
| `deck/deck_numbers_60d.py` | 读取层 + 允许数字集 + `SPEC` | 自检可跑:`python deck_numbers_60d.py` |
| `deck/build_carry.py` | 搬运器 | 配 `verify_carry.py` |
| `deck/verify_carry.py` | 六项判据 | 退出码 0 才算过 |
| `deck/build_new.py` | 新页构建器 + 页内构件 + 数字审计 | 打印"every number traces" |
| `deck/draw_schematics.py` | 两张示意图 | |
| `deck/preview_deck.py` | 整页预览 | 见第 8 节的渲染缺陷 |
| `deck/probe_decks.py` | 读源 deck 的逐页文字与几何 | 搬运对照的底子 |
| `predictor/scripts/extract_deck_numbers.m` | 取数 | 用 `matfile` 逐模型切片 |
| `predictor/runs/run_extract_numbers.bat` | 取数入口,日志名当参数 | |

### 4.3 证据件(读过、可删但要留痕)

`deck/_probe_*.py` 与 `.txt`、`deck/_formula_probe/`、`deck/_formula_probe2/`、`deck/_preview_tmp/`、`deck/_formula_cache/`、`deck/preview_carry/`、`deck/preview_src1/`、`deck/preview_new/`、`deck/formulas/`(52 张 PNG + 7 张样张)。

### 4.4 源参考

| 文件 | 用途 |
|---|---|
| `Weekly/2026-10-13/预测器数学模型与符号_20261013.md` | 符号底稿,**口径已过时**,见第 5 节 |
| `Weekly/2026-10-13/deck/DECK_INVENTORY.md` | 四份参考 deck 的逐页清点,541 行 |
| `Weekly/2026-09-23/deck/deck_kit.py` | 样式工具箱 |
| `Weekly/2026-09-23/deck/render_formula.py` | 公式渲染器 |
| `Weekly/2026-10-08/deck/check_deck.py` | 旧自检,9 项,新自检的基础 |
| `Predicitor/Shared/model_registry.m` | 图集列序的唯一权威 |
| `Predicitor/Shared/official_lead_axis.m` | 376 列轴的唯一权威 |

---

## 5 数字

### 5.1 唯一来源

`deck/deck_numbers_60d.json` ← `extract_deck_numbers.m` ← `atlas_60d.mat` + `official_60d.mat`。

**报告 4.1 节的中位数表口径已作废。** `atlas_60d.mat` 里存的 `R` 是 60 天全窗口的(`run_full_ensemble_test.m` 第 622 行),而出图脚本 `report_figures.m` 第 55 行按 **32 个评分日**重算。报告把两套混在了一份文件里。**deck 一律用 32 天面**,因为图、判定表、普查、组合规则与官方对照全在那一面上。

判据:按 32 天面重算的普查**逐位复现**了出图日志 `figures_60d_v8.log` 印出的数字(官方 23,574 格占 21.77%),M20 对 M4 复现 91,861 / 16,400 / 中位 −5.586,推荐组合对 Anchor-mix 复现 54,208 / 54,080。

### 5.2 十六个模型的中位数 R(32 天口径,1 小时 / 24 小时 / 7.6 天)

| 模型 | 1 h | 24 h | 7.6 d | 模型 | 1 h | 24 h | 7.6 d |
|---|---|---|---|---|---|---|---|
| Persistence | 55.16 | 62.91 | 59.75 | T28 + level | 44.88 | 45.32 | 44.38 |
| Template T28 | 43.46 | 43.46 | 43.69 | Multi-window T | 45.75 | 45.75 | 45.18 |
| Theta-y | 50.27 | 50.27 | 56.49 | MW + level | 45.23 | 46.15 | 44.91 |
| T28 + AR4 | 17.24 | 51.36 | 53.11 | MW + level (run) | 36.36 | 46.51 | 44.72 |
| Carry-forward | 16.90 | 55.16 | 79.02 | Kalman harmonic SS | 31.29 | 57.67 | 63.12 |
| T28 + DMS4 | 16.59 | 44.20 | 45.51 | EWMA template | 45.36 | 45.36 | 43.81 |
| CF + DMS4 | 17.01 | 55.18 | 79.02 | Weekday-class T | 44.49 | 44.49 | 45.80 |
| Anchor-mix | 16.57 | 43.77 | 44.61 | T28 + AR(n per cell) | 17.62 | 45.78 | 47.80 |

官方侧:1 小时 19.49、24 小时 36.29、7.6 天 67.74。

### 5.3 逐格普查(108,288 格,32 天面)

只让 16 个模型竞争:Weekday-class T 28,615(26.42%)、Template T28 23,890(22.06%)、Anchor-mix 18,186(16.79%)、T28 + DMS4 11,971(11.05%)、T28 + AR(n) 9,013(8.32%)、EWMA 4,870、T28 + AR4 4,203、Multi-window T 3,048、其余 7 个合计 2,603。

把官方放进来:Official 23,574(21.77%)、T_class 21,413(19.77%)、T28 18,992(17.54%)、Anchor-mix 14,418(13.31%)、T28 + DMS4 9,420(8.70%)、T28 + AR(n) 6,883(6.36%)、EWMA 4,534、MW 3,048、T28 + AR4 2,594、其余 8 个 3,412。

### 5.4 其他要用到的数

- 官方覆盖:5 至 55 分钟档 190,014 / 190,080 = 100.0%(60 天);1 小时至 183.0 小时档 5,508,910 / 6,307,200 = 87.3%(60 天)。32 天可比格 101,280 / 108,288 = 93.53%。
- 来源配比(32 个评分日):P5MIN 2.93%、PREDISPATCH 14.01%、PD7DAY 76.60%、无 6.47%。**注意报告里的 2.92 / 13.86 / 70.93 / 12.29 是全 60 天口径,两套不许混。**
- 数据年龄:P5MIN 中位 0;PREDISPATCH 中位 0.17 小时、最大 0.42;PD7DAY 中位 3.96、75 分位 7.46、95 分位 12.25、最大 13.42。
- 三产品实测规格:P5MIN 17,281 runs × 12 列,到 55 分钟,每 5 分钟一次;PREDISPATCH 2,880 × 79,horizon 15.5 至 39.0 小时,每 30 分钟一次;PD7DAY 180 × 367,horizon 164.5 至 183.0 小时,每天 07:30 13:00 18:00。
- M19 选阶分布(`ar_sel_hist`,历次每日重选的比例),六个探针跨度:p=1 依次为 23.1 / 15.9 / 49.3 / 80.4 / 90.3 / 78.6%;整体 84.1%。**报告 4.7 节统计的是 `ar_sel_hist`,不是 `ar_sel` 快照**;报告 4.2 节的表格作废(分母是 82,944)。
- 组合整图指纹(只作指纹):推荐规则 `optimal weights, lead bands (shrink 0.3)` 43.447。

---

## 6 公式

### 6.1 mathtext 实测清单

本机没有 TeX 发行版,渲染走 matplotlib mathtext。**禁用:**

| 构造 | 替代 |
|---|---|
| `\big` `\Big` `\bigg` | `\left( \right)` 或圆括号 |
| `\tfrac` | `\frac` |
| `\begin{cases} ... \end{cases}` | `\substack{a\\b\\c}` 或拆两张图 |
| `\le` | **`\leq`** |
| `\overbrace` `\underbrace` | 不要用 |
| `\color` | 不要用 |

`\le` 最阴,几乎所有手写 LaTeX 都会写它。**可用且实测正确:** `\frac` `\dfrac` `\sum_{}^{}` `\min` `\max` `\arg\min` `\left(\right)` `\sqrt{}` `\hat{}` `\bar{}` `\tilde{}` `\mathrm{}` `\text{}` `\operatorname{}` `\mathbf{}` `\mathcal{}` `\mathbb{R}` `\substack{a\\b}` `\{ \}` `\#` `\mid` `\top` `\Delta` `\times` `\pm` `\partial` `\approx` `\leftarrow` `\vdots` `\cdots` `\lfloor \rfloor` `\|x\|` `:=` `D'_h` `p^{\ast}`。

### 6.2 三层检查

1. **lint**:8 条禁用正则,命中即停。
2. **渲染**:600 dpi 透明底,`alpha_min == 0`,墨迹非空,自然宽 ≤ 12.2 英寸。52 条全过,自然宽都 ≤ 8.66 英寸,所以放置时不会被缩小,有效字号恒为 14 pt。
3. **样张**:7 张对照样张,**逐张看过**。第一版样张救了一次:见第 12 节的大小写覆盖。

### 6.3 公式键名对应

`deck_formulas.py` 的键:共享 `slot` `clamp` `clampq` `rlsv` `rlss` `tmpl` `resid` `diff`;官方 `off_rule` `off_pick` `off_age` `off_col`;网格 `lead_axis` `err_e` `err_E` `err_R` `err_pool` `dm` `dm_bh`;预测器 `m1` `m2` `m3` `m4_rec` `m4` `m5` `m6` `m7` `m8` `m8_convex` `m9_fit` `m9` `m10` `m10p` `m11` `m12_rho` `m12` `m13_ss` `m13_upd` `m13` `m13_g` `m13_rot` `m14` `m14p` `m15` `m16` `m17` `m18` `m19_cand` `m19_rule` `m20`;结构 `band48` `win_share`。

---

## 7 版式规矩

页几何沿用 `deck_kit.py`:16:9,`12192000 × 6858000` EMU(精确值,不要用 `deck_kit.SLIDE_W` 那个截断的 13.333),左边距 0.55,内容宽 12.2,页码圆盘 (0.55, 0.42) 直径 0.52,标题框 (1.25, 0.30, 11.5, 0.76)。字号:标题 27,副标题 13,正文 14,小字 11,脚注 10。

**S2 里定下来的四条:**

1. **内容顶 `TOP = 1.38` 英寸。** 标题框到 1.06,13 pt 副标题到约 1.32,再往上放就会压字。
2. **标题按长度自动降字号**:56 字符以内 27 pt,68 以内 24 pt,更长 21 pt。`build_new.py` 的 `title_size()`。
3. **符号表的下标一律真下标**,`symtab` 用 `add_runs` 实现(run 上 `baseline="-25000"`,字号 0.72 倍)。一个符号只允许一个下划线,多则断言失败。
4. **表格用 `add_table6`**,不用 `deck_kit.add_table`(后者用第七个颜色做隔行底色)。

**页内构件**(都在 `build_new.py`):`title_page` `section_page` `formula` `symtab` `prose` `scope` `add_table6` `picture` `add_runs`。

**口径带 `scope()`**:散文在 (0.55, 6.86) 宽 8.05,10 pt;口径公式图在 (8.75, 6.95),fontsize 10。图页必须两块都有。

---

## 8 一个已测出的渲染缺陷与绕法

**缺陷:那套 LibreOffice 渲染把内容按 1.75 倍绘制,画布却按名义 dpi 出图,于是每张预览恒定裁掉右侧与下侧约 43%,`--dpi` 改不了。**

四处独立测量一致给出内容比例 175 px/英寸(画布是 100):深蓝条 0.16 英寸渲染成 27 px;琥珀条左缘 0.58 英寸落在 102 px;右缘 2.78 英寸落在 485 px;页脚文字下缘 4.23 英寸落在 738 px。再把同一组标记放在 13.333 英寸页与 26.667 英寸页上各渲一次,像素**完全相同**(条高都 27 px、左缘都 102 px),所以放大是绝对英寸的。四档 dpi(59 / 72 / 100 / 200)下内容比例恒为 1.72 至 1.75 倍 dpi、画布恒为 1 倍 dpi,两者同步。

**绕法 `preview_deck.py`**:先复制一份 deck,把全部形状与字号乘 1/1.75,再以 dpi 175 渲染。内容缩到页面的 57%,渲染器的 1.75 倍刚好放回画布,整页可见且字号像素不变。判据:2334 px 宽的画布上内容跨度正好 2334 px。缩放副本不进交付件。

**验证搬运是否忠实也可以用它**:用同一渲染器渲源 deck 的某一页,与我搬过来的对应页比 sha256。已验:源 `Capstone_Forecasting_Deck.pptx` 第 1 页与第 20 页的 PNG,与搬运后对应页的 PNG **字节完全相同**。

---

## 9 S3 的逐页规格(第 72 至 91 页)

**二十页,一个预测器一页。** 页内三块:断言句标题、公式(透明 PNG)、紧贴公式正下方的符号表;右栏放三到五条说明;底部口径带。

M1 至 M20 里,**M15 M16 M17 已从图集排除但仍要介绍**,数字用 120 天口径并写明;M19 是**求解规则**(逐格选阶),M20 是**消费它的预测器**,两者数值逐位相同,图集只存 M20。

| 页 | 模型 | 断言句标题 | 公式键 | 1 h / 24 h / 7.6 d |
|---|---|---|---|---|
| 72 | M1 Persistence | Yesterday's slot: the reference every model must beat, and it loses to the official | `m1` | 55.16 / 62.91 / 59.75 |
| 73 | M2 Template T28 | A rolling 28-day per-slot mean carries all the cross-day memory, and nothing else | `tmpl` `m2` | 43.46 / 43.46 / 43.69 |
| 74 | M3 Theta-y | A per-slot gain on yesterday's price fixes the bias, not the timing | `m3` `rlss` | 50.27 / 50.27 / 56.49 |
| 75 | M4 T28 + AR4 | An iterated AR(4) residual dies by design at long leads | `resid` `m4_rec` `m4` `rlsv` | 17.24 / 51.36 / 53.11 |
| 76 | M5 Carry-forward | The newest price held flat: the strongest thing inside the hour, structurally wrong beyond a day | `m5` | 16.90 / 55.16 / 79.02 |
| 77 | M6 T28 + DMS4 | One least-squares row per lead, so no recursion can run away | `m6` | 16.59 / 44.20 / 45.51 |
| 78 | M7 CF + DMS4 | The same direct multi-step engine, anchored on the current price instead of the template | `m7` | 17.01 / 55.18 / 79.02 |
| 79 | M8 Anchor-mix | Three anchors and one weight row per lead, refitted every day | `m8` `m8_convex` | 16.57 / 43.77 / 44.61 |
| 80 | M9 T28 + level | Correct the template's daily level and leave its shape alone | `m9_fit` `m9` | 44.88 / 45.32 / 44.38 |
| 81 | M10 Multi-window T | Four template windows averaged equally | `m10` `m10p` | 45.75 / 45.75 / 45.18 |
| 82 | M11 MW + level | The multi-window template plus the same daily-level correction | `m11` | 45.23 / 46.15 / 44.91 |
| 83 | M12 MW + level (run) | Let the observed share of today set its own weight in the level estimate | `m12_rho` `m12` | 36.36 / 46.51 / 44.72 |
| 84 | M13 Kalman | A harmonic state space: best at 5 minutes, and it decays faster than the anchors | `m13_ss` `m13_upd` `m13` `m13_g` `m13_rot` | 31.29 / 57.67 / 63.12 |
| 85 | M14 EWMA | Exponentially weighted days with the tail actually dropped | `m14` `m14p` | 45.36 / 45.36 / 43.81 |
| 86 | M15 Moving average 1 h | A trailing average is not a forecast: it is the current level, one hour late | `m15` | 120 天口径,整图 51.51 |
| 87 | M16 Moving average, delay compensated | Paying the smoother's delay back as a slope turns a 51 into an 86 | `m16` | 120 天口径,整图 86.38 |
| 88 | M17 Moving median 1 h | A median instead of a mean changes almost nothing once prices are clamped | `m17` | 120 天口径,整图 51.59 |
| 89 | M18 Weekday-class T | Splitting the template by weekday earns 10.8% over the same window unsplit | `m18` | 44.49 / 44.49 / 45.80 |
| 90 | M19 AR order rule | The AR order is chosen per cell from trailing error, never from the test window | `m19_cand` `m19_rule` | 84.1% 选 p=1,分跨度分布见 5.4 |
| 91 | M20 T28 + AR(n per cell) | Choosing the order cell by cell beats a fixed AR(4) in 91,861 of 108,288 cells | `m20` | 17.62 / 45.78 / 47.80 |

**符号表要写到这个程度**(用户原话:"必须要说清楚带上公式,不然没人知道这个东西怎么来的"):

- `T` — 28-day rolling intraday template, 288 by 1. It is not a fixed mean: each slot keeps a ring buffer of 28 days, so the newest value pushes the 28th-oldest out and T moves every day.
- `phi`(写成 φ)— residual AR coefficients, a vector of length p. Estimated online by vector RLS with forgetting factor λ = 0.98, initial value 0, initial covariance 100 I. Not fitted offline.
- 每页还要覆盖该页用到的常数:`n_s` 288、`n_T` 28、`p` 4、`λ` 0.98、`δ` 100、`n_fit` 14、`n_lvl` 56、`α` 0.15、`w` 12、`J` 3、`ρ`、`η`。

**每页口径带一句**:"it issues 376 leads at once, every 5 minutes."

二十页里要补的细节:M4 那一页要写清 p=4 不是最优、扫描给出的结论是 p=1;M8 要写清现在跑的是无正则最小二乘、拟合时报秩亏(rank 10 对 12 列);M15 至 M17 要写清三条负面结论与为什么不留;M19 与 M20 是同一组数字的两个对象。

---

## 10 S4 的逐页规格(第 92 至 108 页)

### 10.1 结构说明两页

**92 页** `The horizontal banding in these maps is grid structure, not noise`。判据:T28 的 `R` 在 375 个相邻列对里 368 对逐位相同,剩余 7 处全落在 24 小时整数倍上;lag-48 自相关 T28 0.998、carry-forward 0.781、kalman 0.675。起因是过了第一小时一列就是 30 分钟,48 列正好一天。**这一页是必须有的**,不然图一看起来像有伪影。

**93 页** `Twenty predictors are defined, sixteen are in the bench`。名册与每个家族提供什么信息;M15 至 M17 与 M19 为什么不在图集的列里。

### 10.2 图十五页

十二张图在 `Weekly/2026-10-13/predictor/figures_60d/`,实测宽高比:

| 图 | 宽高比 | 版式 |
|---|---|---|
| `f1_surfaces` | 1.662 | 左图右说明,图 8.6 x 5.17 |
| `f2a_diff_vs_official` | 1.665 | 同上 |
| `f2b_diff_significance` | 1.666 | 同上 |
| `f3_winner_map` | 1.588 | 同上,图 8.2 x 5.17 |
| `f3b_winner_map_with_official` | 1.588 | 同上 |
| `f4_fixed_lead_profiles` | 1.870 | 图 8.6 x 4.60 |
| `f4b_first_hour` | 1.870 | 同上 |
| `f5_fixed_slot_profiles` | 1.877 | 同上 |
| `f2c_sample_count` | 3.411 | 上图下说明,图 12.2 x 3.48 |
| `f6_combination` | 3.510 | 同上 |
| `f8_m20_vs_m4` | 3.510 | 同上 |
| `f9_order_cellwise` | 3.516 | 同上 |

所有图按 `deck_kit.fit_image` 等比缩放,不裁不拉。

**每张图页的说明块固定五行**(沿用 10-08 英文那份 deck 第 5 页的写法,项目自己用过):

```
What you see.     这一页的坐标轴、颜色、色标范围各是什么
How to read it.   怎么把颜色或曲线读成一个数
What it shows.    三到五个具体数字,全部可追到报告小节
Conclusion.       一句话结论,必须带上它是哪一维、取哪个切片
Scope.            口径散文加口径公式,见下
```

**口径带**散文与公式两块都要:

```
Scope  Window 2026-08-11 to 2026-10-09, 60 days; scored on days 29 to 60, 32 days;
       one sample per cell per day; forecast and actual both clamped to the target
       day's rolling 30-day Q1 and Q99.
```

配 `err_R` 公式图。

**十五页的分配:** 十二张图各一页,加一页图索引,再加两页给最密的两张(f1 十六个面、f3b 普查图)各补一页放大说明。

**`f2c_sample_count` 要单独详细讲数据年龄**,用户点名过。要点见第 5.4 节,前置页已经在第 68 页讲过一遍,图页只讲这张图怎么看。

**注意图上的读数与结论必须对得上**(以下都是已核过的事实):

- f4 固定跨度剖面:5 分钟至 1 天档官方粗黑线最低;到 7.625 天官方升到 45 至 70 而 Template T28 在 30 至 55,**长端换赢家**。
- f5 固定时刻剖面:Template T28 与 Weekday-class T 是近水平线,因为它们的预测与提前量无关;官方那条不是。
- f3b 左图:官方占中段、两个模板家族占长端;黑格带在 24 小时至 4 天之间随时段变化,18:05 至次日 06:05 归 Weekday-class T,06:05 至 18:05 归 Template T28。
- f8/f9:M20 对 M4 在长端大面积更低,中位差 −5.586;f9 中图是产生它的阶数。

---

## 11 S5 与 S6

**S5(109 至 113 页)**:八条结论分三页;F7 暂停一页(现状、恢复代价约 30 分钟加出图 10 分钟、恢复后能得到什么、为什么可以先不做);收尾一页(这份 deck 维护什么、数字从哪来、重跑命令)。然后**合并成单一 deck**:`deck_A_carry.pptx` 的 62 页 + 新内容 51 页,页序即最终页序,页码圆盘已经是最终编号。

**S6 全量自检**:写 `check_deck_60d.py`(在 `check_deck.py` 的 9 项基础上按家族套判据,旧页允许 `normAutofit`、允许不是 6 色、允许中间档字号;新页一条都不许),跑它,整册导预览逐页看,导出 PDF 一份对页数,交件。

合并的技术要点:`slide_origin.json` 现在是搬运页的来源表,合并时要把新页也写进同一份清单(记 `kind: "new"`),自检按它分家族。

---

## 12 已踩到的坑

| 坑 | 后果 | 处理 |
|---|---|---|
| **Windows 文件名大小写不敏感** | `err_e.png` 与 `err_E.png` 互相覆盖,两个文件 sha256 相同,样张上同一个式子出现两次,而内存里的渲染报告是对的,**所有自动判据都没报** | 输出名加 crc 后缀,大小写折叠后仍唯一;并加判据"不同公式串不得产出同一张图"。**这条只有看图能发现** |
| **`\le` 不被 mathtext 支持** | 渲染直接失败 | linter 正则拦截,一律写 `\leq` |
| **千分位逗号** | 审计把 `190,014` 读成 `190` 与 `014`,报两个不存在的数字 | 抽数前先去逗号 |
| **`q_1, q_99` 有两个下划线** | 下标函数只切第一个,剩下的漏进 run,页面上印出下划线 | 下标函数断言残留即失败;改用报告本来的写法 `q1, q99` |
| **文件名里的下划线** | 口径行写 `official_lead_axis.m`,违反文本判据 | 改成文字描述 |
| **内容顶放太高** | 每张有副标题的页都压字(66、67 页最明显) | 统一 `TOP = 1.38` |
| **长标题折行压副标题** | 72 字符的标题折成两行并盖住副标题 | 标题按长度自动降字号 |
| **示意图里的标题与页标题重复** | 同一句话在一页上出现两次 | 删掉图内标题 |
| **示意图的标注放在坐标区外** | 四段说明被裁掉,产品标签印在自己的色条上 | 标注改走 `get_yaxis_transform`,文字放在各自色条上方 |
| **`deck_kit.SLIDE_W` 是截断值** | 12191695 比旧稿的 12192000 窄 305 EMU,右边缘形状出框 | 目标页显式设精确 12192000 |
| **`deck_kit.add_table` 用第七个颜色** | 违反严格 6 色 | 自己写 `add_table6` |
| **导航页的 `<p:style>` 带主题色** | 主题判据按整册总数比会差 18 个 accent1 | 判据改成**逐页**比对,更强也不受导航页干扰 |
| **旧稿有装饰环故意出血页外** | "零越界"判据会把忠实拷贝判成失败 | 判据改成"越界集合与源相同" |
| **`matfile` 不能部分加载 `string` 类变量** | 取数脚本报 "To use 'names', load the entire variable" | 标签用 `load` 整取,数值仍用 `matfile` 切片 |
| **`matfile` 不支持线性索引** | `A.lead_min(:)` 报错 | 先读成变量再 reshape |
| **对三维数组用逻辑下标会静默折叠尾维** | `size(sr(:, b1))` 返回 `288 × 11` 而不是 `288 × 11 × 32`,把 101,376 个非零数数成 3,168 个 | 一律用 `find` 换数字下标,每个维度显式写冒号 |
| **cell 数组不能那样索引** | `A.comb_surf(:,:,pick)` 报 "Index exceeds matrix dimensions" | 先整取 `cs = A.comb_surf`,再 `cs{pick}` |
| **日志名沿用** | 旧进程握句柄,删除与新重定向静默失败,读到上一轮输出 | 日志名当参数,每次换新的;判"跑完了"看产物不看日志 |

**通则一:输入相同而输出不同时,不要继续查输入,去查那个函数本身,用一个不经过它的实现来对照。**

**通则二:一个模型在整张面上给出同一个值,这个形状本身就可疑,通常是比较退化了。**

**通则三:在一根轴上两个量恰好相等的地方,任何"混用"都测不出来。回归对照只能证明共有的部分没变。**

---

## 13 复现命令

Python 与依赖(每次都要设 `PYTHONPATH`,matplotlib 在 10-08 那份 deck 里 vendored):

```
set PY = C:\Users\AshTrailer\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe
set LIB = C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-08\deck\_pylibs
```

| 做什么 | 命令 |
|---|---|
| 公式 lint 加渲染加样张 | `set PYTHONPATH=%LIB%&& "%PY%" Weekly\2026-10-13\deck\check_formulas.py --outdir Weekly\2026-10-13\deck\formulas --sheets` |
| 取数(约 2 分钟) | `Weekly\2026-10-13\predictor\runs\run_extract_numbers.bat <新日志名>` |
| 数字模块自检 | `"%PY%" Weekly\2026-10-13\deck\deck_numbers_60d.py` |
| 搬运 | `"%PY%" Weekly\2026-10-13\deck\build_carry.py` |
| 搬运核对 | `"%PY%" Weekly\2026-10-13\deck\verify_carry.py` |
| 新页 | `"%PY%" Weekly\2026-10-13\deck\build_new.py` |
| 示意图 | `"%PY%" Weekly\2026-10-13\deck\draw_schematics.py` |
| 整页预览 | `"%PY%" Weekly\2026-10-13\deck\preview_deck.py --deck deck_B_new.pptx --pages 1,2,3 --outdir preview_x` |

渲染预览要走 office-pptx 技能给的 LibreOffice Kit 绝对路径(`preview_deck.py` 里已写死):

```
node   = C:\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe
cli.js = C:\DeepSeek Harness\resources\app.asar.unpacked\dsh\node_modules\@deepseek-ai\libreoffice-kit\lib\cli.js
```

MATLAB:`C:\Program Files\MATLAB\R2024a\bin\matlab.exe`。**一次只跑一个 MATLAB 重活**,本机可用内存约 1 GB。

读子进程输出一律重定向到文件再读,不要赋值给变量、不要接管道。判"跑完了"看产物,不看日志内容。

---

## 14 开工顺序

1. 读第 9 节,把二十页按第 3 节的页内模板写进 `build_new.py`(键名、标题、符号表、数字都在表里)。
2. 跑 `build_new.py`,看审计是否全绿(数字可追、无禁用字符、6 色)。
3. `preview_deck.py` 导出这二十页,**逐页看过**,重点看符号表有没有压公式、公式有没有超宽、下标是否渲染成真下标。
4. 停下汇报 S3,再进 S4。
5. S4、S5、S6 按第 10、11 节的规格走,每段结束停下汇报。

## 附 相关技能

- `office-pptx`:读写 pptx、导 PDF 与逐页 PNG 时读。**只用它给的 LibreOffice Kit 绝对路径,不找系统 LibreOffice。**
- `ppt`:做与改演示文稿时读。
- `forecast-eval`:评价口径的权威,第 2 节的规矩来自它。
- `matlab`:取数时读。
