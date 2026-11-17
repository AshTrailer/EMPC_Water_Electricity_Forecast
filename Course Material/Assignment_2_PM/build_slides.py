"""Build the Assignment 2 Part 2 slide deck: 2 slides, 16:9, editable shapes, content-sized boxes.

Layout rule: every text box height is computed from the text it holds, using a conservative
Calibri glyph-width estimate, so nothing has to be shrunk to fit by the renderer.
"""

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml import parse_xml
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main"

OUT_PPTX = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Assignment_2_PM\Assignment2_PM_Slides_DRAFT_v1.pptx"

NAVY = RGBColor(0x1F, 0x33, 0x55)
INK = RGBColor(0x22, 0x2B, 0x38)
BODY = RGBColor(0x44, 0x4C, 0x57)
MUTED = RGBColor(0x78, 0x82, 0x8E)
ACCENT = RGBColor(0x2F, 0x6F, 0xB5)
AMBER = RGBColor(0xB2, 0x62, 0x0F)
GREEN = RGBColor(0x1E, 0x7A, 0x46)
PANEL = RGBColor(0xF4, 0xF7, 0xFA)
RULE = RGBColor(0xD5, 0xDD, 0xE6)

FONT = "Calibri"

# Calibrated on this deck: the 123-character 9.5 pt footer occupies one line in a 12.2 in box,
# so Calibri averages about 0.44 em per glyph here. Using 0.46 keeps a small margin.
EM = 0.46
LEAD = 1.06          # extra leading per line, as a multiple of the font size
PAD = 0.08           # internal slack added to every computed box height


def lines_needed(text, size_pt, width_in):
    """Worst-case wrapped line count for a paragraph."""
    per_line = max(1.0, width_in / (size_pt * EM / 72.0))
    total = 0
    for chunk in text.split("\n"):
        n = len(chunk)
        total += max(1, -(-n // int(per_line)) if n else 1)
    return total


def text_height(specs, width_in):
    """Estimated height in inches for a list of paragraph specs."""
    total = 0.0
    for spec in specs:
        size = spec.get("size", 14)
        spacing = spec.get("line", 0.98)
        n = lines_needed(spec["text"], size, width_in)
        total += n * size * (spacing + LEAD) / 72.0
        total += spec.get("after", 0) / 72.0
        total += spec.get("before", 0) / 72.0
    return total


class Deck:
    def __init__(self):
        self.prs = Presentation()
        self.prs.slide_width = Inches(13.333)
        self.prs.slide_height = Inches(7.5)
        self.report = []

    def slide(self):
        return self.prs.slides.add_slide(self.prs.slide_layouts[6])

    def block(self, slide, x, y, w, specs, align=PP_ALIGN.LEFT, tag=""):
        h = text_height(specs, w) + PAD
        frame = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)).text_frame
        frame.word_wrap = True
        frame.vertical_anchor = MSO_ANCHOR.TOP
        frame.margin_left = 0
        frame.margin_right = 0
        frame.margin_top = 0
        frame.margin_bottom = 0
        for i, spec in enumerate(specs):
            para = frame.paragraphs[0] if i == 0 else frame.add_paragraph()
            para.alignment = align
            para.line_spacing = spec.get("line", 0.98)
            para.space_after = Pt(spec.get("after", 0))
            para.space_before = Pt(spec.get("before", 0))
            # Font properties must live on the run: paragraph-level defaults are not honoured
            # by every renderer, and PowerPoint itself prefers run properties.
            run = para.add_run()
            run.text = spec["text"]
            run.font.size = Pt(spec.get("size", 14))
            run.font.bold = spec.get("bold", False)
            run.font.italic = spec.get("italic", False)
            run.font.color.rgb = spec.get("color", INK)
            run.font.name = FONT
        self.report.append((tag, x, y, w, h))
        return h

    def panel(self, slide, x, y, w, h):
        shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
        shape.fill.solid()
        shape.fill.fore_color.rgb = PANEL
        shape.line.color.rgb = RULE
        shape.line.width = Pt(0.75)
        shape.adjustments[0] = 0.05
        # Remove the theme's outer shadow: an empty effect list is the only reliable way.
        sp_pr = shape._element.spPr
        for tag in ("a:effectLst", "a:effectDag"):
            for node in sp_pr.findall(qn(tag)):
                sp_pr.remove(node)
        sp_pr.append(parse_xml(f'<a:effectLst xmlns:a="{NS_A}"/>'))
        return shape

    def rule(self, slide, x, y, w, color=RULE, weight=1.25):
        shape = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(x), Inches(y), Inches(w), Pt(weight))
        shape.fill.solid()
        shape.fill.fore_color.rgb = color
        shape.line.fill.background()
        shape.shadow.inherit = False
        return shape

    def save(self, path):
        self.prs.save(path)


TITLE_1 = "Forecasting electricity prices to run water pumps when power is cheap"
SUB_1 = "ENGR90037 Capstone  |  Assignment 2 Part 2, project management retrospective  |  Ash"

TITLE_2 = "Retrospective: integration delivered, one blind spot, two lessons"
SUB_2 = "Progress against the plan, what surprised us, and what changes as a result"


def build():
    deck = Deck()
    prs = deck.prs

    # =============================================================== slide 1
    s1 = deck.slide()
    deck.block(s1, 0.55, 0.34, 12.2, [{"text": TITLE_1, "size": 26, "bold": True, "color": NAVY, "line": 1.0}], tag="s1.title")
    deck.block(s1, 0.55, 0.98, 12.2, [{"text": SUB_1, "size": 12, "color": MUTED}], tag="s1.sub")
    deck.rule(s1, 0.55, 1.30, 12.23)

    LEFT_W = 7.35
    deck.block(s1, 0.55, 1.50, LEFT_W,
               [{"text": "PROBLEM AND OBJECTIVE", "size": 11, "bold": True, "color": ACCENT}], tag="s1.h1")
    deck.block(s1, 0.55, 1.80, LEFT_W, [
        {"text": "A water utility pays the wholesale electricity price, which changes every five minutes. "
                 "Pumping can be moved to the cheap intervals, but only if the next hours of price are known first.",
         "size": 14, "color": BODY, "after": 9, "line": 1.0},
        {"text": "We deliver the forecaster and the controller that decides which pumps run. The objective was set "
                 "at the start: a forecast good enough to schedule pumping against, and a controller that saves energy cost.",
         "size": 14, "color": BODY, "after": 9, "line": 1.0},
        {"text": "The two are now connected. Our own forecast drives the controller, over a one-hour horizon chosen "
                 "so the result can be compared directly against the market operator's published forecast.",
         "size": 14, "bold": True, "color": INK, "line": 1.0},
    ], tag="s1.body")

    RIGHT_X, RIGHT_W = 8.20, 4.58
    deck.block(s1, RIGHT_X, 1.50, RIGHT_W,
               [{"text": "WHERE THE PROJECT STANDS", "size": 11, "bold": True, "color": ACCENT}], tag="s1.h2")
    panel_specs = [
        {"text": "Data pipeline", "size": 12.5, "bold": True, "color": NAVY, "after": 1},
        {"text": "verified, no missing timestamps, audit re-runnable", "size": 11, "color": BODY, "after": 8, "line": 1.0},
        {"text": "Forecast benchmark", "size": 12.5, "bold": True, "color": NAVY, "after": 1},
        {"text": "9 models, 120 days, one entry point", "size": 11, "color": BODY, "after": 8, "line": 1.0},
        {"text": "Controller", "size": 12.5, "bold": True, "color": NAVY, "after": 1},
        {"text": "rolling three-pump schedule, hard tank limits, switching penalty", "size": 11, "color": BODY, "after": 8, "line": 1.0},
        {"text": "Linked to the forecaster", "size": 12.5, "bold": True, "color": GREEN, "after": 1},
        {"text": "our forecast is the controller's price input", "size": 11, "color": BODY, "line": 1.0},
    ]
    inner_w = RIGHT_W - 0.44
    panel_h = 3.10
    deck.panel(s1, RIGHT_X, 1.84, RIGHT_W, panel_h)
    deck.block(s1, RIGHT_X + 0.22, 2.00, inner_w, panel_specs, tag="s1.status")

    # metric cards
    cards = [
        ("5 MINUTES AHEAD", "9.0", "AUD/MWh median forecast error", "market volatility over the same period: 48.8"),
        ("30 MINUTES AHEAD", "13.1", "AUD/MWh median forecast error", "dominates the value of the forecast"),
        ("CONTROL HORIZON", "1 hour", "matches the only horizon the market operator", "publishes, so the comparison is direct"),
    ]
    card_y = 5.30
    x = 0.55
    for label, value, note_a, note_b in cards:
        card_specs = [
            {"text": label, "size": 9.5, "bold": True, "color": MUTED, "after": 2},
            {"text": value, "size": 18, "bold": True, "color": NAVY, "after": 3, "line": 0.95},
            {"text": note_a, "size": 9.5, "color": BODY, "line": 1.0},
            {"text": note_b, "size": 9.5, "color": BODY, "line": 1.0},
        ]
        card_inner = 3.54
        card_h = text_height(card_specs, card_inner) + 0.10
        deck.panel(s1, x, card_y, 3.94, card_h)
        deck.block(s1, x + 0.20, card_y + 0.11, card_inner, card_specs, tag=f"s1.card{label[:2]}")
        x += 4.145

    deck.rule(s1, 0.55, 6.94, 12.23)
    deck.block(s1, 0.55, 7.04, 12.2,
               [{"text": "Slide 1 of 2  |  figures from the project benchmark: 120 test days, prices clamped as delivered to the controller.",
                 "size": 9.5, "color": MUTED}], tag="s1.foot")

    # =============================================================== slide 2
    s2 = deck.slide()
    deck.block(s2, 0.55, 0.34, 12.2, [{"text": TITLE_2, "size": 26, "bold": True, "color": NAVY, "line": 1.0}], tag="s2.title")
    deck.block(s2, 0.55, 0.98, 12.2, [{"text": SUB_2, "size": 12, "color": MUTED}], tag="s2.sub")
    deck.rule(s2, 0.55, 1.30, 12.23)

    COL1_X, COL1_W = 0.55, 5.85
    COL2_X, COL2_W = 6.78, 6.00

    # left top: progress
    deck.block(s2, COL1_X, 1.50, COL1_W,
               [{"text": "PROGRESS AGAINST THE BASELINE PLAN", "size": 11, "bold": True, "color": GREEN}], tag="s2.h1")
    deck.block(s2, COL1_X, 1.80, COL1_W, [
        {"text": "Both technical milestones in the baseline plan are met, and the module link that carried the real "
                 "risk is closed and working. What slipped is the schedule: the 21 September date for a working "
                 "controller moved into early October.",
         "size": 12.5, "color": BODY, "after": 9, "line": 1.0},
        {"text": "Two things drove that. Fixing defects in our own data capture took about a week, and integration "
                 "took longer than we planned because nobody owned the interfaces between modules.",
         "size": 12.5, "color": BODY, "after": 9, "line": 1.0},
        {"text": "The critical path now runs from the forecast to the evidence: the cost comparison against the "
                 "market operator, and the report. No budget contingency is needed.",
         "size": 12.5, "color": BODY, "line": 1.0},
    ], tag="s2.progress")

    # left bottom: risks and surprises
    deck.block(s2, COL1_X, 4.30, COL1_W,
               [{"text": "WHAT WENT WRONG, AND WHAT SURPRISED US", "size": 11, "bold": True, "color": ACCENT}], tag="s2.h2")
    deck.block(s2, COL1_X, 4.60, COL1_W, [
        {"text": "All three charter risks happened: data integrity, forecast accuracy below target, and an "
                 "undefined interface between our two modules. All three countermeasures held.",
         "size": 12, "color": BODY, "after": 7, "line": 1.0},
        {"text": "None of them was the surprise. Our own tooling was. A parsing defect had silently discarded the "
                 "record of actual prices since the store was created, and a time-zone setting logged live prices "
                 "against the wrong clock. That cost a week and a month of samples.",
         "size": 12, "color": BODY, "line": 1.0},
    ], tag="s2.risks")

    # right: two lessons
    deck.block(s2, COL2_X, 1.50, COL2_W,
               [{"text": "TWO LESSONS, EACH WITH AN ACTION TAKEN", "size": 11, "bold": True, "color": GREEN}], tag="s2.h3")

    lesson1 = [
        {"text": "1.  Audit how we measure before challenging the data.", "size": 13, "bold": True, "color": NAVY, "after": 4},
        {"text": "We suspected the market data. The fault was in our own capture code, and it had been there for a "
                 "month. Action: a cross-source audit is now a required release step, and pipeline correctness is a "
                 "weekly measure reported to the team.",
         "size": 11.5, "color": BODY, "line": 1.0},
    ]
    lesson2 = [
        {"text": "2.  Fix the comparison first; it sets the scope.", "size": 13, "bold": True,
         "color": NAVY, "after": 4},
        {"text": "The charter asked for one good forecast and left the horizon open. We found no model wins at every "
                 "horizon, so we fixed the comparison instead: a one-hour control horizon, matching the only horizon "
                 "the market operator publishes. Action: our forecast drives the controller over that hour, and "
                 "longer horizons became a scheduled decision rather than an open question.",
         "size": 11.5, "color": BODY, "after": 5, "line": 1.0},
        {"text": "Process fix: a decision log, and one integration test owned by each person.",
         "size": 11.5, "bold": True, "color": GREEN, "line": 1.0},
    ]

    lesson_inner = COL2_W - 0.44
    y = 1.80
    for specs, tag in ((lesson1, "s2.lesson1"), (lesson2, "s2.lesson2")):
        panel_h = text_height(specs, lesson_inner) + 0.34
        panel_h = max(0.95, panel_h - 0.16)
        deck.panel(s2, COL2_X, y, COL2_W, panel_h)
        deck.block(s2, COL2_X + 0.22, y + 0.13, lesson_inner, specs, tag=tag)
        y += panel_h + 0.16

    deck.rule(s2, 0.55, 6.94, 12.23)
    deck.block(s2, 0.55, 7.04, 12.2,
               [{"text": "Slide 2 of 2  |  prepared with AI assistance, reviewed and verified by the author.",
                 "size": 9.5, "color": MUTED}], tag="s2.foot")

    # ============================================== slide 3: backup chart for Q&A
    s3 = deck.slide()
    deck.block(s3, 0.55, 0.34, 12.2,
               [{"text": "Backup: updated schedule against the charter baseline", "size": 24, "bold": True,
                 "color": NAVY, "line": 1.0}], tag="s3.title")
    deck.block(s3, 0.55, 0.94, 12.2,
               [{"text": "Not part of the five-minute presentation. Shown only if the sponsor asks for the chart.",
                 "size": 11.5, "color": MUTED}], tag="s3.sub")
    deck.rule(s3, 0.55, 1.28, 12.23)

    # week ruler
    GX, GY = 4.62, 1.75
    WD = 0.66
    for i, label in enumerate(["W1", "W2", "W3", "W4", "W5", "W6", "W7", "W8", "W9", "W10", "W11", "W12"]):
        deck.block(s3, GX + i * WD, GY - 0.28, WD,
                   [{"text": label, "size": 9, "color": MUTED}], tag=f"s3.w{i}")
    deck.rule(s3, GX, GY - 0.06, WD * 12, RULE)

    # rows: label, planned start week index, planned length in weeks, progress 0..1, complete,
    #       milestone week index (or None)
    rows = [
        ("Literature review", 0, 1, 1.0, True, None),
        ("Data pipeline build", 0, 1, 1.0, True, None),
        ("Capture-script defect fix", 3, 1, 1.0, True, None),
        ("Data audit and rebuild", 6, 1, 1.0, True, None),
        ("Forecaster v1", 1, 2, 1.0, True, None),
        ("Forecaster benchmark, 9 models", 8, 2, 1.0, True, 4),
        ("Controller v1, single tank", 3, 1, 1.0, True, None),
        ("Three-pump rolling MPC", 4, 2, 1.0, True, None),
        ("Forecaster to controller link", 8, 2, 1.0, True, 7),
        ("Cost comparison vs AEMO", 10, 1, 0.6, False, None),
        ("Final report", 10, 2, 0.4, False, 11),
    ]
    ROW_H = 0.30
    MID = 0.032
    BAR_H = 0.125
    y = GY + 0.32
    for label, start, length, progress, done, milestone in rows:
        frame = s3.shapes.add_textbox(Inches(0.55), Inches(y - 0.015), Inches(4.00), Inches(0.20)).text_frame
        frame.word_wrap = False
        frame.margin_left = 0
        frame.margin_right = 0
        frame.margin_top = 0
        frame.margin_bottom = 0
        para = frame.paragraphs[0]
        run = para.add_run()
        run.text = label
        run.font.size = Pt(10)
        run.font.color.rgb = INK
        run.font.name = FONT
        track = deck.panel(s3, GX + start * WD, y, length * WD - 0.06, BAR_H)
        track.fill.solid()
        track.fill.fore_color.rgb = RGBColor(0xE3, 0xE9, 0xEF)
        if progress > 0:
            fill = GREEN if done else AMBER
            bar = deck.panel(s3, GX + start * WD, y, (length * WD - 0.06) * progress, BAR_H)
            bar.fill.solid()
            bar.fill.fore_color.rgb = fill
            bar.line.fill.background()
        if milestone is not None:
            # small plan marker below the bar: when the charter said this had to be finished
            mark = s3.shapes.add_shape(
                MSO_SHAPE.DIAMOND, Inches(GX + milestone * WD - 0.055), Inches(y + BAR_H + 0.032),
                Inches(0.11), Inches(0.11))
            mark.fill.solid()
            mark.fill.fore_color.rgb = NAVY
            mark.line.fill.background()
            sp_pr = mark._element.spPr
            sp_pr.append(parse_xml(f'<a:effectLst xmlns:a="{NS_A}"/>'))
        y += ROW_H

    # today marker: two short lines sit above the week row without touching the week labels
    today_x = GX + 10.0 * WD
    deck.rule(s3, today_x, GY - 0.10, 0.02, AMBER, weight=1.6)
    deck.block(s3, today_x - 0.90, 1.40, 0.85,
               [{"text": "today", "size": 9, "bold": True, "color": AMBER, "line": 0.95},
                {"text": "(W11)", "size": 9, "bold": True, "color": AMBER, "line": 0.95}], tag="s3.today")

    legend = [
        ("Complete", GREEN),
        ("In progress", AMBER),
        ("Not started", RGBColor(0xB8, 0xC2, 0xCC)),
        ("Milestone in the plan", NAVY),
    ]
    lx = 0.55
    for text, colour in legend:
        if text.startswith("Milestone"):
            chip = s3.shapes.add_shape(MSO_SHAPE.DIAMOND, Inches(lx + 0.05), Inches(5.95),
                                       Inches(0.11), Inches(0.11))
            chip.fill.solid()
            chip.fill.fore_color.rgb = colour
            chip.line.fill.background()
            chip._element.spPr.append(parse_xml(f'<a:effectLst xmlns:a="{NS_A}"/>'))
        else:
            chip = deck.panel(s3, lx, 5.95, 0.20, 0.11)
            chip.fill.solid()
            chip.fill.fore_color.rgb = colour
            chip.line.fill.background()
        deck.block(s3, lx + 0.28, 5.91, 1.35, [{"text": text, "size": 10, "color": BODY}], tag=f"s3.leg{text[:4]}")
        lx += 1.90

    deck.block(s3, 0.55, 6.26, 12.2, [
        {"text": "Baseline milestones: forecaster validated 31 August, working controller 21 September (both met, "
                 "the controller date by about two weeks), final report 14 October. The chart itself was never revised "
                 "after submission, which is why it still shows the completed work as zero.",
         "size": 11, "color": BODY, "line": 1.05},
    ], tag="s3.note")

    deck.rule(s3, 0.55, 6.94, 12.23)
    deck.block(s3, 0.55, 7.04, 12.2,
               [{"text": "Backup slide, not presented. Built from the charter Gantt chart and the repository commit history.",
                 "size": 9.5, "color": MUTED}], tag="s3.foot")

    deck.save(OUT_PPTX)

    print("saved:", OUT_PPTX)
    print(f"slides: {len(prs.slides)}")
    print("\ncomputed box geometry (x, y, w, h in inches):")
    worst = 0.0
    for tag, x, y, w, h in deck.report:
        bottom = y + h
        worst = max(worst, bottom)
        print(f"  {tag:14s} ({x:5.2f},{y:5.2f}) {w:5.2f} x {h:4.2f}   bottom {bottom:5.2f}")
    print(f"lowest content bottom: {worst:.2f} in (slide height 7.50, footer rule at 6.94)")


if __name__ == "__main__":
    build()
