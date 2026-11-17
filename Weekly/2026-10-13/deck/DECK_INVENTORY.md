# DECK INVENTORY

Structural inventory of four PowerPoint decks, produced by read-only inspection: python-pptx 1.0.2 on the bundled Python interpreter for the object model, and direct `zipfile` plus `ElementTree` reads of the package XML for backgrounds, theme fonts, and part census. No `.pptx` file was opened for writing or modified.

Conventions used below.

- EMU is the English Metric Unit; 914400 EMU = 1 inch, 12700 EMU = 1 point.
- A *title* is the text of the placeholder whose `idx` is 0 or whose type is TITLE or CENTER_TITLE. Where a slide has no such placeholder the marker `(no title placeholder)` is written and the first 60 characters of the largest-font text on the slide are given instead.
- Counts of text frames, pictures, tables, and charts are top-level shape counts; shapes nested inside a group are counted in the group's row only for pictures, which are traversed into groups.
- Text extracts are truncated at the stated limit and marked `…[cut]`.

## Summary table

`Math-named images` counts pictures whose alt text is exactly a mathematical quantity name, such as `mse.png` or `clamp.png`; that column is the direct evidence for formulas stored as images.

| # | Deck | Bytes | Slides | Slide size (EMU) | Aspect | Major latin | Minor latin | Math-named images |
|---|---|---|---|---|---|---|---|---|
| 1 | `Capstone_Forecasting_Deck.pptx` | 4032474 | 26 | 12192000 x 6858000 | 16:9 (= 1.7778) | Calibri | Calibri | 0 |
| 2 | `Capstone_Weekly_2026-09-23.pptx` | 783181 | 22 | 12192000 x 6858000 | 16:9 (= 1.7778) | Calibri | Calibri | 0 |
| 3 | `Predicitor.pptx` | 2543933 | 10 | 12192000 x 6858000 | 16:9 (= 1.7778) | 等线 Light | 等线 | 0 |
| 4 | `Capstone_Forecasting_v1.pptx` | 5394488 | 22 | 12191695 x 6858000 | 2438339:1371600 (= 1.7777) | Calibri | Calibri | 17 |

## Deck 1 — `C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Forecasting_Deck.pptx`

- Absolute path: `C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Forecasting_Deck.pptx`
- File size: 4032474 bytes
- Slide count: 26
- Slide width: 12192000 EMU
- Slide height: 6858000 EMU
- Aspect ratio: 16:9 (= 1.7778)
- `ppt/presentation.xml` slide size element: `<p:sldSz cx="12192000" cy="6858000"/>`
- Notes slides in package: 0

### Slide layouts used

These are the layouts the slides actually reference, out of 11 layouts present in the master.

- Blank

### Slide master names and background fill

- Master `ppt/slideMasters/slideMaster1.xml`: the `p:cSld` element carries no `name` attribute, so the master is unnamed in the file. python-pptx reports its `name` as the empty string.
  - Background fill declared on the master: `p:cSld > p:bg > p:bgRef idx=1001 > a:schemeClr val=bg1`.
  - No slide layout in this deck declares its own `p:bg`, and no slide declares one either, so the master background is what every slide inherits.

### Theme font scheme

- Part `ppt/theme/theme1.xml`
  - `a:majorFont` latin typeface: Calibri
  - `a:minorFont` latin typeface: Calibri
  - `a:majorFont` east-asian typeface: (no `a:ea` element declared)
  - `a:minorFont` east-asian typeface: (no `a:ea` element declared)

### Slide titles in order

1. (no title placeholder) — largest-font text: Electricity Price Forecasting for Economic MPC
2. (no title placeholder) — largest-font text: Project workflow and where forecasting fits
3. (no title placeholder) — largest-font text: Data source — AEMO monthly price & demand files
4. (no title placeholder) — largest-font text: Automated AEMO capture — Python (nemweb.com.au)
5. (no title placeholder) — largest-font text: Capture stores, retention and dedup
6. (no title placeholder) — largest-font text: Core building block — adaptive RLS AR(p) filter
7. (no title placeholder) — largest-font text: AR(p) model and iterated multi-step prediction
8. (no title placeholder) — largest-font text: Daily template — the cross-day memory
9. (no title placeholder) — largest-font text: Experiment 1 — AR vs AR + daily template
10. (no title placeholder) — largest-font text: Experiment 1 — key finding: short good, long bad
11. (no title placeholder) — largest-font text: Experiment 2 — template window strategies
12. (no title placeholder) — largest-font text: Experiment 3 — AR order sweep (p = 1…10)
13. (no title placeholder) — largest-font text: Experiment 4 — forecast update cadence
14. (no title placeholder) — largest-font text: Experiment 5 — no-split vs weekday/weekend template (89 days …[cut]
15. (no title placeholder) — largest-font text: Phase-1 summary — what the first experiments established
16. (no title placeholder) — largest-font text: Part II — the six-model predictor suite
17. (no title placeholder) — largest-font text: Benchmark protocol and price clamp
18. (no title placeholder) — largest-font text: Predictor 1 & 2 — Persistence and rolling template
19. (no title placeholder) — largest-font text: Predictor 3 — Theta-y tracker
20. (no title placeholder) — largest-font text: Predictor 4 — Template + intraday AR(4)
21. (no title placeholder) — largest-font text: Predictor 5 & 6 — convex blends (Blend A and B)
22. (no title placeholder) — largest-font text: Benchmark results — aggregate & lead-time accuracy
23. (no title placeholder) — largest-font text: Benchmark results — RMSE(slot, lead) matrices
24. (no title placeholder) — largest-font text: Benchmark results — per-slot profile & improvement
25. (no title placeholder) — largest-font text: Conclusions
26. (no title placeholder) — largest-font text: Next steps

### Per-slide content summary

| Slide | Layout | Text frames | Pictures | Tables | Charts | Groups | Runs without explicit size | First 120 chars of concatenated text |
|---|---|---|---|---|---|---|---|---|
| 1 | Blank | 8 | 0 | 0 | 0 | 0 | 0 | Electricity Price Forecasting for Economic MPC of Water Pumping Systems From AR + RLS to a six-model predictor suite — d …[cut] |
| 2 | Blank | 16 | 0 | 0 | 0 | 0 | 0 | 1 Project workflow and where forecasting fits Wholesale spot price varies every 5 min — EMPC shifts pumping to cheap per …[cut] |
| 3 | Blank | 5 | 0 | 1 | 0 | 0 | 0 | 2 Data source — AEMO monthly price & demand files Historical data: one CSV per region-month, publicly available from AEM …[cut] |
| 4 | Blank | 17 | 0 | 0 | 0 | 0 | 0 | 3 Automated AEMO capture — Python (nemweb.com.au) Replaces manual monthly downloads with a continuous fetch of current N …[cut] |
| 5 | Blank | 4 | 0 | 1 | 0 | 0 | 0 | 4 Capture stores, retention and dedup Three append-only / batch-retention CSV stores under AEMO_Data • Dedup keeps the h …[cut] |
| 6 | Blank | 7 | 1 | 0 | 0 | 0 | 0 | 5 Core building block — adaptive RLS AR(p) filter apply_rls_filter.m — estimates AR coefficients online with forgetting  …[cut] |
| 7 | Blank | 6 | 3 | 0 | 0 | 0 | 0 | 6 AR(p) model and iterated multi-step prediction predict_ar_recursive.m — freeze coefficients, recurse forward over the  …[cut] |
| 8 | Blank | 6 | 3 | 0 | 0 | 0 | 0 | 7 Daily template — the cross-day memory build_daily_template.m / init_ewma_state.m — a mean profile over 288 five-minute …[cut] |
| 9 | Blank | 4 | 8 | 0 | 0 | 0 | 0 | 8 Experiment 1 — AR vs AR + daily template run_prediction_experiment.m — does a template fix the long-horizon collapse o …[cut] |
| 10 | Blank | 7 | 5 | 0 | 0 | 0 | 0 | 9 Experiment 1 — key finding: short good, long bad The template supplies the daily shape; AR only helps at short lead ti …[cut] |
| 11 | Blank | 4 | 6 | 0 | 0 | 0 | 0 | 10 Experiment 2 — template window strategies run_prediction_experiment.m (Fig. 2) — how many days should the mean span?  …[cut] |
| 12 | Blank | 3 | 3 | 1 | 0 | 0 | 0 | 11 Experiment 3 — AR order sweep (p = 1…10) run_ar_order_sweep.m — does raising the AR order help? (2026-02-01 → 02-07)  …[cut] |
| 13 | Blank | 4 | 1 | 1 | 0 | 0 | 0 | 12 Experiment 4 — forecast update cadence run_update_cadence_sweep.m — pure AR(4), how often should we re-issue the fore …[cut] |
| 14 | Blank | 4 | 1 | 1 | 0 | 0 | 0 | 13 Experiment 5 — no-split vs weekday/weekend template (89 days) run_template_class_long_test.m — 28-day windows, 2026-0 …[cut] |
| 15 | Blank | 8 | 0 | 0 | 0 | 0 | 0 | 14 Phase-1 summary — what the first experiments established AR order Raising p (1→10) gives no meaningful gain — AR(3)–A …[cut] |
| 16 | Blank | 7 | 0 | 0 | 0 | 0 | 0 | Part II — the six-model predictor suite Unified on-line benchmark at 5-minute cadence, scored on a 288×288 RMSE matrix p …[cut] |
| 17 | Blank | 7 | 10 | 0 | 0 | 0 | 0 | 15 Benchmark protocol and price clamp run_predictor_benchmark.m — every observation re-issues the full 24-h forecast • U …[cut] |
| 18 | Blank | 7 | 2 | 0 | 0 | 0 | 0 | 16 Predictor 1 & 2 — Persistence and rolling template 1. Persistence ŷ(t+h\|t) = y(s+h − 288) Same slot, previous day — t …[cut] |
| 19 | Blank | 6 | 3 | 0 | 0 | 0 | 0 | 17 Predictor 3 — Theta-y tracker Per-slot scalar gain on yesterday's price, adapted by RLS ŷ(t+h\|t) = θ(s+h) · y(s+h − 2 …[cut] |
| 20 | Blank | 6 | 4 | 0 | 0 | 0 | 0 | 18 Predictor 4 — Template + intraday AR(4) The core model: rolling template for the daily shape + AR for short-term trac …[cut] |
| 21 | Blank | 6 | 7 | 0 | 0 | 0 | 0 | 19 Predictor 5 & 6 — convex blends (Blend A and B) Adaptively combine a long-term and a short-term component, per slot ŷ …[cut] |
| 22 | Blank | 5 | 0 | 2 | 0 | 0 | 0 | 20 Benchmark results — aggregate & lead-time accuracy Two-week test (Feb 1–14), clamped prices, $/MWh Reading the tables …[cut] |
| 23 | Blank | 3 | 2 | 0 | 0 | 0 | 0 | 21 Benchmark results — RMSE(slot, lead) matrices Full 288×288 RMSE surface per model (rows = target slot, cols = lead ti …[cut] |
| 24 | Blank | 4 | 2 | 1 | 0 | 0 | 0 | 22 Benchmark results — per-slot profile & improvement Where each model wins, and by how much vs the persistence baseline …[cut] |
| 25 | Blank | 8 | 0 | 0 | 0 | 0 | 0 | Conclusions ● The daily template is the indispensable long-term component — AR alone cannot forecast past ~6 h. ● The re …[cut] |
| 26 | Blank | 8 | 0 | 0 | 0 | 0 | 0 | 23 Next steps Automation Schedule the Python capture with GitHub Actions for hands-off daily data refresh. Kalman predic …[cut] |

### Every picture on every slide

`descr` is the alt text stored on the picture; `null` means the attribute is absent. It is reported because in these decks it carries the source file name.

| Slide | Shape name | Alt text (descr) | Width EMU | Height EMU | Left EMU | Top EMU | Pixel size | Bytes |
|---|---|---|---|---|---|---|---|---|
| 6 | Picture 9 | null | 1644576 | 212661 | 2927425 | 3322669 | 464x60 | 10077 |
| 7 | Picture 8 | null | 3215125 | 406212 | 1935259 | 1733484 | 744x94 | 12905 |
| 7 | Picture 10 | null | 3215125 | 347703 | 1935260 | 2664760 | 712x77 | 11010 |
| 7 | Picture 12 | null | 4967461 | 340096 | 1935259 | 3513106 | 964x66 | 12910 |
| 8 | Picture 8 | null | 2648341 | 612542 | 1885100 | 1810618 | 588x136 | 13223 |
| 8 | Picture 10 | null | 3245714 | 652351 | 1885100 | 4927692 | 607x122 | 18323 |
| 8 | Picture 12 | null | 1309792 | 536876 | 1885101 | 5627263 | 283x116 | 6002 |
| 9 | Picture 4 | exp1_three_models.png | 5943600 | 4754880 | 5760720 | 1234440 | 2416x1946 | 307126 |
| 9 | Picture 7 | null | 2878377 | 614837 | 740664 | 2034282 | 735x157 | 19420 |
| 9 | Picture 9 | null | 2878377 | 566302 | 740664 | 2862698 | 737x145 | 22015 |
| 9 | Picture 11 | null | 2459736 | 1031101 | 740664 | 3710008 | 594x249 | 34888 |
| 9 | Picture 13 | null | 1812151 | 614837 | 740664 | 4714698 | 392x133 | 15388 |
| 9 | Picture 15 | null | 2459736 | 362017 | 740665 | 5313178 | 496x73 | 9150 |
| 9 | Picture 17 | null | 2084408 | 541618 | 8237296 | 73152 | 508x132 | 13211 |
| 9 | Picture 19 | null | 2465591 | 566362 | 8237296 | 614770 | 579x133 | 16200 |
| 10 | Picture 9 | null | 2084408 | 541618 | 9416101 | 135321 | 508x132 | 13211 |
| 10 | Picture 11 | null | 2465591 | 566362 | 9416101 | 676939 | 579x133 | 16200 |
| 10 | Picture 13 | null | 3101006 | 423430 | 639221 | 2053545 | 498x68 | 9110 |
| 10 | Picture 15 | null | 1492543 | 368204 | 639221 | 2464709 | 227x56 | 4456 |
| 10 | Picture 17 | null | 1949743 | 422048 | 639221 | 2832914 | 328x71 | 6992 |
| 11 | Picture 4 | exp2_window_strategies.png | 5943600 | 4546480 | 5760720 | 1338639 | 2544x1946 | 328256 |
| 11 | Picture 7 | null | 2084408 | 541618 | 9574192 | 113239 | 508x132 | 13211 |
| 11 | Picture 9 | null | 2465591 | 566362 | 9574192 | 654857 | 579x133 | 16200 |
| 11 | Picture 11 | null | 1646327 | 583074 | 740664 | 1768238 | 336x119 | 11162 |
| 11 | Picture 13 | null | 1883384 | 583075 | 740664 | 2562836 | 365x113 | 12438 |
| 11 | Picture 15 | null | 2867360 | 615777 | 740665 | 3404201 | 610x131 | 18378 |
| 12 | Picture 4 | exp3_ar_order.png | 5303520 | 3281468 | 6400800 | 1788265 | 2733x1691 | 309484 |
| 12 | Picture 7 | null | 2084408 | 541618 | 9586862 | 126177 | 508x132 | 13211 |
| 12 | Picture 9 | null | 2465591 | 566362 | 9586862 | 667795 | 579x133 | 16200 |
| 13 | Picture 4 | exp4_update_cadence.png | 7132320 | 4663440 | 4572000 | 1280160 | 2450x1888 | 240227 |
| 14 | Picture 4 | exp5_template_class.png | 4297680 | 3289666 | 7452360 | 1281246 | 2524x1932 | 204195 |
| 17 | Picture 9 | null | 2459630 | 398056 | 6583680 | 2230844 | 414x67 | 10186 |
| 17 | Picture 11 | null | 3383370 | 1087283 | 6583681 | 2628900 | 529x170 | 19866 |
| 17 | Picture 13 | null | 1744021 | 296314 | 673548 | 3198030 | 412x70 | 8695 |
| 17 | Picture 15 | null | 1403533 | 524644 | 673548 | 3708163 | 313x117 | 9827 |
| 17 | Picture 17 | null | 1403533 | 323115 | 2417569 | 3808927 | 278x64 | 6401 |
| 17 | Picture 19 | null | 1821371 | 295357 | 673548 | 4413529 | 370x60 | 8026 |
| 17 | Picture 21 | null | 2796327 | 557748 | 673548 | 4891577 | 737x147 | 20871 |
| 17 | Picture 23 | null | 1573090 | 310610 | 673549 | 5632016 | 314x62 | 5871 |
| 17 | Picture 25 | null | 849783 | 310610 | 2541028 | 5632017 | 145x53 | 2889 |
| 17 | Picture 27 | null | 2717262 | 321461 | 673549 | 6125317 | 448x53 | 9326 |
| 18 | Picture 9 | null | 1784291 | 941405 | 777240 | 4134551 | 326x172 | 15659 |
| 18 | Picture 11 | null | 2177907 | 318718 | 777240 | 2691710 | 410x60 | 8036 |
| 19 | Picture 8 | null | 3127441 | 359347 | 502920 | 1815560 | 557x64 | 11788 |
| 19 | Picture 10 | null | 3723909 | 790970 | 502920 | 3060947 | 645x137 | 17003 |
| 19 | Picture 12 | null | 1798219 | 1657817 | 502920 | 4681728 | 333x307 | 18394 |
| 20 | Picture 8 | null | 1915809 | 370599 | 1367140 | 5052513 | 305x59 | 7196 |
| 20 | Picture 10 | null | 1799954 | 351506 | 1367140 | 2452588 | 297x58 | 6746 |
| 20 | Picture 12 | null | 3464657 | 575263 | 1367140 | 1574748 | 530x88 | 12115 |
| 20 | Picture 14 | null | 3973925 | 337456 | 1367140 | 3051890 | 789x67 | 14149 |
| 21 | Picture 8 | null | 3926652 | 383673 | 978408 | 1691827 | 655x64 | 10250 |
| 21 | Picture 10 | null | 1631568 | 320270 | 978409 | 2377520 | 270x53 | 3926 |
| 21 | Picture 12 | null | 2400633 | 315450 | 978408 | 2955453 | 449x59 | 8969 |
| 21 | Picture 14 | null | 1832393 | 346669 | 978409 | 4727948 | 333x63 | 5933 |
| 21 | Picture 16 | null | 1039810 | 346603 | 3152380 | 4728014 | 204x68 | 3332 |
| 21 | Picture 18 | null | 1223187 | 332008 | 981062 | 5074618 | 210x57 | 4354 |
| 21 | Picture 20 | null | 1785061 | 666946 | 4383873 | 4728014 | 273x102 | 6054 |
| 23 | Picture 3 | bench_rmse_matrix.png | 6949440 | 3977022 | 502920 | 1623368 | 2518x1441 | 684901 |
| 23 | Picture 4 | bench_rmse_lead.png | 3844243 | 4663440 | 7724798 | 1280160 | 1706x1879 | 138747 |
| 24 | Picture 5 | bench_rmse_slot.png | 6675120 | 3108960 | 5029200 | 1280160 | 2685x1691 | 423652 |
| 24 | Picture 6 | bench_week_aligned.png | 6675120 | 1828800 | 5029200 | 4434840 | 3169x1890 | 757861 |

### Equations or symbols stored as images rather than text

The package contains no OLE equation objects (`oleObject` parts): every graphic in this deck is a PNG. The question is therefore whether formulas are *drawn as* pictures. Two kinds of evidence bear on it, and they are reported separately because they carry different weight.

- Total pictures: 61. Pictures under 1200000 EMU (about 1.3 inch) tall: 51.
- Short-picture heights in descending frequency: 541618 EMU x4 (slides [9, 10, 11, 12]); 566362 EMU x4 (slides [9, 10, 11, 12]); 310610 EMU x2 (slides [17]); 614837 EMU x2 (slides [9]); 212661 EMU x1 (slides [6]).
- Short pictures sharing an identical width and height, which indicates one rendering pipeline rather than hand-placed screenshots: 2084408x541618 EMU on slides [9, 10, 11, 12]; 2465591x566362 EMU on slides [9, 10, 11, 12].
- No picture in this deck carries alt text naming a mathematical quantity.

Deck-specific reading.

Deck 1 carries no alt text on any of its short pictures, so a name-based test finds nothing. What the structure does show is that the deck keeps two separate populations: 10 large figures that are clearly plots, and 51 short wide strips under 1200000 EMU that sit inline where a displayed formula would sit. The strips share repeated exact dimensions, so they were produced programmatically as a family. Whether their pixels are equations or cropped plot labels cannot be settled from the object model, because nothing in this deck names them.

Caveat: this is a structural and naming test. It reports the height distribution, the repeated exact dimensions, and the alt-text naming conventions. It does not decode any image, so the classification of a given strip as an equation rests on that structural evidence, not on reading its pixels.

## Deck 2 — `C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Weekly_2026-09-23.pptx`

- Absolute path: `C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Weekly_2026-09-23.pptx`
- File size: 783181 bytes
- Slide count: 22
- Slide width: 12192000 EMU
- Slide height: 6858000 EMU
- Aspect ratio: 16:9 (= 1.7778)
- `ppt/presentation.xml` slide size element: `<p:sldSz cx="12192000" cy="6858000"/>`
- Notes slides in package: 0

### Slide layouts used

These are the layouts the slides actually reference, out of 11 layouts present in the master.

- Blank

### Slide master names and background fill

- Master `ppt/slideMasters/slideMaster1.xml`: the `p:cSld` element carries no `name` attribute, so the master is unnamed in the file. python-pptx reports its `name` as the empty string.
  - Background fill declared on the master: `p:cSld > p:bg > p:bgRef idx=1001 > a:schemeClr val=bg1`.
  - No slide layout in this deck declares its own `p:bg`, and no slide declares one either, so the master background is what every slide inherits.

### Theme font scheme

- Part `ppt/theme/theme1.xml`
  - `a:majorFont` latin typeface: Calibri
  - `a:minorFont` latin typeface: Calibri
  - `a:majorFont` east-asian typeface: (no `a:ea` element declared)
  - `a:minorFont` east-asian typeface: (no `a:ea` element declared)

### Slide titles in order

1. (no title placeholder) — largest-font text: Correcting AEMO's Own Price Forecast
2. (no title placeholder) — largest-font text: The predictor is one link: this week we added a second one
3. (no title placeholder) — largest-font text: Part I — Data chain audit
4. (no title placeholder) — largest-font text: AEMO_Data holds four unrelated datasets, not one
5. (no title placeholder) — largest-font text: Same market, three conventions — the mismatches are all ours
6. (no title placeholder) — largest-font text: The monthly and real-time prices never disagreed
7. (no title placeholder) — largest-font text: Five defects in the capture chain — all of them ours, all fi …[cut]
8. (no title placeholder) — largest-font text: The blast radius, and the fifth defect that was not in the p …[cut]
9. (no title placeholder) — largest-font text: After the fix the store accumulates intervals instead of ove …[cut]
10. (no title placeholder) — largest-font text: Part II — Predictor baseline
11. (no title placeholder) — largest-font text: Six predictors, one 288×288 error surface each
12. (no title placeholder) — largest-font text: Template + AR(4) owns the first three hours and loses beyond …[cut]
13. (no title placeholder) — largest-font text: Averaging over 288 leads hides the only horizon that matters
14. (no title placeholder) — largest-font text: Part III — The AEMO error model
15. (no title placeholder) — largest-font text: We do not need to beat AEMO — we need to correct them
16. (no title placeholder) — largest-font text: The pairing had to be rebuilt from the NEMWEB archive
17. (no title placeholder) — largest-font text: AEMO's 5-minute forecast is good — and it degrades fast
18. (no title placeholder) — largest-font text: The error is not noise: it arrives in runs
19. (no title placeholder) — largest-font text: No single candidate wins the hour: persistence takes 5–10 mi …[cut]
20. (no title placeholder) — largest-font text: Short-lead table, all four candidates, by lead
21. (no title placeholder) — largest-font text: What the error study says, and what it does not
22. (no title placeholder) — largest-font text: Next

### Per-slide content summary

| Slide | Layout | Text frames | Pictures | Tables | Charts | Groups | Runs without explicit size | First 120 chars of concatenated text |
|---|---|---|---|---|---|---|---|---|
| 1 | Blank | 7 | 0 | 0 | 0 | 0 | 0 | Correcting AEMO's Own Price Forecast Data-chain audit, predictor baseline, and a first error model for the 5-minute P5 p …[cut] |
| 2 | Blank | 7 | 0 | 0 | 0 | 0 | 0 | 1 The predictor is one link: this week we added a second one Pipeline overview · the new branch is the AEMO error model  …[cut] |
| 3 | Blank | 7 | 0 | 0 | 0 | 0 | 0 | Part I — Data chain audit Four producers, three timebases, one broken store |
| 4 | Blank | 4 | 0 | 1 | 0 | 0 | 0 | 2 AEMO_Data holds four unrelated datasets, not one Inventory by producer · AEMO_Data · 2026-09-23 ▪ Only class A feeds t …[cut] |
| 5 | Blank | 4 | 0 | 1 | 0 | 0 | 0 | 3 Same market, three conventions — the mismatches are all ours Field-by-field comparison of the three price sources ▪ Ev …[cut] |
| 6 | Blank | 4 | 1 | 1 | 0 | 0 | 0 | 4 The monthly and real-time prices never disagreed 8 sampled days, VIC1, point-by-point against the NEMWEB archive ▪ max …[cut] |
| 7 | Blank | 4 | 0 | 1 | 0 | 0 | 0 | 5 Five defects in the capture chain — all of them ours, all fixed Online_Data_Capture_Project Evidence: data_audit/scrip …[cut] |
| 8 | Blank | 4 | 0 | 1 | 0 | 0 | 0 | 6 The blast radius, and the fifth defect that was not in the parser Online_Data_Capture_Script D5 evidence: data_audit/s …[cut] |
| 9 | Blank | 5 | 0 | 1 | 0 | 0 | 0 | 7 After the fix the store accumulates intervals instead of overwriting them Same command, same source, before and after  …[cut] |
| 10 | Blank | 7 | 0 | 0 | 0 | 0 | 0 | Part II — Predictor baseline Where the six-model suite stands, re-run today |
| 11 | Blank | 4 | 0 | 1 | 0 | 0 | 0 | 8 Six predictors, one 288×288 error surface each run_predictor_benchmark.m · re-run 2026-09-23 ▪ Every test point is for …[cut] |
| 12 | Blank | 4 | 2 | 1 | 0 | 0 | 0 | 9 Template + AR(4) owns the first three hours and loses beyond six Two-week test, clamped prices, $/MWh ▪ Best 5 min / 3 …[cut] |
| 13 | Blank | 6 | 0 | 0 | 0 | 0 | 0 | 10 Averaging over 288 leads hides the only horizon that matters Reading the baseline The two-week column is a trap Pooli …[cut] |
| 14 | Blank | 7 | 0 | 0 | 0 | 0 | 0 | Part III — The AEMO error model Forecast their residual, not their problem |
| 15 | Blank | 11 | 5 | 0 | 0 | 0 | 0 | 11 We do not need to beat AEMO — we need to correct them The brief, restated with the symbols the professor asked for De …[cut] |
| 16 | Blank | 6 | 0 | 1 | 0 | 0 | 0 | 12 The pairing had to be rebuilt from the NEMWEB archive The current feed keeps only two days, which is not a dataset Pa …[cut] |
| 17 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 13 AEMO's 5-minute forecast is good — and it degrades fast P5 error against realised dispatch price, VIC1 ▪ RMSE climbs  …[cut] |
| 18 | Blank | 3 | 1 | 0 | 0 | 0 | 0 | 14 The error is not noise: it arrives in runs ▪ ACF of the realised error ε(k): +0.50 at lag 1, +0.48 at lag 2, still +0 …[cut] |
| 19 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 15 No single candidate wins the hour: persistence takes 5–10 min, T+AR(4) takes the rest Five candidates on a held-out 3 …[cut] |
| 20 | Blank | 4 | 0 | 1 | 0 | 0 | 0 | 16 Short-lead table, all four candidates, by lead Test split · RMSE and MAE in $/MWh ▪ gain = RMSE change relative to ra …[cut] |
| 21 | Blank | 4 | 0 | 0 | 0 | 0 | 0 | 17 What the error study says, and what it does not Established▪ AEMO's P5 error is strongly autocorrelated and arrives i …[cut] |
| 22 | Blank | 8 | 0 | 0 | 0 | 0 | 0 | Next ● Raise the forecast retention so the live store, not a backfill, feeds the error model. ● Extend the error study t …[cut] |

### Every picture on every slide

`descr` is the alt text stored on the picture; `null` means the attribute is absent. It is reported because in these decks it carries the source file name.

| Slide | Shape name | Alt text (descr) | Width EMU | Height EMU | Left EMU | Top EMU | Pixel size | Bytes |
|---|---|---|---|---|---|---|---|---|
| 6 | Picture 6 | F1_monthly_vs_archive_vic1.png | 3431689 | 2651760 | 7268135 | 3566160 | 1430x1105 | 234655 |
| 12 | Picture 6 | E1_p5_error_by_lead_VIC1.png | 4343400 | 1539932 | 7315200 | 1973233 | 1430x507 | 54626 |
| 12 | Picture 7 | bench_rmse_slot.png | 4343400 | 1734870 | 7315200 | 4298924 | 1745x697 | 203771 |
| 15 | Picture 6 | f_f45a3351.png | 384048 | 214884 | 502920 | 2011680 | 252x141 | 5511 |
| 15 | Picture 8 | f_c162afcb.png | 179832 | 214884 | 502920 | 2537460 | 118x141 | 2515 |
| 15 | Picture 10 | f_5d74415c.png | 1019556 | 245363 | 502920 | 3063240 | 669x161 | 12362 |
| 15 | Picture 13 | f_0918b145.png | 2388108 | 245363 | 502920 | 4168140 | 1567x161 | 25674 |
| 15 | Picture 15 | f_2f46ae59.png | 2886456 | 246888 | 502920 | 4724400 | 1894x162 | 33877 |
| 17 | Picture 4 | E1_p5_error_by_lead_VIC1.png | 8510953 | 3017520 | 1825283 | 1417320 | 1430x507 | 54626 |
| 18 | Picture 4 | E2_error_predictability_VIC1.png | 8768861 | 3108960 | 1696329 | 1417320 | 1430x507 | 49975 |
| 19 | Picture 4 | C1_four_way_short_lead.png | 9026769 | 3200400 | 1567375 | 1417320 | 1430x507 | 78496 |

### Equations or symbols stored as images rather than text

The package contains no OLE equation objects (`oleObject` parts): every graphic in this deck is a PNG. The question is therefore whether formulas are *drawn as* pictures. Two kinds of evidence bear on it, and they are reported separately because they carry different weight.

- Total pictures: 11. Pictures under 1200000 EMU (about 1.3 inch) tall: 5.
- Short-picture heights in descending frequency: 214884 EMU x2 (slides [15]); 245363 EMU x2 (slides [15]); 246888 EMU x1 (slides [15]).
- Short pictures sharing an identical width and height, which indicates one rendering pipeline rather than hand-placed screenshots: none.
- No picture in this deck carries alt text naming a mathematical quantity.

Deck-specific reading.

Deck 2 makes the distinction visible. Ten of its eleven pictures carry a descriptive source name such as `bench_rmse_slot.png` or `E1_p5_error_by_lead_VIC1.png`, which identifies them as exported figures. The remaining five, all on slide 15, carry hashed names of the form `f_<hex>.png` (`f_f45a3351.png`, `f_c162afcb.png`, `f_5d74415c.png`, `f_0918b145.png`, `f_2f46ae59.png`) and are short strips 214884 to 246888 EMU tall placed inline with the run text. Two naming conventions in one deck, and the hashed family is the one that behaves like rendered inline math rather than an exported chart.

Caveat: this is a structural and naming test. It reports the height distribution, the repeated exact dimensions, and the alt-text naming conventions. It does not decode any image, so the classification of a given strip as an equation rests on that structural evidence, not on reading its pixels.

## Deck 3 — `C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Predicitor.pptx`

- Absolute path: `C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Predicitor.pptx`
- File size: 2543933 bytes
- Slide count: 10
- Slide width: 12192000 EMU
- Slide height: 6858000 EMU
- Aspect ratio: 16:9 (= 1.7778)
- `ppt/presentation.xml` slide size element: `<p:sldSz cx="12192000" cy="6858000"/>`
- Notes slides in package: 0

### Slide layouts used

These are the layouts the slides actually reference, out of 11 layouts present in the master.

- Title Slide

### Slide master names and background fill

- Master `ppt/slideMasters/slideMaster1.xml`: the `p:cSld` element carries no `name` attribute, so the master is unnamed in the file. python-pptx reports its `name` as the empty string.
  - Background fill declared on the master: `p:cSld > p:bg > p:bgRef idx=1001 > a:schemeClr val=bg1`.
  - No slide layout in this deck declares its own `p:bg`, and no slide declares one either, so the master background is what every slide inherits.

### Theme font scheme

- Part `ppt/theme/theme1.xml`
  - `a:majorFont` latin typeface: 等线 Light
  - `a:minorFont` latin typeface: 等线
  - `a:majorFont` east-asian typeface: (no `a:ea` element declared)
  - `a:minorFont` east-asian typeface: (no `a:ea` element declared)

### Slide titles in order

1. (no title placeholder) — largest-font text: (no text on this slide)
2. (no title placeholder) — largest-font text: (no text on this slide)
3. (no title placeholder) — largest-font text: (no text on this slide)
4. (no title placeholder) — largest-font text: (no text on this slide)
5. (no title placeholder) — largest-font text: (no text on this slide)
6. (no title placeholder) — largest-font text: NEMPRICEANDDEMAND_NSW1_202609101245
7. (no title placeholder) — largest-font text: (no text on this slide)
8. (no title placeholder) — largest-font text: (no text on this slide)
9. (no title placeholder) — largest-font text: (no text on this slide)
10. (no title placeholder) — largest-font text: (no text on this slide)

### Per-slide content summary

| Slide | Layout | Text frames | Pictures | Tables | Charts | Groups | Runs without explicit size | First 120 chars of concatenated text |
|---|---|---|---|---|---|---|---|---|
| 1 | Title Slide | 2 | 5 | 0 | 0 | 0 | 0 | (no text) |
| 2 | Title Slide | 2 | 3 | 0 | 0 | 0 | 0 | (no text) |
| 3 | Title Slide | 2 | 3 | 0 | 0 | 0 | 0 | (no text) |
| 4 | Title Slide | 2 | 3 | 0 | 0 | 0 | 0 | (no text) |
| 5 | Title Slide | 2 | 5 | 0 | 0 | 0 | 0 | (no text) |
| 6 | Title Slide | 3 | 2 | 0 | 0 | 0 | 1 | NEMPRICEANDDEMAND_NSW1_202609101245 |
| 7 | Title Slide | 2 | 2 | 0 | 0 | 0 | 0 | (no text) |
| 8 | Title Slide | 2 | 0 | 0 | 0 | 0 | 0 | (no text) |
| 9 | Title Slide | 2 | 0 | 0 | 0 | 0 | 0 | (no text) |
| 10 | Title Slide | 2 | 0 | 0 | 0 | 0 | 0 | (no text) |

### Equations or symbols stored as images rather than text

- Total pictures: 23. Pictures under 1200000 EMU tall: 2.
- Pictures whose alt text is exactly a mathematical quantity name: 0.
Deck 3 carries no alt text on any picture, and all 23 of its pictures are full-size screenshots between 1299118 and 6858000 EMU tall, with no short inline strips at all. Its symbols, if any, are inside those screenshots and cannot be separated from them by structure. Note also that this deck has almost no text of its own, so imagery is its only content channel.

Caveat: the count above rests on alt text naming, so an unnamed formula image would not be counted here.

## Deck 4 — `C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-08\deck\Capstone_Forecasting_v1.pptx`

- Absolute path: `C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-08\deck\Capstone_Forecasting_v1.pptx`
- File size: 5394488 bytes
- Slide count: 22
- Slide width: 12191695 EMU
- Slide height: 6858000 EMU
- Aspect ratio: 2438339:1371600 (= 1.7777)
- `ppt/presentation.xml` slide size element: `<p:sldSz cx="12191695" cy="6858000" type="screen4x3"/>` (carries `type="screen4x3"`, which disagrees with the 16:9 geometry)
- Notes slides in package: 0

### Slide layouts used

These are the layouts the slides actually reference, out of 11 layouts present in the master.

- Blank

### Slide master names and background fill

- Master `ppt/slideMasters/slideMaster1.xml`: the `p:cSld` element carries no `name` attribute, so the master is unnamed in the file. python-pptx reports its `name` as the empty string.
  - Background fill declared on the master: `p:cSld > p:bg > p:bgRef idx=1001 > a:schemeClr val=bg1`.
  - No slide layout in this deck declares its own `p:bg`, and no slide declares one either, so the master background is what every slide inherits.

### Theme font scheme

- Part `ppt/theme/theme1.xml`
  - `a:majorFont` latin typeface: Calibri
  - `a:minorFont` latin typeface: Calibri
  - `a:majorFont` east-asian typeface: (no `a:ea` element declared)
  - `a:minorFont` east-asian typeface: (no `a:ea` element declared)

### Slide titles in order

1. (no title placeholder) — largest-font text: 把 24 小时电价预测压到 42.2 $/MWh
2. (no title placeholder) — largest-font text: 预测器是数据链的第三环：抓取进 CSV 库，预测器出 288 步价，MPC 拿去排泵
3. (no title placeholder) — largest-font text: 四类数据同在一个市场却不同源：口径不先钉死，后面的误差都不可比
4. (no title placeholder) — largest-font text: 评价只认 288×288 误差图集：每格每天恰好一个样本，跨模型同格可比
5. (no title placeholder) — largest-font text: 八个模型不是八个候选：每个只靠一种信息，没有单一冠军
6. (no title placeholder) — largest-font text: 两个常量锚点是所有模型的参照系：长档是天花板，短档是地板
7. (no title placeholder) — largest-font text: Theta-y 用每槽一个标量增益修正昨天，只比 persistence 好 1.9 $/MWh
8. (no title placeholder) — largest-font text: T+AR4 短档最强、长档自毁：迭代递归把残差预测一步步推到零
9. (no title placeholder) — largest-font text: T+DMS4 换成直接多步：每个提前量各有一套系数，所以不会发散
10. (no title placeholder) — largest-font text: Carry-forward 把当前价原样搬到未来：短档极强，长档结构性失效
11. (no title placeholder) — largest-font text: Anchor-mix 让数据自己按提前量配权：七档里五档的跨槽中位数最好
12. (no title placeholder) — largest-font text: 滚动 5 分钟口径下单日形状：五个含当前价的模型已经贴住实际
13. (no title placeholder) — largest-font text: 跨 120 天看偏差：日型模型系统性高估 10 $/MWh 以上，含当前价的模型基本无偏
14. (no title placeholder) — largest-font text: 单起点一次发 288 步：八条曲线挤在 42 到 45，差别被一条日型线掩盖
15. (no title placeholder) — largest-font text: 120 个起点的定点长期能力：长档选 T+DMS4 或 Anchor-mix，CF+DMS4 半天以外失效
16. (no title placeholder) — largest-font text: J 图把失效模式画成了图片：两片封顶区与两条时段横条，比任何平均值都直白
17. (no title placeholder) — largest-font text: 旧口径热图留作对照：色标、模型集、窗口都换过了，数字不可与新图直接比
18. (no title placeholder) — largest-font text: 早期实验 1 到 3 的旧图保留原数字：模板是必需品，阶数取 3 到 4 就够
19. (no title placeholder) — largest-font text: 早期实验 4 到 5 的旧图保留原数字：更新越勤越好，分类窗口是混合结果
20. (no title placeholder) — largest-font text: AEMO 官方 P5 在新窗口重测：5 分钟 15.18、55 分钟 41.97，误差强自相关
21. (no title placeholder) — largest-font text: 把 P5 偏差项并进预测器已经测过：新窗口没有可用增益，这条路到此为止
22. (no title placeholder) — largest-font text: 首版结论：短档交给当前价锚点，长档交给模板锚点，平均值不再用来排名

### Per-slide content summary

| Slide | Layout | Text frames | Pictures | Tables | Charts | Groups | Runs without explicit size | First 120 chars of concatenated text |
|---|---|---|---|---|---|---|---|---|
| 1 | Blank | 5 | 0 | 0 | 0 | 0 | 0 | 把 24 小时电价预测压到 42.2 $/MWh 八个模型 · 一套钳位口径 · 一张 288×288 误差图集 Capstone 首版 —— 数据链、模型定义、120 天基准与 AEMO P5 误差研究 Ash Zhang · Capst …[cut] |
| 2 | Blank | 18 | 0 | 0 | 0 | 0 | 0 | 2 预测器是数据链的第三环：抓取进 CSV 库，预测器出 288 步价，MPC 拿去排泵 AEMO NEMWEB DispatchIS · P5MIN PREDISPATCHIS Python 抓取 aemo_capture.py 60 s …[cut] |
| 3 | Blank | 6 | 1 | 1 | 0 | 0 | 0 | 3 四类数据同在一个市场却不同源：口径不先钉死，后面的误差都不可比 时间口径 三个源都是 NEM 时间（AEST），时间戳是区间结束时刻，所以槽位 1 = 00:05、槽位 288 = 24:00，一天 288 个 5 分钟槽。捕获链上曾把 …[cut] |
| 4 | Blank | 6 | 2 | 0 | 0 | 0 | 0 | 4 评价只认 288×288 误差图集：每格每天恰好一个样本，跨模型同格可比 误差与两个指标的定义 逐格累积 e = 钳位目标 − 钳位预测，按 (目标槽位 s, 提前量 h, 目标天 d) 累积。每个格子每天恰好一个样本，所以同一格在不同 …[cut] |
| 5 | Blank | 4 | 0 | 1 | 0 | 0 | 0 | 5 八个模型不是八个候选：每个只靠一种信息，没有单一冠军 ▪ 表怎么读：每个格子第一行是跨 288 槽位与 120 天的合并 RMSE，方括号内是跨 288 槽位的中位数，单位 $/MWh。三个常量锚点的中位数与合并值相等或接近，因为它们不 …[cut] |
| 6 | Blank | 10 | 2 | 0 | 0 | 0 | 0 | 6 两个常量锚点是所有模型的参照系：长档是天花板，短档是地板 Persistence（昨天同槽位） 把昨天同一槽位的价搬到目标时刻。它不随提前量变化，是每个模型必须先打赢的参照。 120 天结果：5 分钟合并 RMSE 48.6、跨槽中位数 …[cut] |
| 7 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 7 Theta-y 用每槽一个标量增益修正昨天，只比 persistence 好 1.9 $/MWh ▪ 退化关系：θ(s) 初值取 1 时就精确等于 persistence；标量 RLS 在线学的是「昨天这个槽位是偏高还是偏低」。 ▪ 更 …[cut] |
| 8 | Blank | 4 | 4 | 0 | 0 | 0 | 0 | 8 T+AR4 短档最强、长档自毁：迭代递归把残差预测一步步推到零 怎么工作 模板 T 给日形状，日内 AR(4) 追当前残差水平，φ 由向量 RLS（λ = 0.98）每 5 分钟更新一次。预测时 φ 冻结，把上一步的预测值塞回缓冲。 已 …[cut] |
| 9 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 9 T+DMS4 换成直接多步：每个提前量各有一套系数，所以不会发散 ▪ 拟合方式：对每个提前量 h 单独做一次最小二乘，回归量是起点处的 r(t)、r(t−1)、r(t−2)、r(t−3)，窗口 14 天共 4032 个样本，每天 00: …[cut] |
| 10 | Blank | 4 | 2 | 0 | 0 | 0 | 0 | 10 Carry-forward 把当前价原样搬到未来：短档极强，长档结构性失效 ▪ 两个式子：CF 就是 ŷ(t+h) = y(t)，与提前量完全无关；CF+DMS4 在它上面加一层直接多步的差分修正，修正项只吃起点附近的 Δy。 ▪ 结 …[cut] |
| 11 | Blank | 5 | 2 | 1 | 0 | 0 | 0 | 11 Anchor-mix 让数据自己按提前量配权：七档里五档的跨槽中位数最好 它是什么 把当前价 y(t) 与模板 T(s+h) 当成两个锚点，连同四个残差滞后与四个差分滞后一起，对每个提前量 h 单独做直接多步拟合。a_h 是当前价的权 …[cut] |
| 12 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 12 滚动 5 分钟口径下单日形状：五个含当前价的模型已经贴住实际 一、看什么 横轴是目标槽位，一天 0 到 24 小时共 288 个 5 分钟槽；纵轴是钳位价 $/MWh。数据窗口 120 天（2026-02-01 至 06-01），本页 …[cut] |
| 13 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 13 跨 120 天看偏差：日型模型系统性高估 10 $/MWh 以上，含当前价的模型基本无偏 一、看什么 横轴是目标槽位 0 到 24 小时；纵轴是误差（预测减实际）$/MWh。120 天全部日子按槽位汇总，每个槽位 120 个样本。钳位 …[cut] |
| 14 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 14 单起点一次发 288 步：八条曲线挤在 42 到 45，差别被一条日型线掩盖 一、看什么 横轴是离发起点的步数 0 到 24 小时；纵轴是钳位价 $/MWh。窗口同为 120 天（2026-02-01 至 06-01）。本页只有一个发 …[cut] |
| 15 | Blank | 6 | 1 | 1 | 0 | 0 | 0 | 15 120 个起点的定点长期能力：长档选 T+DMS4 或 Anchor-mix，CF+DMS4 半天以外失效 逐个提前量的定点 RMSE（$/MWh），h = 1/6/12/36/72/144/288 步： T+AR4 8.8 / 12 …[cut] |
| 16 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 16 J 图把失效模式画成了图片：两片封顶区与两条时段横条，比任何平均值都直白 一、看什么 行是目标时刻（一天 24 小时，288 槽），列是提前量（0 到 24 小时，288 步），颜色是 RMSE，单位 $/MWh。窗口 120 天（2 …[cut] |
| 17 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 17 旧口径热图留作对照：色标、模型集、窗口都换过了，数字不可与新图直接比 一、看什么 六个面板分别是 Persistence、Template、Theta-y、T+AR(4)、Blend A、Blend B。行是目标槽位（0 到 24 小 …[cut] |
| 18 | Blank | 9 | 3 | 0 | 0 | 0 | 0 | 18 早期实验 1 到 3 的旧图保留原数字：模板是必需品，阶数取 3 到 4 就够 实验 1 · AR vs AR + 模板（A 第 9 页） 看什么 六个子图：左列实际对预测，右列逐点误差；横轴 2026-02-01 至 02-07，纵 …[cut] |
| 19 | Blank | 7 | 2 | 0 | 0 | 0 | 0 | 19 早期实验 4 到 5 的旧图保留原数字：更新越勤越好，分类窗口是混合结果 实验 4 · 更新间隔（A 物理第 13 页） 看什么 三个子图：按提前量的 RMSE（对数横轴）、按小时的 RMSE、总体 RMSE 柱状图；纯 AR(4)， …[cut] |
| 20 | Blank | 4 | 1 | 1 | 0 | 0 | 0 | 20 AEMO 官方 P5 在新窗口重测：5 分钟 15.18、55 分钟 41.97，误差强自相关 窗口与面板 2026-08-25 至 2026-10-06，平衡面板 12373 起点 / 148476 行，原始价，VIC1。旧值对照来 …[cut] |
| 21 | Blank | 4 | 1 | 0 | 0 | 0 | 0 | 21 把 P5 偏差项并进预测器已经测过：新窗口没有可用增益，这条路到此为止 ▪ 样本外增益：加 P5 偏差项后的增益区间是 -4.3% 到 +2.7%，斜率多为负——也就是加进去的次数里，变差的比变好的多。 ▪ 解释力随提前量塌掉：P5  …[cut] |
| 22 | Blank | 7 | 0 | 0 | 0 | 0 | 0 | 22 首版结论：短档交给当前价锚点，长档交给模板锚点，平均值不再用来排名 ▪ 短档（1 小时以内）用 Anchor-mix 或 Carry-forward 这一类含当前价的模型。5 分钟合并 RMSE 9.9 对 persistence 的 …[cut] |

### Equations or symbols stored as images rather than text

- Total pictures: 28. Pictures under 1200000 EMU tall: 17.
- Pictures whose alt text is exactly a mathematical quantity name: 17.
- Those images: slide 3 `clamp.png`, slide 4 `mse.png`, slide 4 `rmse.png`, slide 6 `persistence.png`, slide 6 `template.png`, slide 7 `theta.png`, slide 8 `ar4.png`, slide 8 `iterated.png`, slide 8 `tplusar.png`, slide 8 `decay.png`, slide 9 `dms.png`, slide 10 `cf.png`, slide 10 `cfdms.png`, slide 11 `anchor1.png`, slide 11 `anchor2.png`, slide 20 `p5_error.png`, slide 21 `p5_correct.png`.

The formula images in this deck are named by quantity and are all small strips, while the large pictures are named by figure letter (`D.png`, `G.png`, `H.png`, `I.png`, `J.png`) or by experiment (`exp1.png` through `exp5.png`). The two populations are therefore separable by name as well as by geometry. Full detail is given in the Deck 1 and Deck 2 sections above, which carry the complete picture tables.

Caveat: the count above rests on alt text naming, so an unnamed formula image would not be counted here.

## Union of distinct font sizes in text runs, all four decks

A font size here is the explicit `sz` attribute of a text run. Counts cover normal slide shapes only, including runs inside grouped shapes and chart titles and axis titles. Runs that carry no explicit size, and therefore inherit from the layout, master, or theme, cannot contribute a size and are reported separately per deck below.

| Font size (EMU) | Points | Runs |
|---|---|---|
| 508000 | 40.0 | 3 |
| 482600 | 38.0 | 1 |
| 457200 | 36.0 | 1 |
| 431800 | 34.0 | 5 |
| 342900 | 27.0 | 40 |
| 330200 | 26.0 | 21 |
| 279400 | 22.0 | 1 |
| 254000 | 20.0 | 23 |
| 228600 | 18.0 | 18 |
| 215900 | 17.0 | 2 |
| 203200 | 16.0 | 40 |
| 190500 | 15.0 | 124 |
| 184150 | 14.5 | 7 |
| 177800 | 14.0 | 424 |
| 171450 | 13.5 | 112 |
| 165100 | 13.0 | 105 |
| 158750 | 12.5 | 53 |
| 152400 | 12.0 | 26 |
| 146050 | 11.5 | 15 |
| 139700 | 11.0 | 28 |
| 133350 | 10.5 | 5 |
| 127000 | 10.0 | 64 |
| **total** | | **1118** |

Distinct sizes: 22.

### Per-deck breakdown

| Font size (EMU) | Points | Deck 1 | Deck 2 | Deck 3 | Deck 4 |
|---|---|---|---|---|---|
| 508000 | 40.0 | 2 | 1 | 0 | 0 |
| 482600 | 38.0 | 0 | 0 | 0 | 1 |
| 457200 | 36.0 | 1 | 0 | 0 | 0 |
| 431800 | 34.0 | 1 | 4 | 0 | 0 |
| 342900 | 27.0 | 23 | 17 | 0 | 0 |
| 330200 | 26.0 | 0 | 0 | 0 | 21 |
| 279400 | 22.0 | 0 | 0 | 0 | 1 |
| 254000 | 20.0 | 23 | 0 | 0 | 0 |
| 228600 | 18.0 | 1 | 17 | 0 | 0 |
| 215900 | 17.0 | 1 | 1 | 0 | 0 |
| 203200 | 16.0 | 7 | 11 | 0 | 22 |
| 190500 | 15.0 | 124 | 0 | 0 | 0 |
| 184150 | 14.5 | 7 | 0 | 0 | 0 |
| 177800 | 14.0 | 48 | 104 | 0 | 272 |
| 171450 | 13.5 | 112 | 0 | 0 | 0 |
| 165100 | 13.0 | 83 | 22 | 0 | 0 |
| 158750 | 12.5 | 53 | 0 | 0 | 0 |
| 152400 | 12.0 | 26 | 0 | 0 | 0 |
| 146050 | 11.5 | 15 | 0 | 0 | 0 |
| 139700 | 11.0 | 0 | 28 | 0 | 0 |
| 133350 | 10.5 | 5 | 0 | 0 | 0 |
| 127000 | 10.0 | 19 | 3 | 0 | 42 |

### Runs with no explicit size

| Deck | Total runs | Runs with explicit size | Runs with no explicit size |
|---|---|---|---|
| 1 | 551 | 551 | 0 |
| 2 | 208 | 208 | 0 |
| 3 | 1 | 0 | 1 |
| 4 | 359 | 359 | 0 |

Deck 3 (`Predicitor.pptx`) contains exactly one text run in the whole deck, the string `NEMPRICEANDDEMAND_NSW1_202609101245` on slide 6, and that run has no explicit size. Deck 3 therefore contributes no rows of its own to the union above; its visible content is delivered entirely by 23 embedded PNG images.
