# GAPS.md — 补漏四源与核验三条结论

日期：2026-10-13。范围：任务 A 补四个抓取失败的源，任务 B 核验三条已有结论。

本轮四个源全部拿到全文，无一条需要退到二手来源。原始件落在 `_gap\` 与既有 `_web\` 下，未改动任何既有文件。

抓取路径说明：四个源的原 URL 本轮分别返回 403 或域名失效。有效的绕法是换机构库作者接受稿，以及用 `r.jina.ai` 代理取 Wrocław 工作报告。

---

## A. 四个补漏源

### A1 方差稳定变换（VST）用于电价预测

- 论文：Uniejewski, Weron, Ziel, "Variance stabilizing transformations for electricity spot price forecasting"，HSC Research Report 17/01，2017-02-14。
- 全文 URL：<https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_17_01.pdf>（本机直连不通，见文末可达性说明）
- 代理 URL（本轮实测取到全文，HTTP 200）：<https://r.jina.ai/https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_17_01.pdf>
- 会议版 URL（本机直连 200）：<https://efc.pwr.edu.pl/assets/EFC17/Uniejewski_EFC17.pdf>
- 本地件：`_gap\vst_hsc1701_jina.txt`（46783 字符，10 页）、`_gap\vst_efc17.pdf`

原 URL `http://www.im.pwr.wroc.pl/~hugo/RePEc/wuu/wpaper/HSC_17_01.pdf` 已失效。新域名是 `alfa.im.pwr.edu.pl`，本机直连 fetch failed，只有代理可取。

**变换形式**。论文不推单一变换，而是系统评估 16 个 VST，分 8 类。除 PIT 类外每类都有两种归一化：set 1 用中位数与 MAD，set 2 用均值与标准差。

| 类 | 形式 |
| --- | --- |
| asinh | `Y = asinh(p) ≡ log(p + sqrt(p² + 1))`，逆变换 `p = sinh(Y)` |
| 3σ / 3σlog | 在 3 倍标准差处截尾，3σlog 先取对数再截尾 |
| logistic | logistic 型压缩 |
| boxcox(λ) | Box-Cox 的对零与负值稳健变体 |
| poly(λ, c) | 两参数族，论文取 λ = 0.125、c = 0.05 |
| mlog(c) | 镜像对数，负值区的对数关于原点翻转 |
| N-PIT | `Y = G⁻¹(F̂_P(p))`，G 为标准正态分布函数 |
| t-PIT | 同上，G 为自由度 ν = 8 的 Student-t |

论文正文对 asinh 的定位：电价预测文献里最常用的对数变换是 Box-Cox 的特例；asinh 已在 Schneider 的文章里用过但未被注意，Ziel 与 Weron 因其能保持样本密度的单峰性而在实证研究中使用。

**为什么电价需要它**。电价序列普遍带 spike。这些极值观测会显著影响模型估计，从而降低预测算法的效率。对只有正价格的市场，对数变换是最常用的降 spike 手段。但对接近零的价格（OMIE.ES、OMIE.PT）或负价格（EPEX.DE+AT），对数不可行。稳健估计与显式 spike 模型在 EPF 文献里并不流行，多数研究仍用 OLS，所以需要一个可在变换侧解决问题的方案。

**精度提升**。论文的汇总指标 m.p.d.f.b. 是每个市场相对当期最优变换的平均百分比差，越小越好。12 个市场的 MAE 口径结果：

| 变换 | m.p.d.f.b.（MAE） |
| --- | --- |
| N-PIT | 0.45% |
| mlog1 | 0.86% |
| poly1 | 0.93% |
| boxcox1 | 1.28% |
| t-PIT | 1.37% |
| poly2 | 1.54% |
| asinh2 | 1.73% |
| asinh1 | 1.85% |
| 3σ2 | 2.04% |
| 3σlog2 | 2.29% |
| logistic2 | 5.24% |
| logistic1 | 7.38% |
| 原始未变换 | 5.22% |

结论：除 logistic 一类外，所有变换在 Diebold-Mariano 检验下都显著优于原始未变换数据。L1 范数下 N-PIT 显著优于其他所有选项，是最稳健的选择。若评价关注 spike（RMSE 类），poly1 与 mlog1 更好；mlog 只有一个形状参数 c，poly 要两个，所以论文推荐 mlog1。

版本提示：以上取自 HSC 工作报告 17/01。正式发表版在 IEEE Transactions on Power Systems，页码与表述可能与此稿有出入。

### A2 长期季节分量（LTSC）在日前电价预测中的作用

- 论文：Nowotarski, Weron, "On the importance of the long-term seasonal component in day-ahead electricity price forecasting"，HSC Research Report 16/05，2016-03-15。
- 全文 URL：<https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_16_05.pdf>（本机直连不通，见文末可达性说明）
- 代理 URL（本轮实测取到全文，HTTP 200）：<https://r.jina.ai/https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_16_05.pdf>
- IDEAS 摘要页（本机直连 200）：<https://ideas.repec.org/p/wuu/wpaper/hsc1605.html>
- 本地件：`_gap\ltsc_hsc1605_jina.txt`（39782 字符，15 页）、`_web\nowotarski2016_ltssc.txt`

**LTSC 怎么估**。论文用两类 LTSC 模型。

- 小波平滑。Daubechies 阶 24 小波，十个平滑水平 J = 5 到 14，约相当于 32 小时到 683 天的平滑尺度，即从日到近半年。
- Hodrick-Prescott 滤波。λ 取八个值：1e8、5e8、1e9、5e9、1e10、5e10、1e11、5e11。

建模流程是把对数价格 p_t 分解成 LTSC 分量 T_t 与随机分量 q_t，对 q_t 拟合 ARX 或 mARX，再把两者预测相加，最后取指数还原。LTSC 的 24 小时外推用持久（随机游走）预测：T̂ 在下一天 24 小时全部等于校准窗口最后一点的 T 值。

论文自己指出一个关键困难：LTSC 是模型假设的产物，现实中不可观测，所以它的预测无法被恰当评价；短期上只能假定持久预测够用。

**去掉 LTSC 再建模是否真的提升精度**。不是无条件提升，取决于 LTSC 用什么方法估。这是本文最实用的发现。

- 小波 LTSC 配多日模型：最优的 mSCARX-S 在 67% 的小时上显著优于 mARX 基准，且从无被显著反超。
- 小波 LTSC 配单日模型：最优的 SCARX-S 在 38% 的小时上显著更优，但在 8% 的小时上显著更差。
- HP 滤波 LTSC：无论 λ 取什么值，从来不优于对应的自回归基准。对 mARX 基准有多达 23% 的小时显著更差。

所以论文的准确结论是「用对方法估计的 LTSC 能带来提升」，而不是「去掉 LTSC 就能提升」。

**适用条件**。

- 数据：两个市场各 2 年逐小时测试期。GEFCom2014（美国东南部 LMP）103 周，Nord Pool（北欧）104 周。
- 最优小波水平随市场变。GEFCom2014 是 S12，约半年即 170 天平滑。Nord Pool 是 S9 与 S10，约 3 至 6 周平滑。最优尺度不能跨市场照搬。
- 一般地，S9 到 S14 之间的近似在两个数据集上都表现不错，但并非全部都能打败基准。
- 多日设定 mARX 与 mSCARX 几乎总优于对应的单日设定。
- 评价用周加权平均绝对误差 WMAE 与 Diebold-Mariano 检验，DM 检验按 24 个小时分别做。

### A3 时间层级（temporal hierarchies）预测与重构

- 论文：Athanasopoulos, Hyndman, Kourentzes, Petropoulos, "Forecasting with temporal hierarchies"，European Journal of Operational Research。
- 作者接受稿全文 URL（本轮实测直连 200）：<https://eprints.lancs.ac.uk/84905/1/Athanasopoulos_2017_TemporalHierarchies.pdf>
- 机构库页面（本轮实测直连 200）：<https://eprints.lancs.ac.uk/id/eprint/84905/>
- 作者主页幻灯片 URL（本轮实测直连 200）：<https://kourentzes.com/forecasting/wp-content/uploads/2015/08/TempHier20150814_Kourentzes.pdf>
- 出版页（付费墙，本机直连 403）：<https://www.sciencedirect.com/science/article/abs/pii/S0377221717301911>
- 本地件：`_gap\temporal_eprints.pdf` 与 `.txt`（26 页，83216 字符）

原清单里的 Bath 研究门户 URL、Monash 的 wp 地址、以及 robjhyndman.com 全部返回 403。Lancaster EPrints 的这个副本可直连下载。

**做法**。对一条序列用不重叠时间聚合造出时间层级，例如月、季、半年、年。在每个层级独立生成基预测（base forecasts），再用重构把它们合成一组一致的预测。重构回归模型是 `ŷ_h = Sβ_h + ε_h`，最优组合取 `P = (S'Σ⁻¹S)⁻¹S'Σ⁻¹`。Σ 未知，Hyndman 等 2011 与本文用不同的估计量替代。

**精度提升多少**。M3 竞赛数据，1428 条月度加 756 条季度，共 2184 条序列。用 sMAPE 与 M3 竞赛原成绩对比：

| 数据 | 时间层级最好成绩 | M3 竞赛原最好成绩（Theta） |
| --- | --- | --- |
| 月度 | 13.61%（ETS + 结构缩放 WLSS） | 13.85% |
| 季度 | 9.70%（ARIMA + WLSV） | 8.96% |

月度上小幅胜出，季度上反而输给 Theta。所以提升不是全面压制既有方法。

**提升的分布很不均匀**，这是引用时最容易漏掉的部分。

- 对 ARIMA 基预测的提升大于对 ETS 基预测的提升，因为 ARIMA 基预测本身更不准。
- 两种基预测下，提升都在年度层级最大。
- 低于年度的层级提升很小。月度数据里，除年度外各层级只有很小的改进，ARIMA 如此；ETS 的 bottom-up 甚至出现损失。
- 论文自己的措辞是「particularly under increased modelling uncertainty」，即基预测越不准，重构带来的好处越大。
- 反直觉的结论：传统观点认为直接用最细层级的 bottom-up 最好，论文结果显示合并所有时间聚合层级的信息更优。

### A4 trace minimization（MinT）最优预测重构

- 论文：Wickramasuriya, Athanasopoulos, Hyndman, "Optimal forecast reconciliation for hierarchical and grouped time series through trace minimization"，Monash 工作报告 22/17，2017-12。
- 全文 URL：<https://www.monash.edu/business/econometrics-and-business-statistics/research/publications/ebs/wp22-17.pdf>（本机直连 403）
- 代理 URL（本轮实测取到全文，HTTP 200）：<https://r.jina.ai/https://www.monash.edu/business/econometrics-and-business-statistics/research/publications/ebs/wp22-17.pdf>
- 本地件：`_web\wickramasuriya2019_tracemin.txt`（45 页）

原 Monash URL 本轮仍 403，代理可取得全文。上一轮 `_pdf_manifest.json` 把它记为失败，实际 `_web\` 下已有全文，本轮直接复用并逐条核对了公式与数字。

**重构的闭式解**。论文 Eq. 11：

```
ỹ_T(h) = S(S'W_h⁻¹S)⁻¹S'W_h⁻¹ ŷ_T(h)
       = S[J − JW_hU(U'W_hU)⁻¹U'] ŷ_T(h)
```

第一个形式是 GLS 形状的解，第二个是等价但计算更省的表示，只需求逆一个 n 阶矩阵而不是 m 阶，因此可扩展到很大的序列集合。

**为什么需要 MinT**。Hyndman 等 2011 的 GLS 重构需要相干误差协方差 Σ_h。本文证明 Σ_h 不可识别：`(I_m − SP)` 幂等，其秩为 `tr(I_m) − tr(I_n) = m − n`，秩亏，所以 Σ_h 在实践中无法估计。MinT 换用基预测误差协方差 W_h，解的形式仍是 GLS，但 W_h 是可估计的。这是 MinT 相对原始 GLS 的核心贡献。

**相对 bottom-up 与 OLS 的优势**。

- 理论保证：MinT 的重构预测至少不差于不相干的基预测。
- OLS 是 MinT 在 `W_h = k_h·I` 下的特例。该假设只在基预测误差不相关且等方差时最优，论文说这在层级或分组序列的应用里不可能满足。
- bottom-up 是 MinT 的另一个极端：用 Moore-Penrose 逆时 `P = J`，即只信最细层级。
- W_h 有五种取法：`k_h·I`（即 OLS）、`k_h·diag(Ŵ_1)`（WLSv，方差缩放）、`k_h·Λ` 且 `Λ = diag(S1)`（WLSs，结构缩放，只用分组结构，误差不可得时可用）、`k_h·Ŵ_1`（MinT(Sample)）、`k_h·Ŵ*_1`（MinT(Shrink)，收缩到对角阵）。
- 论文结论：应当总是用重构，bottom-up 或 top-down 这类只用有限信息的做法应当避免。

**实证数字**。

- 模拟，h = 1 且底层级误差相关为 −0.8 时，MinT(Shrink) 顶层平均 RMSE 比基预测低约 30%。
- 澳大利亚国内旅游数据，555 条序列。MinT(Shrink) 在各层级稳定改进，高层级改进最大：州层级约 −10.8%，区域层级约 −6.9%，平均约 −8.9%。
- 短预测步长 h = 1 与 4 上 MinT(Shrink) 改进最大；长步长 h = 8 与 16 上 WLSv 更好。
- bottom-up 在多数层级与多数步长上比基预测更差，在高层级与基预测不准时损失尤为明显。

---

## B. 核验三条已有结论

### B1 Marcellino, Stock & Watson (2006)：迭代多步在长跨度上相对表现更好

**结论成立，但需要补上限定条件。**

- 原文：`_txt\marcellino2006_di.txt`
- URL：<https://repec.unibocconi.it/igier/igi/wp/2005/285.pdf>

原文位置：

- 摘要，第 112 至 114 行：「The iterated forecasts typically outperform the direct forecasts ... The relative performance of the iterated forecasts improves with the forecast horizon.」
- 引言，第 203 至 205 行：「Third, direct forecasts become increasingly less desirable as the forecast horizon lengthens; this too is consistent with the efficiency of the iterated forecasts outweighing the robustness of the direct forecasts.」
- 结论，第 898 至 902 行：「iterated forecasts tend to have smaller MSFEs than direct forecasts, particularly if the iterated forecasts are computed using AIC lag length selection. The relative performance of the direct forecasts deteriorates as the forecast horizon lengthens...」

必须一并带上的限定条件：

- 第 199 至 201 行：改进幅度「tend to be modest」，即改进本身不大。
- 第 205 至 212 行：对工资、价格、货币这几类序列，低阶自回归的迭代预测会被直接预测打败，只有高阶的迭代预测才赢。论文把这归因于这类序列有效上有一个大的移动平均根，等价于最优线性预测器有长滞后。
- 第 795 至 796 行：以 BIC 选阶为例，h = 6 与 h = 12 的平均相对 MSFE 是 0.86；改用更长滞后能消掉直接预测的大部分优势。

正确表述：在自回归阶数选得够（例如用 AIC 选阶）的前提下，迭代多步预测的 MSFE 通常小于直接多步预测，且这一优势随预测跨度增大而扩大；但对最优线性预测器含长滞后的序列不成立，且改进幅度一般不大。

### B2 Campbell & Shiller (1988)：长期最优预测里长期移动平均占 2/3 到 3/4 权重

**结论基本成立，但表述有三处偏差。**

- 原文：`_txt\campbell_shiller1988.txt`
- URL：<http://www.nber.org/papers/w2511.pdf>

原文位置：

- 摘要，第 29 至 33 行：「We estimate that for each year the optimal forecast of the present value of future real dividends is roughly a weighted average of moving average earnings and current real price, with between 2/3 and 3/4 of the weight on the earnings measure.」
- 正文，第 814 至 818 行：「where e is the 30-year moving average of log real earnings. This shows that p is essentially 3/4 times the long moving average of real log earnings plus 1/4 times the current price.」
- 第 849 至 850 行，加入股息项后的估计：「a weight of 0.638 on e° and 0.288 on P_t」。

偏差在哪里：

1. 权重不落在泛指的「长期移动平均」上，而落在「盈利测度」上，具体是 log 实际盈利的 30 年移动平均。
2. 被预测的对象不是泛指的「长期最优预测」，而是「未来实际股利的现值」。
3. 2/3 到 3/4 是论文对 1871 至 1986 年美国总体股市数据得到的估计区间，不是一般性定理。

正确表述：在 Campbell 与 Shiller 1988 的估计里，未来实际股利现值的最优预测近似等于长期盈利移动平均与当前实际价格的加权平均，盈利测度占 2/3 到 3/4 的权重；论文报告的点估计是 3/4，加入股息项后约为 0.638。

### B3 Lago 等 (2021)：推荐集成规模 4 到 10 个，且 RMSE 不适合评价电价预测

**前半成立，后半有偏差。**

- 原文：`_txt\lago2021_benchmark.txt`
- URL：<https://arxiv.org/pdf/2008.08004v2>

集成规模 4 到 10，成立。第 2051 至 2055 行：「To further maximize the performance, the number of models used in the ensemble should be limited [135], e.g. 4–10, especially in the case of heavy-tailed data for which large ensembles tend to contain outliers more often, resulting in less accurate forecasts.」注意原文是「e.g. 4–10」，是举例建议不是硬性推荐，理由是电价这类重尾数据里大集成更容易纳入离群模型。

RMSE 不适合评价电价预测，不成立。原文说的是不能单独使用。

- 第 2793 至 2794 行：「research in EPF should avoid MAPE and only use metrics like sMAPE or RMSE in conjunction with any version of rMAE.」论文真正要避开的指标是 MAPE，不是 RMSE。
- 第 2808 至 2811 行：「RMSE is more reliable than MAPE but it does not represent correctly the underlying risks of EPF. Hence, it should not be used alone to evaluate forecasting models.」
- 理由在第 2770 至 2775 行：购电成本是线性的，所以线性指标 MAE 与 rMAE 最适合量化预测误差带来的风险。
- 第 2776 至 2780 行补充：RMSE 的结果与 MAE/rMAE 在定性上一致，只是因篇幅未在正文细分析。

正确表述：Lago 等 2021 建议 EPF 研究避开 MAPE，把 sMAPE 或 RMSE 与某个版本的 rMAE 一起使用；RMSE 不应单独使用，因为它不能正确表示电价预测的底层风险。他们推荐的集成规模约为 4 到 10 个模型。

---

## 本轮遗留与不确定项

- A1 用的是 HSC 工作报告 17/01，不是 IEEE TPWRS 的正式发表版。引用正式版页码需另核。
- A3 的作者接受稿与正式发表版之间可能有排版与数字差异，本轮数字均取自 Lancaster EPrints 副本。
- A2 的最优小波水平、A4 的各估计量优劣都依赖具体数据集与市场，不要当成跨市场的通用结论。
- 三条 B 类核验均已在本地抽出的正文里定位到行号，未依赖二手转述。

## URL 可达性说明（2026-10-13 逐条实测）

报告里每个地址都在成稿后发了一次请求。结论分三类。

直连可取（HTTP 200）：

- <https://efc.pwr.edu.pl/assets/EFC17/Uniejewski_EFC17.pdf>
- <https://ideas.repec.org/p/wuu/wpaper/hsc1605.html>
- <https://eprints.lancs.ac.uk/84905/1/Athanasopoulos_2017_TemporalHierarchies.pdf>
- <https://eprints.lancs.ac.uk/id/eprint/84905/>
- <https://kourentzes.com/forecasting/wp-content/uploads/2015/08/TempHier20150814_Kourentzes.pdf>
- <https://repec.unibocconi.it/igier/igi/wp/2005/285.pdf>
- <http://www.nber.org/papers/w2511.pdf>
- <https://arxiv.org/pdf/2008.08004v2>

需代理（直连 403 或不通，加 `https://r.jina.ai/` 前缀后 HTTP 200 且取到全文）：

- <https://www.monash.edu/business/econometrics-and-business-statistics/research/publications/ebs/wp22-17.pdf>
- <https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_17_01.pdf>
- <https://alfa.im.pwr.edu.pl/~hugo/RePEc/wuu/wpaper/HSC_16_05.pdf>

付费墙，本机取不到正文，仅为出处引用：<https://www.sciencedirect.com/science/article/abs/pii/S0377221717301911>。

注意：jina 代理有速率限制，连续快速请求会返回 422，隔几秒重试即恢复 200。上面两个 Wrocław 工作报告的地址属于这一类，不是链接失效。
