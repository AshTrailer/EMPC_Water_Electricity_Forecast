# -*- coding: utf-8 -*-
"""Build the short English update deck (11 slides) for 2026-10-08.

Sources, all treated as read-only:
  predictor/figures/*.png                  five result figures
  deck/formulas/*.png                      mathtext renders, checked by _tmp_render_formulas.py
  the RMSE table and the AEMO P5 numbers   supplied verbatim in the task brief

Run with the bundled Python and PYTHONPATH pointing at deck/_pylibs.
"""
import os

from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches, Pt

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.abspath(os.path.join(HERE, "..", "predictor", "figures"))
FORMULAS = os.path.join(HERE, "formulas")
OUT_PPTX = os.path.join(HERE, "Capstone_Update_2026-10-08.pptx")

SW = 13.333
SH = 7.5
MARGIN = 0.6

NAVY = RGBColor(0x1E, 0x27, 0x61)
INK = RGBColor(0x1B, 0x24, 0x30)
MUTED = RGBColor(0x5A, 0x6B, 0x7B)
LINE = RGBColor(0xC9, 0xD4, 0xDE)
AMBER = RGBColor(0xE9, 0xA8, 0x20)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

FONT = "Calibri"
TITLE_SIZE = Pt(26)
LEAD_SIZE = Pt(16)
BODY_SIZE = Pt(14)
NOTE_SIZE = Pt(10)
CELL_SIZE = Pt(10)

DPI = 300  # every formula PNG is rendered at this dpi


# --------------------------------------------------------------------------- helpers
def blank(prs):
    return prs.slides.add_slide(prs.slide_layouts[6])


def no_autofit(tf):
    bodyPr = tf._txBody.find(qn("a:bodyPr"))
    for tag in ("a:normAutofit", "a:spAutoFit"):
        el = bodyPr.find(qn(tag))
        if el is not None:
            bodyPr.remove(el)


def set_font(run, size, bold, color, italic=False):
    f = run.font
    f.size = size
    f.bold = bold
    f.italic = italic
    f.name = FONT
    f.color.rgb = color
    rPr = run._r.get_or_add_rPr()
    for tag in ("a:latin", "a:ea", "a:cs"):
        el = rPr.find(qn(tag))
        if el is None:
            el = rPr.makeelement(qn(tag), {})
            rPr.append(el)
        el.set("typeface", FONT)


def textbox(slide, x, y, w, h, anchor=MSO_ANCHOR.TOP):
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = 0
    tf.margin_right = 0
    tf.margin_top = 0
    tf.margin_bottom = 0
    no_autofit(tf)
    return box, tf


def para(tf, first, label, body, size=BODY_SIZE, gap=Pt(3)):
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.space_before = Pt(0)
    p.space_after = gap
    if label:
        r = p.add_run()
        r.text = label
        set_font(r, size, True, NAVY)
    if body:
        r = p.add_run()
        r.text = body
        set_font(r, size, False, INK)
    return p


def line(slide, x, y, w, color=LINE, h=Pt(1.2)):
    shp = slide.shapes.add_shape(1, Inches(x), Inches(y), Inches(w), Emu(int(h)))
    shp.fill.solid()
    shp.fill.fore_color.rgb = color
    shp.line.fill.background()
    shp.shadow.inherit = False
    return shp


def place_image(slide, path, x, y, w=None, h=None, max_w=None, max_h=None):
    """Place by width or height, keeping the aspect. scale 1.0 = native dpi size."""
    with Image.open(path) as im:
        pw, ph = im.size
    nat_w = pw / DPI
    nat_h = ph / DPI
    if h is not None:
        box_w, box_h = (max_h if False else w), h
    if w is not None and h is None:
        box_w, box_h = w, nat_h * (w / nat_w)
    elif h is not None and w is None:
        box_h, box_w = h, nat_w * (h / nat_h)
    else:
        box_w, box_h = w, h
    if max_w is not None and box_w > max_w:
        box_h *= max_w / box_w
        box_w = max_w
    if max_h is not None and box_h > max_h:
        box_w *= max_h / box_h
        box_h = max_h
    return slide.shapes.add_picture(path, Inches(x), Inches(y), Inches(box_w), Inches(box_h))


def title(slide, text):
    box, tf = textbox(slide, MARGIN, 0.34, SW - 2 * MARGIN, 0.6)
    para(tf, True, None, text, size=TITLE_SIZE)
    for r in tf.paragraphs[0].runs:
        set_font(r, TITLE_SIZE, True, NAVY)
    return box


def footer(slide, text, y=6.95):
    box, tf = textbox(slide, MARGIN, y, SW - 2 * MARGIN, 0.34)
    para(tf, True, None, text, size=NOTE_SIZE, gap=Pt(0))
    for r in tf.paragraphs[0].runs:
        set_font(r, NOTE_SIZE, False, MUTED)
    return box


def caption_grid(slide, items, x0=MARGIN, width=SW - 2 * MARGIN, y=5.55, height=1.3, size=NOTE_SIZE):
    """Four short blocks laid out in one row."""
    gap = 0.22
    colw = (width - 3 * gap) / 4.0
    boxes = []
    for i, (label, body) in enumerate(items):
        box, tf = textbox(slide, x0 + i * (colw + gap), y, colw, height)
        p = tf.paragraphs[0]
        p.space_before = Pt(0)
        p.space_after = Pt(2)
        r = p.add_run()
        r.text = label
        set_font(r, size, True, NAVY)
        p2 = tf.add_paragraph()
        p2.space_before = Pt(0)
        p2.space_after = Pt(0)
        r2 = p2.add_run()
        r2.text = body
        set_font(r2, size, False, INK)
        boxes.append(box)
    return boxes


def style_table(tbl, header_rows=1, size=CELL_SIZE, row_h=0.32, band=True):
    for r_i, row in enumerate(tbl.rows):
        row.height = Inches(row_h)
        for c_i, cell in enumerate(row.cells):
            cell.margin_left = Inches(0.05)
            cell.margin_right = Inches(0.05)
            cell.margin_top = Inches(0.01)
            cell.margin_bottom = Inches(0.01)
            cell.vertical_anchor = MSO_ANCHOR.MIDDLE
            head = r_i < header_rows
            if head:
                cell.fill.solid()
                cell.fill.fore_color.rgb = NAVY
            elif band and (r_i - header_rows) % 2 == 0:
                cell.fill.solid()
                cell.fill.fore_color.rgb = WHITE
            else:
                cell.fill.solid()
                cell.fill.fore_color.rgb = RGBColor(0xF2, 0xF5, 0xF8)
            for p in cell.text_frame.paragraphs:
                no_autofit(cell.text_frame)
                p.space_before = Pt(0)
                p.space_after = Pt(0)
                for r in p.runs:
                    set_font(r, size, head, WHITE if head else INK)
    return tbl


def fill_cell(cell, text, align=PP_ALIGN.LEFT):
    cell.text_frame.word_wrap = False
    p = cell.text_frame.paragraphs[0]
    p.alignment = align
    p.text = text
    return cell


def make_table(slide, rows, cols, x, y, w, h):
    gf = slide.shapes.add_table(rows, cols, Inches(x), Inches(y), Inches(w), Inches(h))
    tbl = gf.table
    tbl.first_row = True
    tbl.horz_banding = False
    return tbl


# --------------------------------------------------------------------------- content
RMSE_TABLE = [
    ("Model", "5min", "30min", "1h", "3h", "6h", "12h", "24h"),
    ("Persistence", "48.6 [47.7]", "48.6", "48.6", "48.6", "48.6", "48.6", "60.0 [59.0]"),
    ("Rolling template", "47.3 [45.0]", "47.3", "47.3", "47.3", "47.3", "47.3", "47.3"),
    ("Theta-y tracker", "46.7 [45.6]", "46.7", "46.7", "46.7", "46.7", "46.7", "46.7"),
    ("T+AR(4)", "12.3 [9.8]", "20.2 [15.2]", "25.7 [20.4]", "39.7 [34.3]", "48.4 [44.6]", "51.4 [48.7]", "50.6 [45.1]"),
    ("Carry-forward", "10.8 [9.9]", "16.3 [13.3]", "22.2 [16.6]", "38.5 [29.9]", "51.1 [46.3]", "57.2 [58.8]", "48.6 [47.7]"),
    ("T+DMS4", "12.0 [9.8]", "19.4 [15.1]", "23.8 [19.4]", "33.7 [30.5]", "39.4 [37.2]", "44.9 [41.6]", "42.7 [41.4]"),
    ("CF+DMS4", "10.2 [9.0]", "16.4 [13.4]", "22.3 [16.8]", "38.5 [30.0]", "51.1 [46.3]", "57.2 [58.8]", "48.7 [47.7]"),
    ("Anchor-mix", "9.9 [9.0]", "15.6 [13.0]", "20.8 [17.3]", "31.4 [29.0]", "36.7 [35.8]", "41.9 [40.6]", "42.2 [41.1]"),
]

LEAD_TABLE = [
    ("Lead", "Best", "RMSE", "Second best", "RMSE", "Gap"),
    ("5min", "Anchor-mix", "9.9", "CF+DMS4", "10.2", "0.3"),
    ("30min", "Anchor-mix", "15.6", "Carry-forward", "16.3", "0.7"),
    ("1h", "Anchor-mix", "20.8", "Carry-forward", "22.2", "1.4"),
    ("3h", "Anchor-mix", "31.4", "T+DMS4", "33.7", "2.3"),
    ("6h", "Anchor-mix", "36.7", "T+DMS4", "39.4", "2.7"),
    ("12h", "Anchor-mix", "41.9", "T+DMS4", "44.9", "3.0"),
    ("24h", "Anchor-mix", "42.2", "T+DMS4", "42.7", "0.5"),
]

THREE_COEF = [
    ("Lead h", "5min", "30min", "1h", "3h", "6h", "12h", "24h"),
    ("c_h", "0.090", "0.310", "0.940", "1.350", "0.080", "11.530", "15.170"),
    ("a_h", "0.971", "0.887", "0.735", "0.405", "0.344", "0.194", "0.820"),
    ("b_h", "0.032", "0.123", "0.274", "0.636", "0.764", "0.651", "-0.068"),
]

NOTATION = [
    ("Symbol", "Meaning", "Unit or range"),
    ("k", "5-minute time step index", "integer"),
    ("h", "lead, forecast horizon in steps", "h = 1 to 288"),
    ("s(k)", "slot of the day at step k", "1 to 288, slot 1 is 00:05"),
    ("y(k)", "clamped VIC1 price at step k", "$/MWh"),
    ("T_c(s)", "day template at slot s, mean over W_c", "$/MWh"),
    ("W_c, N_c", "template window and its day count", "28 days"),
    ("r(k)", "price minus template at the same slot", "$/MWh"),
    ("Delta y(k)", "first difference of price", "$/MWh"),
    ("theta", "state of the Theta-y tracker", "$/MWh"),
    ("phi_j, psi_j", "AR and difference coefficients", "dimensionless"),
    ("a_h, b_h, c_h", "Anchor-mix coefficients on price, template, intercept", "dimensionless, $/MWh for c_h"),
    ("pi(k)", "AEMO P5 forecast price", "$/MWh"),
    ("g(k)", "P5 price minus our template", "$/MWh"),
    ("Q1, Q99", "clamp bounds, rolling 30-day global quantiles", "$/MWh"),
    ("RMSE", "root mean squared error of the forecast", "$/MWh"),
]


# --------------------------------------------------------------------------- build
def build():
    prs = Presentation()
    prs.slide_width = Inches(SW)
    prs.slide_height = Inches(SH)

    # ---------------------------------------------------------------- 1 title
    s = blank(prs)
    line(s, MARGIN, 1.75, 1.6, AMBER, Pt(4))
    box, tf = textbox(s, MARGIN, 2.0, SW - 2 * MARGIN, 1.4)
    para(tf, True, None, "Capstone update: electricity price forecasting", size=Pt(38))
    for r in tf.paragraphs[0].runs:
        set_font(r, Pt(38), True, NAVY)
    box, tf = textbox(s, MARGIN, 3.45, SW - 2 * MARGIN, 1.9)
    para(tf, True, None, "Eight models, one rolling 5-min forecast protocol, a 288x288 RMSE surface, and the AEMO P5 test.",
         size=Pt(16), gap=Pt(8))
    para(tf, False, None, "VIC1 5-min RRP, window 2026-02-01 to 2026-06-01, 120 days, clamped price.",
         size=Pt(14), gap=Pt(8))
    para(tf, False, None, "Ash Zhang, Capstone Project, 2026-10-08.", size=Pt(14))
    for p in tf.paragraphs:
        for r in p.runs:
            set_font(r, r.font.size, False, INK)

    # ---------------------------------------------------------------- 2 data and setup
    s = blank(prs)
    title(s, "Data and setup")
    box, tf = textbox(s, MARGIN, 1.15, 7.5, 5.4)
    para(tf, True, "Signal. ", "VIC1 5-min RRP from AEMO NEMWEB.", gap=Pt(7))
    para(tf, False, "Clock. ", "NEM time (AEST). A timestamp is the end of its 5-min interval.", gap=Pt(7))
    para(tf, False, "Window. ", "2026-02-01 to 2026-06-01, 120 days, 288 slots per day.", gap=Pt(7))
    para(tf, False, "Clamp. ", "Rolling 30-day global Q1 and Q99, recomputed daily and applied to forecast and actual.", gap=Pt(7))
    para(tf, False, "Clamped signal sd. ", "48.8 $/MWh.", gap=Pt(7))
    para(tf, False, "Protocol. ", "Eat first, then forecast. y(k) enters the state before the forecast is issued.", gap=Pt(7))
    para(tf, False, "Meaning of h. ", "Lead h is the distance in steps from the newest observation.", gap=Pt(7))
    para(tf, False, "Training. ", "Template, AR coefficients and residuals are fitted on the raw price series.", gap=Pt(7))
    para(tf, False, "Scoring. ", "Error and RMSE use the clamped price series only.", gap=Pt(7))
    para(tf, False, "Why clamp. ", "The MPC stage cost is linear in price, so one outlier would steer the whole 288-step plan.",
         gap=Pt(7))
    place_image(s, os.path.join(FORMULAS, "y_clamp.png"), 8.5, 1.35, max_w=4.2)

    # ---------------------------------------------------------------- 3 notation
    s = blank(prs)
    title(s, "Notation")
    rows = len(NOTATION)
    tbl = make_table(s, rows, 3, MARGIN, 1.15, SW - 2 * MARGIN, 5.4)
    widths = [1.9, 5.4, 4.833]
    for i, w in enumerate(widths):
        tbl.columns[i].width = Inches(w)
    for r_i, row in enumerate(NOTATION):
        for c_i, val in enumerate(row):
            fill_cell(tbl.cell(r_i, c_i), val, PP_ALIGN.LEFT if c_i == 0 or c_i == 1 else PP_ALIGN.LEFT)
    style_table(tbl, header_rows=1, size=CELL_SIZE, row_h=0.315)
    footer(s, "T_c(s) is the template, W_c is its window of the last 28 days, r(k) is the deviation from that template.")

    # ---------------------------------------------------------------- 4 the eight models
    s = blank(prs)
    title(s, "The eight models")
    models = [
        ("Persistence", "persistence", "copy the price of the same slot yesterday"),
        ("Rolling template", "rolling_template", "copy the day template of the target slot"),
        ("Theta-y tracker", "theta_y", "template plus the tracked level state"),
        ("T+DMS4", "t_dms4", "direct multistep fit on the residual, refitted daily"),
        ("Carry-forward", "carry_forward", "hold the newest observation, flat in h"),
        ("CF+DMS4", "cf_dms4", "carry-forward plus a fitted daily correction"),
        ("T+AR(4)", "t_ar4", "template plus an iterated AR(4) residual model"),
        ("Anchor-mix", "anchor_mix_a", "weighted mix of current price and template"),
    ]
    y = 1.12
    row_h = 0.62
    for i, (name, key, gloss) in enumerate(models):
        bx, tfx = textbox(s, MARGIN, y + 0.05, 1.95, 0.5)
        para(tfx, True, None, name, size=BODY_SIZE, gap=Pt(0))
        for r in tfx.paragraphs[0].runs:
            set_font(r, BODY_SIZE, True, NAVY)
        # formula image must be fully visible: height capped at row_h - 0.04
        img = os.path.join(FORMULAS, key + ".png")
        with Image.open(img) as im:
            pw, ph = im.size
        nat_w, nat_h = pw / DPI, ph / DPI
        sc = min(1.0, (row_h - 0.06) / nat_h, 3.4 / nat_w)
        pic = s.shapes.add_picture(img, Inches(2.75), Inches(y + (row_h - nat_h * sc) / 2.0),
                                   Inches(nat_w * sc), Inches(nat_h * sc))
        bx2, tfx2 = textbox(s, 2.75 + nat_w * sc + 0.15, y + 0.13, 4.6, 0.4)
        para(tfx2, True, None, gloss, size=NOTE_SIZE, gap=Pt(0))
        for r in tfx2.paragraphs[0].runs:
            set_font(r, NOTE_SIZE, False, MUTED)
        y += row_h
    footer(s, "All eight share one scoring grid: target slot s, lead h, target day d, exactly one sample per cell and day.")

    # ---------------------------------------------------------------- 5 anchor mix
    s = blank(prs)
    title(s, "Anchor-mix")
    line(s, MARGIN, 1.05, 1.6, AMBER, Pt(3))
    place_image(s, os.path.join(FORMULAS, "anchor_mix_a.png"), MARGIN, 1.25, max_w=11.0)
    place_image(s, os.path.join(FORMULAS, "anchor_mix_b.png"), MARGIN + 0.45, 1.85, max_w=9.6)
    box, tf = textbox(s, MARGIN, 2.6, SW - 2 * MARGIN, 0.6)
    para(tf, True, "Coefficients. ",
         "One set per lead: a_h weights the newest price, b_h the target-slot template, c_h the intercept.",
         size=BODY_SIZE, gap=Pt(0))
    tbl = make_table(s, len(THREE_COEF), 8, MARGIN, 3.35, SW - 2 * MARGIN, 2.1)
    tbl.columns[0].width = Inches(1.6)
    for i in range(1, 8):
        tbl.columns[i].width = Inches((SW - 2 * MARGIN - 1.6) / 7.0)
    for r_i, row in enumerate(THREE_COEF):
        for c_i, val in enumerate(row):
            fill_cell(tbl.cell(r_i, c_i), val, PP_ALIGN.LEFT if c_i == 0 else PP_ALIGN.CENTER)
    style_table(tbl, header_rows=1, size=CELL_SIZE, row_h=0.36)
    box, tf = textbox(s, MARGIN, 5.7, SW - 2 * MARGIN, 1.1)
    para(tf, True, "Reading. ",
         "a_h falls and b_h rises with the lead, so the model shifts weight from the current price to the template.",
         size=BODY_SIZE, gap=Pt(6))
    para(tf, False, "Known fault. ",
         "a_h is 0.194 at the 12h row of the table and -0.068 on b_h at 24h, which is a collinear fit, not a physical weight.",
         size=BODY_SIZE, gap=Pt(0))

    # ---------------------------------------------------------------- 6 RMSE
    s = blank(prs)
    title(s, "RMSE")
    place_image(s, os.path.join(FORMULAS, "rmse.png"), MARGIN, 1.15, max_w=4.4)
    box, tf = textbox(s, 5.4, 1.25, 7.3, 2.4)
    para(tf, True, "Grid. ", "One cell per target slot s, lead h and target day d, one sample per cell per day.", gap=Pt(7))
    para(tf, False, "Aggregate. ", "RMSE is taken over the 120 days inside a cell, then reduced across the 288 slots.", gap=Pt(7))
    para(tf, False, "Reported. ", "Pooled RMSE over the same cells, and the across-slot median in brackets.", gap=Pt(7))
    para(tf, False, "Comparability. ", "Every model is scored on the identical clamped targets, so cells are directly comparable.",
         gap=Pt(7))
    tbl = make_table(s, len(RMSE_TABLE), 8, MARGIN, 3.5, SW - 2 * MARGIN, 2.9)
    tbl.columns[0].width = Inches(2.1)
    for i in range(1, 8):
        tbl.columns[i].width = Inches((SW - 2 * MARGIN - 2.1) / 7.0)
    for r_i, row in enumerate(RMSE_TABLE):
        for c_i, val in enumerate(row):
            fill_cell(tbl.cell(r_i, c_i), val, PP_ALIGN.LEFT if c_i == 0 else PP_ALIGN.RIGHT)
    style_table(tbl, header_rows=1, size=CELL_SIZE, row_h=0.31)
    footer(s, "120 days, window 2026-02-01 to 2026-06-01, clamped price, unit $/MWh, bracket is the across-slot median.")

    # ---------------------------------------------------------------- 7..9 figures
    fig_slides = [
        ("Rolling 5-min forecast", "D_single_day__rolling_5-min.png",
         [("What you are looking at",
           "Eight one-step 5-min forecasts over one day, 2026-05-14, target day of the 120-day window."),
          ("How to read it",
           "Black is the clamped actual. Orange is the rolling 5-min forecast. Each panel shows one model and its day RMSE."),
          ("What it shows",
           "Carry-forward 8.7, CF+DMS4 10.7 and Anchor-mix 10.6 track the actual. T+AR(4) is 12.9 but dives to -25 at 08:00."),
          ("Conclusion",
           "The short-lead contest is decided by how fast a model picks up the current price, not by the template.")]),
        ("Rolling 5-min forecast", "G_rolling_5-min__across_days.png",
         [("What you are looking at",
           "The rolling 5-min forecast aggregated over all 120 days, one panel per model."),
          ("How to read it",
           "x is the target slot. Blue is the median error across days, red the mean, the band is Q05 to Q95, black is RMSE."),
          ("What it shows",
           "Rolling template and Theta-y tracker sit at a median error of about +11 $/MWh. Price-anchored models sit at 0."),
          ("Conclusion",
           "Day-type models carry a systematic bias above 10 $/MWh. Carry-forward, CF+DMS4 and Anchor-mix are near unbiased.")]),
        ("Fixed origin", "H_fixed_origin__288-step.png",
         [("What you are looking at",
           "One 288-step forecast issued at 00:00 on 2026-05-14, no rolling update inside the day."),
          ("How to read it",
           "x is the horizon in hours after the origin. Black is the following 24 h, orange the single fixed-origin forecast."),
          ("What it shows",
           "Carry-forward and CF+DMS4 hold 43.4 and go flat. Anchor-mix holds 44.7 with visible intraday shape."),
          ("Conclusion",
           "Without rolling, all eight models land in a 43 to 45 band. A fixed origin cannot separate them.")]),
        ("Long-horizon skill", "I_long-horizon__many_origins.png",
         [("What you are looking at",
           "The same fixed-origin forecast aggregated over 120 origins, one per day at 24:00."),
          ("How to read it",
           "x is the horizon in hours. Black is RMSE over origins, blue the median error, red the mean, the band is Q05 to Q95."),
          ("What it shows",
           "At 24 h T+DMS4 is 37.9, Anchor-mix 38.2, Rolling template 38.9, Carry-forward 44.7, Persistence 52.1."),
          ("Conclusion",
           "The Q05 to Q95 band is roughly plus or minus 50 $/MWh, so single-origin differences of a few dollars are noise.")]),
        ("288x288 RMSE surface", "J_RMSE_288x288_heatmap.png",
         [("What you are looking at",
           "RMSE for every pair of target slot and lead, 288 by 288 cells, over the 120 days."),
          ("How to read it",
           "x is the lead in hours, y is the target slot in hours, colour is RMSE from 0 to 60 $/MWh, saturated at 60."),
          ("What it shows",
           "Rolling template is a flat band set by the slot. Carry-forward and CF+DMS4 carry wide high-error wedges at long lead."),
          ("Conclusion",
           "Anchor-mix is flat at short lead and moderate in the far corner. The 07:00 to 08:30 and 17:00 to 18:30 bands stay hardest.")]),
    ]
    for head, fname, caps in fig_slides:
        s = blank(prs)
        title(s, head)
        place_image(s, os.path.join(FIGDIR, fname), MARGIN, 1.15, w=6.2, max_h=4.15)
        caption_grid(s, caps, y=5.5, height=1.35)

    # ---------------------------------------------------------------- 10 RMSE by lead
    s = blank(prs)
    title(s, "RMSE by lead")
    box, tf = textbox(s, MARGIN, 1.05, SW - 2 * MARGIN, 0.4)
    para(tf, True, "Best model and runner-up at each lead, 120 days, clamped price, unit $/MWh.",
         size=Pt(12), gap=Pt(0))
    for r in tf.paragraphs[0].runs:
        set_font(r, Pt(12), False, MUTED)
    tbl = make_table(s, len(LEAD_TABLE), 6, MARGIN, 1.5, 8.6, 4.4)
    widths = [1.1, 2.0, 1.1, 2.0, 1.1, 1.3]
    for i, w in enumerate(widths):
        tbl.columns[i].width = Inches(w)
    for r_i, row in enumerate(LEAD_TABLE):
        for c_i, val in enumerate(row):
            fill_cell(tbl.cell(r_i, c_i), val, PP_ALIGN.LEFT if c_i in (1, 3) else PP_ALIGN.RIGHT)
    style_table(tbl, header_rows=1, size=CELL_SIZE, row_h=0.5)
    box, tf = textbox(s, 9.6, 1.5, 3.13, 4.6)
    para(tf, True, "Winner. ", "Anchor-mix holds the lowest pooled RMSE at all seven leads.", gap=Pt(8))
    para(tf, False, "Margin. ", "The gap to the runner-up runs from 0.3 to 3.0 $/MWh.", gap=Pt(8))
    para(tf, False, "Short lead. ", "Carry-forward and CF+DMS4 are within 0.3 to 0.7 of Anchor-mix at 5 and 30 min.", gap=Pt(8))
    para(tf, False, "Long lead. ", "T+DMS4 is the runner-up from 3 h to 24 h.", gap=Pt(8))
    para(tf, False, "Day-type models. ", "Persistence, Rolling template and Theta-y tracker never reach the top two.", gap=Pt(8))
    para(tf, False, "Note. ", "Full 8 by 7 table is on the RMSE slide.", gap=Pt(0))

    # ---------------------------------------------------------------- 11 AEMO P5
    s = blank(prs)
    title(s, "AEMO P5 error")
    place_image(s, os.path.join(FORMULAS, "p5_gap.png"), MARGIN, 1.12, max_w=3.4)
    box, tf = textbox(s, MARGIN, 1.9, 6.1, 4.6)
    para(tf, True, "Window. ", "2026-08-25 to 2026-10-06, balanced panel of 12373 origins.", gap=Pt(7))
    para(tf, False, "Raw error. ", "RMSE 15.18 at 5 min, 41.97 at 55 min, sd 10.16, ACF(1) 0.626, mean same-sign run 5.83 steps, longest 135.", gap=Pt(7))
    para(tf, False, "Clamped error. ", "RMSE 12.57 at 5 min and 23.33 at 55 min.", gap=Pt(7))
    para(tf, False, "Fusion test. ", "Using g as a regressor moves the out-of-sample gain from -4.3% to +2.7% across the eight models.", gap=Pt(7))
    para(tf, False, "Decay. ", "R2 of the P5 error on later AEMO error falls from 0.178 at h = 1 to 0.012 at h = 11.", gap=Pt(7))
    para(tf, False, "Our number. ", "At 55 min T+DMS4 scores 23.21 against 34.82 for AEMO, better by 33%.", gap=Pt(7))
    box, tf = textbox(s, 7.1, 1.9, 5.63, 4.6)
    para(tf, True, "What you are looking at. ",
         "The size, the persistence and the forecasting value of the gap between the AEMO P5 price and our own template.",
         size=BODY_SIZE, gap=Pt(8))
    para(tf, False, "How to read it. ",
         "g(k) is the P5 price minus our template. RMSE and ACF are measured on the panel, gains on out-of-sample runs.",
         size=BODY_SIZE, gap=Pt(8))
    para(tf, False, "What it shows. ",
         "The P5 error is persistent, yet it does not predict later AEMO error, and it adds no usable accuracy to our models.",
         size=BODY_SIZE, gap=Pt(8))
    para(tf, False, "Conclusion. ",
         "The result is negative. We report it as negative and keep P5 out of the eight models.", size=BODY_SIZE, gap=Pt(0))
    footer(s, "ACF(1) is the lag-1 autocorrelation of the P5 error. A same-sign run is a stretch of steps with one error sign.")

    # ---------------------------------------------------------------- 12 next steps
    s = blank(prs)
    title(s, "Next steps")
    box, tf = textbox(s, MARGIN, 1.2, 8.0, 5.2)
    para(tf, True, "1. Regularise Anchor-mix. ",
         "Fix the collinear a_h at long lead, then re-run the 120-day table.", gap=Pt(10))
    para(tf, False, "2. Clamped training signal. ",
         "Fit template and regressors on the clamped series, keep the raw-price run as a control.", gap=Pt(10))
    para(tf, False, "3. Close the P5 line. ",
         "Record the negative result and drop the fusion branch from the model set.", gap=Pt(10))
    para(tf, False, "4. Lead-times report. ",
         "Promote the 288x288 surface to the standing weekly figure.", gap=Pt(10))
    para(tf, False, "5. Wide table. ",
         "Keep the 8 by 7 RMSE table in the appendix of the full deck.", gap=Pt(0))
    box, tf = textbox(s, 9.0, 1.2, 3.73, 5.2)
    para(tf, True, "Held constant. ", "Window, clamp, protocol and scoring for any re-run.", size=BODY_SIZE, gap=Pt(8))
    para(tf, False, "Open item. ", "a_h at 12h to 24h, owned by the regularisation step.", size=BODY_SIZE, gap=Pt(8))
    para(tf, False, "Decided. ", "P5 stays out of the eight models.", size=BODY_SIZE, gap=Pt(0))

    prs.save(OUT_PPTX)
    print("saved", OUT_PPTX, os.path.getsize(OUT_PPTX))


if __name__ == "__main__":
    build()
