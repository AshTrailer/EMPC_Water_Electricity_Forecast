# -*- coding: utf-8 -*-
"""
Build the capstone presentation: electricity-price forecasting for EMPC.
Renders a 16:9 deck with python-pptx. Run: .venv/Scripts/python.exe build_deck.py
"""
import os
import re
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from PIL import Image

# ---------------------------------------------------------------------------
# palette + type
# ---------------------------------------------------------------------------
DARK   = "14213D"   # deep navy (title / section / conclusion)
NAVY   = "1E2761"
TEAL   = "0E7C7B"
AMBER  = "E9A820"   # energy accent
ICE    = "EAF1F8"   # light card
ICE2   = "F4F8FB"   # lighter panel
INK    = "1B2430"   # body text
MUTED  = "5A6B7B"   # captions
WHITE  = "FFFFFF"
LINE   = "C9D4DE"
GOOD   = "1E7A46"   # green for "best"
BAD    = "B03A2E"   # red for "worse"

HDR  = "Cambria"
BODY = "Calibri"

ROOT = os.path.dirname(os.path.abspath(__file__))
FIG  = os.path.join(ROOT, "Simulation_Log", "figures_png")

prs = Presentation()
prs.slide_width  = Inches(13.333)
prs.slide_height = Inches(7.5)
BLANK = prs.slide_layouts[6]

# ---------------------------------------------------------------------------
# low-level helpers
# ---------------------------------------------------------------------------
def _rgb(h):
    return RGBColor.from_string(h)


def _set_fill(shape, color):
    shape.fill.solid()
    shape.fill.fore_color.rgb = _rgb(color)
    shape.line.fill.background()


def _no_fill(shape):
    shape.fill.background()
    shape.line.fill.background()


def _set_line(shape, color, w_pt=0.75):
    shape.line.color.rgb = _rgb(color)
    shape.line.width = Pt(w_pt)
    shape.fill.background()


def add_rect(slide, x, y, w, h, fill=None, line=None, line_w=0.75, shape=MSO_SHAPE.RECTANGLE, radius=None):
    s = slide.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
    if fill is None:
        _no_fill(s)
    else:
        _set_fill(s, fill)
        if line is not None:
            s.line.color.rgb = _rgb(line)
            s.line.width = Pt(line_w)
    if radius is not None and shape == MSO_SHAPE.ROUNDED_RECTANGLE:
        try:
            s.adjustments[0] = radius
        except Exception:
            pass
    s.shadow.inherit = False
    return s


def add_run(p, text, font=BODY, size=14, color=INK, bold=False, italic=False, sub=False, sup=False):
    r = p.add_run()
    r.text = text
    f = r.font
    f.name = font
    f.size = Pt(size)
    f.color.rgb = _rgb(color)
    f.bold = bold
    f.italic = italic
    if sub or sup:
        rPr = r._r.get_or_add_rPr()
        rPr.set("baseline", "-25000" if sub else "30000")
    return r


_TOK = re.compile(r"(~[^~\n]+~|\^[^\^\n]+\^)")


def add_math(p, text, font=HDR, size=14, color=INK, bold=False):
    """Mini markup: ~x~ subscript, ^x^ superscript."""
    for part in _TOK.split(text):
        if part == "":
            continue
        if len(part) >= 3 and part[0] == "~" and part[-1] == "~":
            add_run(p, part[1:-1], font, size, color, bold, sub=True)
        elif len(part) >= 3 and part[0] == "^" and part[-1] == "^":
            add_run(p, part[1:-1], font, size, color, bold, sup=True)
        else:
            add_run(p, part, font, size, color, bold)


def textbox(slide, x, y, w, h, anchor=MSO_ANCHOR.TOP):
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = 0
    tf.margin_right = 0
    tf.margin_top = 0
    tf.margin_bottom = 0
    return tb, tf


def para(tf, first=False):
    return tf.paragraphs[0] if first else tf.add_paragraph()


def bullets(slide, x, y, w, h, items, size=14, gap=6, color=INK, bold_first=False):
    """items: list of strings (math markup allowed) or (text, opts) tuples."""
    tb, tf = textbox(slide, x, y, w, h)
    for i, it in enumerate(items):
        p = para(tf, i == 0)
        p.space_after = Pt(gap)
        if isinstance(it, tuple):
            txt, kw = it
        else:
            txt, kw = it, {}
        add_run(p, "•  ", size=size, color=kw.get("bullet_color", TEAL), bold=True)
        add_math(p, txt, size=kw.get("size", size), color=kw.get("color", color),
                 bold=kw.get("bold", False) or (bold_first and i == 0))
    return tb


def header(slide, num, title, subtitle=None, title_size=27):
    """Content-slide header: number chip + title + optional subtitle."""
    chip = add_rect(slide, 0.55, 0.42, 0.52, 0.52, fill=NAVY, shape=MSO_SHAPE.OVAL)
    ctf = chip.text_frame
    ctf.word_wrap = False
    ctf.margin_left = 0; ctf.margin_right = 0; ctf.margin_top = 0; ctf.margin_bottom = 0
    cp = ctf.paragraphs[0]; cp.alignment = PP_ALIGN.CENTER
    add_run(cp, str(num), font=HDR, size=20, color=WHITE, bold=True)
    tb, tf = textbox(slide, 1.25, 0.34, 11.5, 0.7, anchor=MSO_ANCHOR.MIDDLE)
    p = para(tf, True)
    add_run(p, title, font=HDR, size=title_size, color=INK, bold=True)
    if subtitle:
        p2 = tf.add_paragraph()
        add_run(p2, subtitle, font=BODY, size=12.5, color=MUTED)
    return tf


def footnote(slide, text, x=0.55, y=7.02, w=12.2):
    tb, tf = textbox(slide, x, y, w, 0.4)
    p = para(tf, True)
    add_run(p, text, size=10, color=MUTED, italic=True)


def ring_motif(slide, cx, cy, rmax, color, n=3):
    """Recurring 'signal ripple' motif: concentric circle outlines."""
    for i in range(n):
        r = rmax * (1 - 0.3 * i)
        c = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(cx - r), Inches(cy - r),
                                   Inches(2 * r), Inches(2 * r))
        c.fill.background()
        c.line.color.rgb = _rgb(color)
        c.line.width = Pt(1.1)
        c.shadow.inherit = False


# ---------------------------------------------------------------------------
# table helper
# ---------------------------------------------------------------------------
def table(slide, x, y, w, h, data, col_w=None, font_size=11, header_fill=NAVY,
          header_color=WHITE, align_first_left=True, zebra=True, row_h=0.32,
          first_col_bold=False, first_col_color=None, cell_colors=None):
    rows, cols = len(data), len(data[0])
    gtbl = slide.shapes.add_table(rows, cols, Inches(x), Inches(y), Inches(w), Inches(h))
    tbl = gtbl.table
    tbl.first_row = False
    tbl.horz_banding = False
    if col_w:
        tot = sum(col_w)
        for c, cw in enumerate(col_w):
            tbl.columns[c].width = Emu(int(Inches(w) * cw / tot))
    for r in range(rows):
        tbl.rows[r].height = Inches(row_h if r > 0 else row_h + 0.06)
        for c in range(cols):
            cell = tbl.cell(r, c)
            cell.margin_left = Inches(0.06)
            cell.margin_right = Inches(0.06)
            cell.margin_top = Inches(0.02)
            cell.margin_bottom = Inches(0.02)
            cell.vertical_anchor = MSO_ANCHOR.MIDDLE
            tf = cell.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            val = data[r][c]
            is_header = (r == 0)
            if is_header:
                cell.fill.solid(); cell.fill.fore_color.rgb = _rgb(header_fill)
                cell_color = header_color
                bold = True
            else:
                cell.fill.solid()
                cell.fill.fore_color.rgb = _rgb(WHITE if (not zebra or r % 2 == 1) else ICE2)
                cell_color = INK
                bold = False
            if cell_colors is not None and not is_header:
                cc = cell_colors.get((r, c))
                if cc:
                    cell_color = cc
                    bold = True
            if not is_header and first_col_bold and c == 0:
                bold = True
                if first_col_color:
                    cell_color = first_col_color
            left = (c == 0) if align_first_left else True
            p.alignment = PP_ALIGN.LEFT if left else PP_ALIGN.CENTER
            add_run(p, str(val), font=BODY, size=font_size, color=cell_color, bold=bold)
    return gtbl


def fit_image(slide, path, x, y, w, h):
    """Place an image scaled to fit (w, h), preserving aspect, centered."""
    im = Image.open(path)
    iw, ih = im.size
    ar = iw / ih
    bw, bh = w / ar, h * ar
    if bh <= h:            # height-limited -> use full height
        tw, th = bh * ar, h
    else:                  # width-limited -> use full width
        tw, th = w, bw
    tw = min(tw, w); th = min(th, h)
    px = x + (w - tw) / 2
    py = y + (h - th) / 2
    slide.shapes.add_picture(path, Inches(px), Inches(py), Inches(tw), Inches(th))


def figname(n):
    return os.path.join(FIG, n)


# ===========================================================================
# SLIDES
# ===========================================================================

# ---- 1. Title (dark) ----
s = prs.slides.add_slide(BLANK)
add_rect(s, 0, 0, 13.333, 7.5, fill=DARK)
ring_motif(s, 11.3, 1.1, 1.5, TEAL, 3)
ring_motif(s, 10.2, 1.1, 0.55, AMBER, 2)
tb, tf = textbox(s, 0.9, 2.0, 11.5, 2.9)
p = para(tf, True)
add_run(p, "Electricity Price Forecasting for Economic MPC", font=HDR, size=40, color=WHITE, bold=True)
p2 = tf.add_paragraph()
add_run(p2, "of Water Pumping Systems", font=HDR, size=40, color=WHITE, bold=True)
p3 = tf.add_paragraph()
p3.space_before = Pt(14)
add_run(p3, "From AR + RLS to a six-model predictor suite — data, models, and benchmark results",
        font=BODY, size=18, color="CADCFC")
tb, tf = textbox(s, 0.9, 6.2, 11.5, 0.9)
p = para(tf, True)
add_run(p, "AEMO NEM market data  ·  MATLAB  ·  Python data capture", font=BODY, size=14, color="9FB3C8")
p2 = tf.add_paragraph()
add_run(p2, "Ash Trailer  ·  Capstone Project  ·  2026-09-15", font=BODY, size=13, color="9FB3C8")

# ---- 2. System context / workflow ----
s = prs.slides.add_slide(BLANK)
header(s, 1, "Project workflow and where forecasting fits", "Wholesale spot price varies every 5 min — EMPC shifts pumping to cheap periods using forecasts")
# pipeline
stages = ["AEMO market\ndispatch / pre-dispatch", "Data capture\n(Python)", "AEMO_Data\nCSV store", "Price predictor\n(short / long-term)", "EMPC\n(MPC layer)", "Water supply\nsystem"]
n = len(stages)
x0, y0, bw, bh, gap = 0.55, 1.75, 1.82, 1.5, 0.24
for i, st in enumerate(stages):
    x = x0 + i * (bw + gap)
    box = add_rect(s, x, y0, bw, bh, fill=NAVY if i in (3,) else ICE, line=LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.12)
    tfc = box.text_frame; tfc.word_wrap = True
    tfc.margin_left = Inches(0.06); tfc.margin_right = Inches(0.06)
    tfc.margin_top = Inches(0.06); tfc.margin_bottom = Inches(0.06)
    pc = tfc.paragraphs[0]; pc.alignment = PP_ALIGN.CENTER
    add_run(pc, st, size=11.5, color=WHITE if i == 3 else INK, bold=(i == 3))
    if i < n - 1:
        ar = slide_arrow = add_rect(s, x + bw + 0.01, y0 + bh / 2 - 0.12, gap - 0.02, 0.24, fill=AMBER, shape=MSO_SHAPE.RIGHT_ARROW)
tb, tf = textbox(s, 0.55, 3.55, 12.2, 2.6)
p = para(tf, True)
add_run(p, "The predictor is one link in a closed loop:", font=BODY, size=14, color=INK, bold=True)
bullets(s, 0.55, 3.9, 12.2, 2.4, [
    "MPC (tank-level optimisation) decides, over a receding horizon, how much total inflow the tanks need and when.",
    "Decision (pump-combination optimisation) picks which pumps to run to deliver that inflow at minimum cost.",
    "The price forecast feeds both layers; the control step and the spot price are aligned at 5 minutes.",
], size=13.5)
footnote(s, "Time scales: spot price + control step = 5 min; AEMO pre-dispatch forecast = 30-min grid, 48 h look-ahead.")

# ---- 3. Data source: AEMO monthly files ----
s = prs.slides.add_slide(BLANK)
header(s, 2, "Data source — AEMO monthly price & demand files", "Historical data: one CSV per region-month, publicly available from AEMO")
tb, tf = textbox(s, 0.55, 1.35, 12.2, 0.5)
p = para(tf, True)
add_run(p, "Files: ", font=BODY, size=14, color=INK, bold=True)
add_run(p, "PRICE_AND_DEMAND_202601_VIC1.csv … PRICE_AND_DEMAND_202608_VIC1.csv", font=BODY, size=14, color=INK)
# sample table
sample = [
    ["REGION", "SETTLEMENTDATE", "TOTALDEMAND", "RRP", "PERIODTYPE"],
    ["VIC1", "2026/01/01 00:05:00", "4188.23", "58.51", "TRADE"],
    ["VIC1", "2026/01/01 00:10:00", "4169.89", "25.66", "TRADE"],
    ["VIC1", "2026/01/01 00:15:00", "4143.35", "21.31", "TRADE"],
]
table(s, 0.55, 1.95, 9.4, 1.9, sample, col_w=[1.1, 2.6, 1.6, 1.1, 1.4], font_size=11.5)
bullets(s, 0.55, 4.2, 12.2, 2.4, [
    "RRP (Regional Reference Price, $/MWh) is the only column used as the electricity-price signal.",
    "5-minute resolution: 288 slots per day; used for train / test splits and all predictor experiments.",
    "Loaded via load_aemo_data(): returns time (datetime) and price vectors across the whole history.",
], size=13.5)
footnote(s, "Data range used in the benchmark: 2026-01-01 00:05 → 2026-08-09 00:00 (63,360 points, 5-min).")

# ---- 4. Automated capture (Python) ----
s = prs.slides.add_slide(BLANK)
header(s, 3, "Automated AEMO capture — Python (nemweb.com.au)", "Replaces manual monthly downloads with a continuous fetch of current NEM reports")
cards = [
    ("DispatchIS_Reports", "Actual prices", "Realised 5-min dispatch prices (RRP). NEMWEB keeps ~2 days; gaps refilled on startup."),
    ("PredispatchIS_Reports", "30-min forecast", "Official 30-min pre-dispatch forecast (RRP, ~48 h ahead)."),
    ("P5_Reports", "5-min forecast", "Official 5-min P5 forecast (RRP)."),
]
x0, y0, cw, ch, gap = 0.55, 1.5, 3.95, 2.1, 0.2
for i, (name, tag, desc) in enumerate(cards):
    x = x0 + i * (cw + gap)
    card = add_rect(s, x, y0, cw, ch, fill=ICE, line=LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.08)
    tfc = card.text_frame; tfc.word_wrap = True
    tfc.margin_left = Inches(0.16); tfc.margin_right = Inches(0.16)
    tfc.margin_top = Inches(0.14); tfc.margin_bottom = Inches(0.1)
    p = tfc.paragraphs[0]
    add_run(p, name, font=HDR, size=15, color=NAVY, bold=True)
    p2 = tfc.add_paragraph(); p2.space_before = Pt(2)
    add_run(p2, tag, font=BODY, size=12, color=AMBER, bold=True)
    p3 = tfc.add_paragraph(); p3.space_before = Pt(6)
    add_run(p3, desc, font=BODY, size=11.5, color=INK)
tb, tf = textbox(s, 0.55, 3.95, 12.2, 0.5)
p = para(tf, True)
add_run(p, "Module architecture", font=BODY, size=14, color=INK, bold=True)
mods = ["aemo_config.py\npaths · retention · URLs", "aemo_common.py\ntime · listing · download", "aemo_parser.py\nrecord parsing (C/I/D)", "aemo_store.py\nappend + evict + dedup", "aemo_capture.py\norchestration loop"]
x0, y0, bw, bh, gap = 0.55, 4.4, 2.35, 1.15, 0.16
for i, m in enumerate(mods):
    x = x0 + i * (bw + gap)
    box = add_rect(s, x, y0, bw, bh, fill=NAVY, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.1)
    tfc = box.text_frame; tfc.word_wrap = True
    tfc.margin_left = Inches(0.08); tfc.margin_right = Inches(0.08)
    tfc.margin_top = Inches(0.08); tfc.margin_bottom = Inches(0.08)
    pc = tfc.paragraphs[0]; pc.alignment = PP_ALIGN.CENTER
    add_run(pc, m, size=10.5, color=WHITE)
    if i < len(mods) - 1:
        add_rect(s, x + bw + 0.0, y0 + bh / 2 - 0.1, gap, 0.2, fill=AMBER, shape=MSO_SHAPE.RIGHT_ARROW)
bullets(s, 0.55, 5.85, 12.2, 1.1, [
    "Continuous loop (default 60 s): one pass over all three listings, download zips, parse, merge, dedup, evict.",
    "State (capture_state.json) tracks processed files + generation numbers to avoid re-downloading revisions.",
], size=12.5)
footnote(s, "Future: schedule/update the capture automatically with GitHub Actions.")

# ---- 5. Capture stores & retention ----
s = prs.slides.add_slide(BLANK)
header(s, 4, "Capture stores, retention and dedup", "Three append-only / batch-retention CSV stores under AEMO_Data")
rows = [
    ["Store file", "Content", "Retention policy"],
    ["dispatch_actual.csv", "Realised 5-min prices (RRP, EEP, demand)", "Append forever; gaps back-filled ~2 days"],
    ["predispatch_forecast.csv", "30-min pre-dispatch forecasts", "Keep last 10 runs (~5 h)"],
    ["p5min_forecast.csv", "5-min P5 forecasts", "Keep last 60 runs (~5 h)"],
]
table(s, 0.55, 1.5, 12.2, 2.1, rows, col_w=[2.6, 4.4, 3.4], font_size=12.5, first_col_bold=True, first_col_color=NAVY)
bullets(s, 0.55, 4.0, 12.2, 2.6, [
    "Dedup keeps the highest RUNNO per interval/region (the last successful market solve).",
    "Forecast stores keep only the latest N batches; older batches are evicted automatically.",
    "Zip cache + state bookkeeping are pruned to bound disk usage; all timestamps normalised to AU local time.",
    "This design feeds both the offline experiments (monthly CSV) and, going forward, live on-line forecasting.",
], size=13.5)
footnote(s, "Regions tracked: NSW1, QLD1, SA1, TAS1, VIC1.")

# ---- 6. RLS AR(p) filter ----
s = prs.slides.add_slide(BLANK)
header(s, 5, "Core building block — adaptive RLS AR(p) filter", "apply_rls_filter.m — estimates AR coefficients online with forgetting")
tb, tf = textbox(s, 0.55, 1.4, 12.2, 1.15)
p = para(tf, True)
add_math(p, "Signal model:   y(k) = φ(k)^T^θ + e(k),   φ(k) = [y(k−1), …, y(k−p)]^T^  ∈ ℝ^p^", size=15, bold=False)
p2 = tf.add_paragraph(); p2.space_before = Pt(6)
add_math(p2, "φ(k): regressor vector (p latest lags)  ·  θ: AR coefficient vector (p×1)  ·  e(k): scalar innovation", size=12.5, color=MUTED)
# two columns: formulas left, guards right
tb, tf = textbox(s, 0.55, 2.7, 6.5, 3.9)
items = [
    ("1. Gain (vector):", True),
    ("K = Pφ / (λ + φ^T^Pφ)   ∈ ℝ^p^   (scalar denominator)", False),
    ("2. Prior error (scalar):", True),
    ("e = y−φ^T^θ,  e ← clip(e, ±0.5)", False),
    ("3. Weight update:", True),
    ("θ ← θ + K·e", False),
    ("4. Covariance update:", True),
    ("P ← (P − Kφ^T^P) / λ", False),
]
for i, (txt, is_lbl) in enumerate(items):
    p = para(tf, i == 0)
    p.space_after = Pt(3 if is_lbl else 8)
    add_math(p, txt, size=14, color=NAVY if is_lbl else INK, bold=is_lbl)
tb, tf = textbox(s, 7.45, 2.7, 5.4, 3.9)
p = para(tf, True)
add_run(p, "Numerical guards", font=BODY, size=14, color=INK, bold=True)
bullets(s, 7.45, 3.1, 5.4, 3.4, [
    "P~0~ = δ·I  (δ = 100),  λ = 0.98",
    "P symmetrised every step: P ← (P + P^T^)/2",
    "Ridge damping: P ← P + εI  (ε = 1e−6)",
    "Trace cap to stop P from blowing up",
    "Condition-number check → soft restart",
], size=13)
footnote(s, "λ = forgetting factor; δ = initial covariance scale. Filter output y(k) = φ(k)ᵀθ.")

# ---- 7. AR + iterated prediction ----
s = prs.slides.add_slide(BLANK)
header(s, 6, "AR(p) model and iterated multi-step prediction", "predict_ar_recursive.m — freeze coefficients, recurse forward over the horizon")
tb, tf = textbox(s, 0.55, 1.45, 12.2, 1.0)
p = para(tf, True)
add_math(p, "AR(p) on a centred series  r(t) = y(t) − μ:      r(t) = Σ~j=1..p~ φ~j~ r(t−j) + e(t)", size=15)
tb, tf = textbox(s, 0.55, 2.6, 12.2, 1.6)
p = para(tf, True)
add_math(p, "One-step-ahead:   r̂(t+1|t) = φ^T^ [r(t), r(t−1), …, r(t−p+1)]^T^", size=15)
p2 = tf.add_paragraph(); p2.space_before = Pt(6)
add_math(p2, "Iterated (recursive) h-step:   r̂(t+s|t) = φ^T^ [r̂(t+s−1|t), …, r̂(t+s−p|t)]^T^,   s = 1..h", size=15)
bullets(s, 0.55, 4.4, 12.2, 2.1, [
    "Coefficients φ are frozen during the forecast; each predicted value is fed back into the buffer.",
    "Forecast reconstruction:  ŷ(t+s|t) = μ + r̂(t+s|t)   (or, with a template,  T(s) + r̂).",
    "Without an intercept (no template), the recursion decays to 0 → pure AR can only 'chase' the short term.",
], size=13.5)
footnote(s, "RLS supplies φ; the recursion is what makes long-horizon AR forecasts collapse to the mean.")

# ---- 8. Daily template ----
s = prs.slides.add_slide(BLANK)
header(s, 7, "Daily template — the cross-day memory", "build_daily_template.m / init_ewma_state.m — a mean profile over 288 five-minute slots")
tb, tf = textbox(s, 0.55, 1.45, 12.2, 1.0)
p = para(tf, True)
add_math(p, "Pointwise mean:  T~c~(s) = (1/N) Σ~d ∈ Wc~ y~d~(s),   s = 1..288,  c ∈ {weekday, weekend}", size=15)
p2 = tf.add_paragraph(); p2.space_before = Pt(4)
add_math(p2, "y~d~(s): price at slot s on day d ·  W~c~: window of the last N days of class c ·  slot 288 = 24:00", size=12.5, color=MUTED)
bullets(s, 0.55, 2.65, 12.2, 1.9, [
    "Class split: weekday vs weekend templates, so weekend samples don't dilute the weekday mean.",
    "Rolling window rebuilds the template daily at 00:00 (7-day, 28-day, or in-class windows).",
    "Truncated EWMA: exponential weights (1−α)^k^ over in-class days, truncated at K = ⌊ln ε / ln(1−α)⌋.",
], size=13.5)
tb, tf = textbox(s, 0.55, 4.7, 12.2, 1.6)
p = para(tf, True)
add_math(p, "EWMA template:  T~c~(s) = Σ~k=0..n−1~ w~k~ p~k~(s) / Σ~k~ w~k~,    w~k~ = (1−α)^k^", size=15)
p2 = tf.add_paragraph(); p2.space_before = Pt(6)
add_math(p2, "k = 0 newest day ·  α = 0.15, ε = 0.01 → K = 28 in-class days ·  bounded buffer, no infinite memory", size=12.5, color=MUTED)
footnote(s, "get_slot_index.m maps a timestamp to slot 1..288; get_day_class.m maps to weekday/weekend.")

# ---- 9. Experiment 1 ----
s = prs.slides.add_slide(BLANK)
header(s, 8, "Experiment 1 — AR vs AR + daily template", "run_prediction_experiment.m — does a template fix the long-horizon collapse of pure AR?")
bullets(s, 0.55, 1.4, 5.6, 5.2, [
    "Protocol: daily forecast at 00:00, freeze RLS, recurse 288 steps (24 h).",
    "Three models compared:",
    "  Pure AR(4) (no template)",
    "  AR(4) + all-day template (Jan mean)",
    "  AR(4) + weekday/weekend template",
    "Train: 2026-01 (31 days). Test: 2026-02-01 → 02-07.",
    "Left column: actual vs forecast. Right column: error per horizon.",
], size=13)
fit_image(s, figname("exp1_three_models.png"), 6.3, 1.35, 6.5, 5.2)
footnote(s, "Vertical dashed lines mark 00:00 — error grows visibly within each 24-h block as horizon increases.")

# ---- 10. Experiment 1 findings ----
s = prs.slides.add_slide(BLANK)
header(s, 9, "Experiment 1 — key finding: short good, long bad", "The template supplies the daily shape; AR only helps at short lead times")
tb, tf = textbox(s, 0.55, 1.5, 12.2, 0.6)
p = para(tf, True)
add_run(p, "Why pure AR cannot forecast beyond ~6 hours:", font=BODY, size=14.5, color=INK, bold=True)
bullets(s, 0.55, 2.0, 12.2, 2.6, [
    "AR has no intercept: iterated forecasts decay geometrically toward the mean within a few hours.",
    "Adding a daily template restores the daily price shape — the forecast stays realistic out to 24 h.",
    "At very short horizons (~1 h) all models track well; at 6–24 h the template dominates the AR term.",
], size=13.5)
add_rect(s, 0.55, 4.85, 12.2, 1.6, fill=ICE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.1)
tb, tf = textbox(s, 0.85, 5.05, 11.7, 1.3)
p = para(tf, True)
add_run(p, "Takeaway: ", font=BODY, size=14, color=NAVY, bold=True)
add_run(p, "the daily template is the long-term component; the AR residual is a short-term correction. This exact split is what the later 'Template + intraday AR' predictor formalises.", font=BODY, size=14, color=INK)
footnote(s, "Exact RMSE values are in the experiment log; the figures show the actual-vs-forecast trend and the error growth with horizon.")

# ---- 11. Experiment 2 ----
s = prs.slides.add_slide(BLANK)
header(s, 10, "Experiment 2 — template window strategies", "run_prediction_experiment.m (Fig. 2) — how many days should the mean span?")
bullets(s, 0.55, 1.4, 5.6, 5.2, [
    "Three window strategies for the class-specific template:",
    "  7-day in-class rolling window",
    "  28-day in-class rolling window",
    "  Truncated EWMA (α=0.15, ε=0.01 → K=28)",
    "Class windows count weekdays and weekends separately, equalising sample counts.",
    "Longer / smoother windows track the slow daily shape better over the test week.",
], size=13)
fit_image(s, figname("exp2_window_strategies.png"), 6.3, 1.35, 6.5, 5.2)
footnote(s, "All schemes still use AR(4) + weekday/weekend template; only the window differs.")

# ---- 12. Experiment 3: AR order sweep ----
s = prs.slides.add_slide(BLANK)
header(s, 11, "Experiment 3 — AR order sweep (p = 1…10)", "run_ar_order_sweep.m — does raising the AR order help? (2026-02-01 → 02-07)")
data = [
    ["Order", "RMSE", "MAE", "1h", "3h", "6h", "12h", "24h"],
    ["AR(1)",  "51.63", "39.26", "16.48", "36.49", "53.43", "49.53", "39.81"],
    ["AR(2)",  "51.32", "39.29", "17.09", "38.14", "56.00", "48.10", "36.63"],
    ["AR(3)",  "51.04", "39.08", "16.42", "36.95", "54.40", "49.47", "34.83"],
    ["AR(4)",  "51.84", "39.51", "16.28", "36.35", "53.29", "52.62", "36.18"],
    ["AR(5)",  "52.29", "39.82", "16.18", "36.35", "53.35", "53.01", "38.87"],
    ["AR(6)",  "53.82", "41.01", "16.30", "36.95", "54.50", "53.78", "47.01"],
    ["AR(7)",  "55.81", "42.52", "16.22", "36.77", "54.19", "55.61", "56.11"],
    ["AR(8)",  "57.92", "43.90", "16.25", "36.73", "54.30", "57.16", "65.14"],
    ["AR(9)",  "59.56", "44.84", "16.03", "36.59", "54.15", "58.04", "72.59"],
    ["AR(10)", "65.29", "47.72", "16.77", "38.80", "57.32", "59.15", "94.89"],
]
table(s, 0.55, 1.45, 6.3, 5.0, data, col_w=[0.9, 1.0, 1.0, 0.9, 0.9, 0.9, 0.9, 0.9], font_size=10.5)
fit_image(s, figname("exp3_ar_order.png"), 7.0, 1.45, 5.8, 4.6)
tb, tf = textbox(s, 0.55, 6.55, 12.2, 0.5)
p = para(tf, True)
add_run(p, "Signal std = 58.0 $/MWh — RMSE near this is uninformative. Raising p gives no meaningful gain: best overall AR(3).", font=BODY, size=12, color=MUTED, italic=True)

# ---- 13. Experiment 4: update cadence ----
s = prs.slides.add_slide(BLANK)
header(s, 12, "Experiment 4 — forecast update cadence", "run_update_cadence_sweep.m — pure AR(4), how often should we re-issue the forecast?")
data = [
    ["Cadence", "Eff. horizon", "RMSE", "MAE"],
    ["5 min", "1..1", "26.8", "8.9"],
    ["30 min", "1..6", "29.2", "11.9"],
    ["1 h", "1..12", "34.1", "14.5"],
    ["6 h", "1..72", "57.2", "37.3"],
    ["24 h", "1..288", "51.8", "39.5"],
]
table(s, 0.55, 1.45, 4.2, 2.6, data, col_w=[1.0, 1.3, 1.0, 1.0], font_size=11.5)
fit_image(s, figname("exp4_update_cadence.png"), 5.0, 1.4, 7.8, 5.1)
bullets(s, 0.55, 4.35, 4.3, 2.4, [
    "More frequent updates = lower overall RMSE.",
    "Longer cadence = longer average lead time and staler RLS state.",
], size=12)
footnote(s, "24-h cadence can look good because its single 00:00 origin is the calmest part of the day (see origin-of-day table in log).")

# ---- 14. Experiment 5: template class long test ----
s = prs.slides.add_slide(BLANK)
header(s, 13, "Experiment 5 — no-split vs weekday/weekend template (89 days)", "run_template_class_long_test.m — 28-day windows, 2026-02-01 → 2026-05-01")
data = [
    ["Subset", "n", "A RMSE", "B RMSE", "A MAE", "B MAE", "A ME", "B ME"],
    ["Overall", "25632", "134.0", "278.5", "46.0", "49.2", "-9.3", "12.9"],
    ["Weekdays", "18432", "149.0", "327.1", "48.5", "56.5", "-1.3", "18.3"],
    ["Weekends", "7200", "84.1", "46.4", "39.7", "30.3", "-29.6", "-1.0"],
]
table(s, 0.55, 1.45, 7.4, 2.0, data, col_w=[1.1, 0.8, 1.1, 1.1, 1.0, 1.0, 1.0, 1.0], font_size=11)
fit_image(s, figname("exp5_template_class.png"), 8.15, 1.4, 4.7, 3.6)
bullets(s, 0.55, 3.75, 12.2, 3.0, [
    "Weekday/weekend split (B) helps weekends a lot (84.1 → 46.4 RMSE) but hurts weekdays (149 → 327).",
    "Split removes weekend contamination but also halves the weekday sample size → the split is a mixed result.",
    "24-h weekday RMSE blows up (383 → 1040), confirming long-horizon weakness persists regardless of template.",
], size=13)
footnote(s, "A = no-split 28-day window; B = weekday/weekend 28-day in-class windows. ME = mean error (bias).")

# ---- 15. Phase-1 summary ----
s = prs.slides.add_slide(BLANK)
header(s, 14, "Phase-1 summary — what the first experiments established")
cards = [
    ("AR order", "Raising p (1→10) gives no meaningful gain — AR(3)–AR(4) is enough."),
    ("Template", "The daily template is essential; it carries all cross-day memory."),
    ("Class split", "Weekday/weekend split helps weekends but is not a clear overall win."),
    ("Update cadence", "Faster updates lower RMSE — every 5 min is best."),
    ("Horizon", "Short horizons are easy; beyond ~6 h every AR-based model degrades."),
]
x0, y0, cw, ch, gap, gv = 0.55, 1.5, 4.0, 2.2, 0.14, 0.24
pos = [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1)]
for (r_i, c_i), (t, d) in zip(pos, cards):
    x = x0 + c_i * (cw + gap)
    y = y0 + r_i * (ch + gv)
    card = add_rect(s, x, y, cw, ch, fill=ICE, line=LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.1)
    tfc = card.text_frame; tfc.word_wrap = True
    tfc.margin_left = Inches(0.16); tfc.margin_right = Inches(0.16)
    tfc.margin_top = Inches(0.14); tfc.margin_bottom = Inches(0.1)
    p = tfc.paragraphs[0]
    add_run(p, t, font=HDR, size=15, color=NAVY, bold=True)
    p2 = tfc.add_paragraph(); p2.space_before = Pt(6)
    add_run(p2, d, font=BODY, size=12, color=INK)
tb, tf = textbox(s, 0.55, 6.5, 12.2, 0.6)
p = para(tf, True)
add_run(p, "→ Next: a unified benchmark of six predictors at 5-min cadence, scored on a 288×288 RMSE matrix.", font=BODY, size=14, color=NAVY, bold=True)

# ---- 16. Section divider ----
s = prs.slides.add_slide(BLANK)
add_rect(s, 0, 0, 13.333, 7.5, fill=DARK)
ring_motif(s, 1.6, 1.3, 1.5, TEAL, 3)
ring_motif(s, 2.7, 1.3, 0.5, AMBER, 2)
tb, tf = textbox(s, 0.9, 2.7, 11.5, 2.2)
p = para(tf, True)
add_run(p, "Part II — the six-model predictor suite", font=HDR, size=36, color=WHITE, bold=True)
p2 = tf.add_paragraph(); p2.space_before = Pt(12)
add_run(p2, "Unified on-line benchmark at 5-minute cadence, scored on a 288×288 RMSE matrix per predictor", font=BODY, size=17, color="CADCFC")

# ---- 17. Benchmark protocol + price clamp ----
s = prs.slides.add_slide(BLANK)
header(s, 15, "Benchmark protocol and price clamp", "run_predictor_benchmark.m — every observation re-issues the full 24-h forecast")
bullets(s, 0.55, 1.4, 6.4, 2.7, [
    "Update cadence = 1: each new 5-min observation triggers a fresh 288-step forecast.",
    "Every test point is forecast 288 times (lead h = 1..288) → a 288×288 RMSE matrix per model.",
    "Warm-up: all predictors trained on-line over Jan 1–30 (8,640 points).",
    "Forecast origins start Jan 31 so every Feb-1 target owns all 288 lead times.",
], size=13)
tb, tf = textbox(s, 7.2, 1.4, 5.6, 3.0)
p = para(tf, True)
add_run(p, "Price clamp", font=BODY, size=14, color=INK, bold=True)
p2 = tf.add_paragraph(); p2.space_before = Pt(4)
add_math(p2, "ŷ~clamped~ = clip(ŷ, Q~1~, Q~99~)", size=14)
p3 = tf.add_paragraph(); p3.space_before = Pt(6)
add_math(p3, "Q~1~ / Q~99~ = global 1% / 99% quantiles of a rolling 30-day raw-price window, recomputed daily.", size=12, color=MUTED)
bullets(s, 7.2, 2.95, 5.6, 1.5, [
    "Applied to forecasts and actuals — RMSE is scored on the exact signal the MPC receives.",
    "Q1/Q99 at test start −60.0 / 299.5, at end −33.6 / 178.7 $/MWh.",
], size=12)
tb, tf = textbox(s, 0.55, 4.6, 12.2, 2.2)
p = para(tf, True)
add_run(p, "The six predictors", font=BODY, size=14, color=INK, bold=True)
preds = [
    "1. Persistence — yesterday's same-slot price",
    "2. Rolling template — per-slot rolling mean",
    "3. Theta-y tracker — per-slot RLS gain on yesterday",
    "4. Template + intraday AR(4) — template + residual recursion",
    "5. Blend A — w·T + (1−w)·r̂",
    "6. Blend B — w·(θ·y~yesterday~) + (1−w)·r̂",
]
for i, t in enumerate(preds):
    p = para(tf, False)
    p.space_after = Pt(3)
    add_math(p, t, size=13.5, color=INK)
footnote(s, "Model states (gains, AR coefficients, template) are trained on raw prices; scoring uses clamped prices.")

# ---- 18. Predictors 1 & 2 ----
s = prs.slides.add_slide(BLANK)
header(s, 16, "Predictor 1 & 2 — Persistence and rolling template")
c1 = add_rect(s, 0.55, 1.5, 5.9, 4.6, fill=ICE, line=LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.08)
tb, tf = textbox(s, 0.85, 1.75, 5.3, 4.2)
p = para(tf, True)
add_run(p, "1. Persistence", font=HDR, size=16, color=NAVY, bold=True)
p2 = tf.add_paragraph(); p2.space_before = Pt(8)
add_math(p2, "ŷ(t+h|t) = y(s+h − 288)", size=15)
p3 = tf.add_paragraph(); p3.space_before = Pt(6)
add_math(p3, "Same slot, previous day — the naive baseline. s+h is the target slot; 288 = slots per day.", size=12, color=MUTED)
p4 = tf.add_paragraph(); p4.space_before = Pt(14)
add_run(p4, "2. Rolling template", font=HDR, size=16, color=NAVY, bold=True)
p5 = tf.add_paragraph(); p5.space_before = Pt(8)
add_math(p5, "ŷ(t+h|t) = T(s+h)", size=15)
p6 = tf.add_paragraph(); p6.space_before = Pt(6)
add_math(p6, "T(s) = (1/W) Σ y(s) over the last W=28 samples of slot s. Pointwise rolling mean.", size=12, color=MUTED)
c2 = add_rect(s, 6.85, 1.5, 5.9, 4.6, fill=ICE2, line=LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.08)
tb, tf = textbox(s, 7.15, 1.75, 5.3, 4.2)
p = para(tf, True)
add_run(p, "Why these are the anchors", font=BODY, size=14, color=INK, bold=True)
bullets(s, 7.15, 2.2, 5.3, 3.8, [
    "Persistence is the reference every other model must beat.",
    "The rolling template carries all cross-day memory with almost no parameters.",
    "Both are constant over lead time — their RMSE is flat vs h (see benchmark).",
    "Any AR-based model should beat these at short lead and converge to the template at long lead.",
], size=13)

# ---- 19. Predictor 3: theta-y ----
s = prs.slides.add_slide(BLANK)
header(s, 17, "Predictor 3 — Theta-y tracker", "Per-slot scalar gain on yesterday's price, adapted by RLS")
tb, tf = textbox(s, 0.55, 1.5, 12.2, 1.0)
p = para(tf, True)
add_math(p, "ŷ(t+h|t) = θ(s+h) · y(s+h − 288),      θ(s) ∈ ℝ  (scalar per-slot gain)", size=15)
bullets(s, 0.55, 2.65, 12.2, 1.7, [
    "Prior θ~0~ = 1 recovers persistence exactly; RLS then learns whether yesterday over- or under-predicts.",
    "Each slot is updated once per day (when its true value arrives), with regressor x = y~prev~(s) and target y~true~.",
], size=13.5)
tb, tf = textbox(s, 0.55, 4.55, 12.2, 1.7)
p = para(tf, True)
add_math(p, "Scalar RLS update:   K = P·x / (λ + P·x²),   θ ← θ + K(y − θx),   P ← (1 − Kx)P / λ", size=15)
p2 = tf.add_paragraph(); p2.space_before = Pt(6)
add_math(p2, "x = yesterday's value for this slot ·  λ = 0.98 ·  all quantities scalar (per-slot state).", size=12.5, color=MUTED)
footnote(s, "Implemented by rls_scalar_step.m, shared with the blend-weight updates.")

# ---- 20. Predictor 4: template + intraday AR ----
s = prs.slides.add_slide(BLANK)
header(s, 18, "Predictor 4 — Template + intraday AR(4)", "The core model: rolling template for the daily shape + AR for short-term tracking")
tb, tf = textbox(s, 0.55, 1.4, 12.2, 1.0)
p = para(tf, True)
add_math(p, "Template (pointwise rolling mean):   T(s) ← T(s) + (y − y~old~) / W,    W = 28", size=15)
p2 = tf.add_paragraph(); p2.space_before = Pt(6)
add_math(p2, "Residual:   r(t) = y(t) − T~t~(s~t~),    T~t~ = template value BEFORE the update", size=15)
bullets(s, 0.55, 2.75, 12.2, 1.9, [
    "Intraday AR(4) on CONSECUTIVE residuals:  r(t) = φ^T^ [r(t−1), …, r(t−4)] + e(t)",
    "φ updated by vector RLS (λ=0.98) every 5 min — the AR chases the current residual level.",
    "Cross-day per-slot regressors removed: same-slot values 24 h apart are nearly uncorrelated.",
], size=13.5)
tb, tf = textbox(s, 0.55, 4.9, 12.2, 1.5)
p = para(tf, True)
add_math(p, "Forecast:   ŷ(u) = T(u) + r̂(u),     r̂(u) = iterated 288-step AR recursion from [r(t−1), …, r(t−4)]", size=15)
p2 = tf.add_paragraph(); p2.space_before = Pt(6)
add_math(p2, "Short leads chase the residual level; long leads decay to 0, so ŷ → T as h grows.", size=12.5, color=MUTED)
footnote(s, "init/predict/update_template_ar.m — order of operations matters: residual is defined against the pre-update template.")

# ---- 21. Predictors 5 & 6: blends ----
s = prs.slides.add_slide(BLANK)
header(s, 19, "Predictor 5 & 6 — convex blends (Blend A and B)", "Adaptively combine a long-term and a short-term component, per slot")
tb, tf = textbox(s, 0.55, 1.4, 12.2, 1.0)
p = para(tf, True)
add_math(p, "ŷ = w(s)·x~1~ + (1 − w(s))·x~2~,      w(s) ∈ [0, 1]  (convex, per slot)", size=15)
p2 = tf.add_paragraph(); p2.space_before = Pt(6)
add_math(p2, "Blend A:  x~1~ = T (template),  x~2~ = r̂ (residual AR)          Blend B:  x~1~ = θ(s)·y~yesterday~,  x~2~ = r̂", size=13.5, color=NAVY)
bullets(s, 0.55, 2.6, 12.2, 1.7, [
    "Weight adaptation: rewrite ŷ − x~2~ = w·(x~1~ − x~2~), then scalar-RLS the single weight w on regressor d = x~1~ − x~2~.",
    "w is clipped to [0,1] so the combination stays convex (weights sum to 1 exactly).",
    "Initial w = 0.5; the update uses the 1-step-ahead component pair available before the true value arrives.",
], size=13.5)
tb, tf = textbox(s, 0.55, 4.6, 12.2, 1.3)
p = para(tf, True)
add_math(p, "Scalar RLS for w:   K = P·d / (λ + P·d²),   w ← clip(w + K·(y − x~2~ − w·d), 0, 1)", size=15)
p2 = tf.add_paragraph(); p2.space_before = Pt(6)
add_math(p2, "Idea: when the AR residual struggles mid-day but the template matches well, w moves toward 1 (trust the template).", size=12.5, color=MUTED)
footnote(s, "update_blend_weights.m / init_blend_tmpl_ar.m / init_blend_yt_ar.m.")

# ---- 22. Benchmark aggregate tables ----
s = prs.slides.add_slide(BLANK)
header(s, 20, "Benchmark results — aggregate & lead-time accuracy", "Two-week test (Feb 1–14), clamped prices, $/MWh")
data1 = [
    ["Model", "RMSE 2wk", "RMSE w1", "RMSE w2", "MAE", "Bias", "RMSE D9"],
    ["Persistence", "51.2", "47.2", "54.9", "38.8", "-5.2", "68.7"],
    ["Rolling template", "46.4", "46.1", "46.7", "36.6", "9.6", "63.1"],
    ["Theta-y tracker", "49.7", "45.6", "53.5", "37.3", "13.6", "76.3"],
    ["T + AR(4)", "51.9", "45.6", "57.5", "37.5", "1.0", "61.4"],
    ["Blend A", "55.6", "49.1", "61.5", "41.3", "23.1", "69.5"],
    ["Blend B", "61.4", "53.8", "68.1", "45.5", "29.3", "77.4"],
]
table(s, 0.55, 1.4, 6.7, 2.9, data1, col_w=[1.7, 1.1, 1.1, 1.1, 1.0, 1.0, 1.0], font_size=10.5)
data2 = [
    ["Model", "5min", "30min", "1h", "3h", "6h", "12h", "24h"],
    ["Persistence", "51.2", "51.2", "51.2", "51.2", "51.2", "51.2", "51.2"],
    ["Template", "46.4", "46.4", "46.4", "46.4", "46.4", "46.4", "46.4"],
    ["Theta-y", "49.7", "49.7", "49.7", "49.7", "49.7", "49.7", "49.7"],
    ["T + AR(4)", "15.8", "23.4", "28.0", "39.4", "50.3", "54.8", "58.5"],
    ["Blend A", "38.0", "41.0", "43.9", "49.1", "53.8", "57.0", "62.6"],
    ["Blend B", "43.6", "46.8", "49.5", "55.5", "59.9", "61.8", "68.6"],
]
table(s, 7.25, 1.4, 5.55, 2.9, data2, col_w=[1.45, 0.85, 0.85, 0.8, 0.8, 0.8, 0.85, 0.85], font_size=10)
tb, tf = textbox(s, 0.55, 4.5, 12.2, 1.9)
p = para(tf, True)
add_run(p, "Reading the tables:", font=BODY, size=13.5, color=INK, bold=True)
bullets(s, 0.55, 4.85, 12.2, 1.6, [
    "Persistence / template / theta-y are flat vs lead time (they only carry a daily signal).",
    "T + AR(4) wins every short horizon (5 min = 15.8) but degrades past 6 h — exactly as designed.",
    "The two blends sit between their components but never beat the best single model overall.",
], size=13)
footnote(s, "Clamped signal std = 51.3 $/MWh — RMSE near this value is an uninformative forecast.")

# ---- 23. Benchmark figures ----
s = prs.slides.add_slide(BLANK)
header(s, 21, "Benchmark results — RMSE(slot, lead) matrices", "Full 288×288 RMSE surface per model (rows = target slot, cols = lead time)")
fit_image(s, figname("bench_rmse_matrix.png"), 0.55, 1.4, 7.6, 5.1)
fit_image(s, figname("bench_rmse_lead.png"), 8.3, 1.4, 4.5, 5.1)
footnote(s, "Left: heatmaps show persistence/template/theta-y are flat in lead time; T+AR(4) is sharp at short leads. Right: RMSE vs lead (mean/median ± std across slots).")

# ---- 24. Benchmark: slot + improvement ----
s = prs.slides.add_slide(BLANK)
header(s, 22, "Benchmark results — per-slot profile & improvement", "Where each model wins, and by how much vs the persistence baseline")
data3 = [
    ["Model", "2wk", "5min", "24h"],
    ["Persistence", "0.0%", "0.0%", "0.0%"],
    ["Template", "+9.3%", "+9.3%", "+9.3%"],
    ["Theta-y", "+2.9%", "+2.9%", "+2.9%"],
    ["T + AR(4)", "-1.4%", "+69.2%", "-14.3%"],
    ["Blend A", "-8.7%", "+25.9%", "-22.2%"],
    ["Blend B", "-19.9%", "+14.8%", "-34.1%"],
]
table(s, 0.55, 1.4, 4.6, 2.7, data3, col_w=[1.4, 1.0, 1.0, 1.0], font_size=11)
tb, tf = textbox(s, 0.55, 4.3, 5.0, 2.3)
p = para(tf, True)
add_run(p, "Best model per lead time", font=BODY, size=13, color=INK, bold=True)
best = ["5 min → T + AR(4)   (15.8)", "30 min → T + AR(4)  (23.4)", "1 h → T + AR(4)     (28.0)", "3 h → T + AR(4)     (39.4)", "6 h → Template      (46.4)", "12 h → Template     (46.4)", "24 h → Template     (46.4)"]
for i, b in enumerate(best):
    p = para(tf, False)
    p.space_after = Pt(3)
    add_math(p, b, size=12.5, color=INK)
fit_image(s, figname("bench_rmse_slot.png"), 5.5, 1.4, 7.3, 3.4)
fit_image(s, figname("bench_week_aligned.png"), 5.5, 4.85, 7.3, 2.0)
footnote(s, "Improvement vs persistence: positive = better. T+AR(4) gives +69% at 5 min but −14% at 24 h — a short-term specialist.")

# ---- 25. Conclusions ----
s = prs.slides.add_slide(BLANK)
add_rect(s, 0, 0, 13.333, 7.5, fill=DARK)
ring_motif(s, 11.3, 1.1, 1.4, TEAL, 3)
ring_motif(s, 10.2, 1.1, 0.5, AMBER, 2)
tb, tf = textbox(s, 0.9, 0.9, 11.5, 1.0)
p = para(tf, True)
add_run(p, "Conclusions", font=HDR, size=34, color=WHITE, bold=True)
concl = [
    "The daily template is the indispensable long-term component — AR alone cannot forecast past ~6 h.",
    "The residual AR is a short-term specialist: +69% over persistence at 5 min, useless by 24 h.",
    "No single model wins everywhere — the right model depends on the MPC horizon.",
    "Faster updates help; raising the AR order and splitting weekday/weekend give little or mixed benefit.",
    "Price clamping to [Q1, Q99] keeps scoring honest on the signal the controller actually sees.",
]
tb, tf = textbox(s, 0.9, 2.05, 11.5, 4.6)
for i, c in enumerate(concl):
    p = para(tf, i == 0)
    p.space_after = Pt(14)
    add_run(p, "●  ", size=15, color=AMBER, bold=True)
    add_run(p, c, size=16, color=WHITE)

# ---- 26. Next steps ----
s = prs.slides.add_slide(BLANK)
header(s, 23, "Next steps")
cards = [
    ("Automation", "Schedule the Python capture with GitHub Actions for hands-off daily data refresh."),
    ("Kalman predictor", "Finish the harmonic state-space Kalman predictor as an alternative long-term model."),
    ("Forecast blending", "Blend by lead time (AR for short, template for long) instead of one per-slot weight."),
    ("Holiday handling", "Map public holidays into the template class logic to clean the weekday mean."),
    ("EMPC integration", "Wire the predictor into the MPC layer and validate cost savings on the tank system."),
    ("AEMO forecast data", "Fold the official P5 / pre-dispatch forecasts in as an exogenous input."),
]
x0, y0, cw, ch, gap, gv = 0.55, 1.5, 4.0, 2.0, 0.14, 0.22
pos = [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)]
for (r_i, c_i), (t, d) in zip(pos, cards):
    x = x0 + c_i * (cw + gap)
    y = y0 + r_i * (ch + gv)
    card = add_rect(s, x, y, cw, ch, fill=ICE, line=LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.1)
    tfc = card.text_frame; tfc.word_wrap = True
    tfc.margin_left = Inches(0.16); tfc.margin_right = Inches(0.16)
    tfc.margin_top = Inches(0.14); tfc.margin_bottom = Inches(0.1)
    p = tfc.paragraphs[0]
    add_run(p, t, font=HDR, size=14.5, color=NAVY, bold=True)
    p2 = tfc.add_paragraph(); p2.space_before = Pt(6)
    add_run(p2, d, font=BODY, size=11.5, color=INK)

# ---------------------------------------------------------------------------
out = os.path.join(ROOT, "Capstone_Forecasting_Deck.pptx")
prs.save(out)
print("Saved:", out)
print("Slides:", len(prs.slides._sldIdLst))
