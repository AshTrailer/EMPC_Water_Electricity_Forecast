"""Draw the one-page project schedule as editable PowerPoint shapes.

Baseline and delivered work sit on the same row so the slip is visible without reading a legend,
and every bar carries its own dates. Drawn as vector shapes rather than a raster image so the
chart stays sharp in print and can be corrected by hand.
"""

from datetime import date
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml import parse_xml
from pptx.util import Inches, Pt

OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM\Capstone_Schedule_v1_vs_v2.pptx"

NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main"
FONT = "Calibri"

INK = RGBColor(0x1B, 0x24, 0x30)
TITLE = RGBColor(0x1E, 0x27, 0x61)
MUTED = RGBColor(0x5A, 0x6B, 0x7B)
GRID = RGBColor(0xE3, 0xE8, 0xED)
PLAN = RGBColor(0xC3, 0xCF, 0xDB)
PLAN_EDGE = RGBColor(0x9C, 0xAC, 0xBC)
DONE = RGBColor(0x0E, 0x7C, 0x7B)
ACTIVE = RGBColor(0xE9, 0xA8, 0x20)
SLIP = RGBColor(0xC0, 0x39, 0x2B)
BAND = RGBColor(0xF7, 0xF9, 0xFB)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

START = date(2026, 8, 3)
END = date(2026, 11, 16)
TODAY = date(2026, 10, 16)

LABEL_X, LABEL_W = 0.55, 3.28
CHART_X, CHART_W = 3.95, 8.85
ROW_TOP, ROW_H = 1.50, 0.395
BAR_H = 0.140
GAP = 0.030
TODAY_COL = RGBColor(0xE9, 0xA8, 0x20)

# name, baseline start, baseline end, actual start, actual end, state, note
ROWS = [
    ("Literature review", (2026, 8, 7), (2026, 8, 12), (2026, 8, 7), (2026, 8, 12), "done", ""),
    ("AEMO data collection and pipeline", (2026, 8, 7), (2026, 8, 14), (2026, 8, 7), (2026, 9, 15), "done", "built early, reworked later"),
    ("Baseline level control running", (2026, 8, 10), (2026, 8, 14), (2026, 8, 10), (2026, 8, 14), "done", ""),
    ("Predictor development", (2026, 8, 17), (2026, 8, 25), (2026, 8, 17), (2026, 9, 15), "done", "ran in parallel with MPC"),
    ("Predictor testing and evaluation", (2026, 8, 26), (2026, 8, 31), (2026, 8, 26), (2026, 10, 9), "done", ""),
    ("Data and method audit", (2026, 9, 21), (2026, 9, 25), (2026, 9, 23), (2026, 9, 24), "done", "five capture defects fixed"),
    ("MPC development", (2026, 8, 26), (2026, 9, 10), (2026, 8, 26), (2026, 10, 8), "done", "ran in parallel with predictor"),
    ("Predictor and MPC integration", (2026, 9, 4), (2026, 9, 10), (2026, 9, 24), (2026, 9, 24), "done", "held back by design, then delivered"),
    ("Official forecasts: product and data comparison", (2026, 9, 28), (2026, 10, 9), (2026, 9, 24), (2026, 10, 15), "done", "different release calibres"),
    ("Cost comparison against AEMO", (2026, 9, 11), (2026, 9, 21), (2026, 10, 9), (2026, 10, 18), "active", ""),
    ("Report and mid-semester review", (2026, 9, 22), (2026, 11, 13), (2026, 10, 12), (2026, 11, 13), "active", ""),
]


def serial(d):
    return (d - START).days


def pos(d):
    return CHART_X + CHART_W * serial(d) / (END - START).days


def no_shadow(shape):
    sp_pr = shape._element.spPr
    for tag in ("a:effectLst", "a:effectDag"):
        for node in sp_pr.findall(f"{{{NS_A}}}{tag.split(':')[1]}"):
            sp_pr.remove(node)
    sp_pr.append(parse_xml(f'<a:effectLst xmlns:a="{NS_A}"/>'))


class Sheet:
    def __init__(self):
        self.prs = Presentation()
        self.prs.slide_width = Inches(13.333)
        self.prs.slide_height = Inches(7.5)
        self.slide = self.prs.slides.add_slide(self.prs.slide_layouts[6])

    def text(self, x, y, w, h, runs, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP):
        frame = self.slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)).text_frame
        frame.word_wrap = True
        frame.vertical_anchor = anchor
        frame.margin_left = frame.margin_right = frame.margin_top = frame.margin_bottom = 0
        for i, spec in enumerate(runs):
            para = frame.paragraphs[0] if i == 0 else frame.add_paragraph()
            para.alignment = align
            para.line_spacing = spec.get("line", 0.95)
            para.space_after = Pt(spec.get("after", 0))
            run = para.add_run()
            run.text = spec["text"]
            run.font.size = Pt(spec["size"])
            run.font.bold = spec.get("bold", False)
            run.font.italic = spec.get("italic", False)
            run.font.color.rgb = spec.get("color", INK)
            run.font.name = FONT
        return frame

    def rect(self, x, y, w, h, fill=None, edge=None, edge_w=0.75, rounded=False, dashed=False):
        kind = MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE
        shape = self.slide.shapes.add_shape(kind, Inches(x), Inches(y), Inches(max(w, 0.01)), Inches(h))
        if rounded:
            shape.adjustments[0] = 0.22
        if fill is None:
            shape.fill.background()
        else:
            shape.fill.solid()
            shape.fill.fore_color.rgb = fill
        if edge is None:
            shape.line.fill.background()
        else:
            shape.line.color.rgb = edge
            shape.line.width = Pt(edge_w)
            if dashed:
                shape.line.dash_style = 4
        no_shadow(shape)
        return shape

    def diamond(self, cx, cy, size, fill, edge):
        shape = self.slide.shapes.add_shape(MSO_SHAPE.DIAMOND, Inches(cx - size / 2),
                                            Inches(cy - size / 2), Inches(size), Inches(size))
        shape.fill.solid()
        shape.fill.fore_color.rgb = fill
        shape.line.color.rgb = edge
        shape.line.width = Pt(1.0)
        no_shadow(shape)
        return shape

    def save(self):
        self.prs.save(OUT)


def main():
    sheet = Sheet()
    s = sheet.slide

    sheet.text(0.55, 0.30, 11.0, 0.45,
               [{"text": "Project schedule: charter baseline against progress at 16 October",
                 "size": 21, "bold": True, "color": TITLE}])
    sheet.text(0.55, 0.82, 11.6, 0.30,
               [{"text": "Upper bar on each row is the plan submitted on 28 August. Lower bar is what was delivered. "
                         "Where a bar finishes after its plan, the gap carries the slip in days.",
                 "size": 10, "color": MUTED}])

    # month ruler and verticals, drawn only over the chart columns
    months = [(date(2026, 9, 1), "September"), (date(2026, 10, 1), "October"),
              (date(2026, 11, 1), "November")]
    chart_bottom = ROW_TOP + ROW_H * len(ROWS)
    for when, label in months:
        x = pos(when)
        if x < CHART_X - 0.01 or x > CHART_X + CHART_W:
            continue
        sheet.rect(x, ROW_TOP - 0.06, 0.0075, chart_bottom - ROW_TOP + 0.06, fill=GRID)
        sheet.text(x + 0.06, ROW_TOP - 0.32, 1.2, 0.22,
                   [{"text": label, "size": 10.5, "bold": True, "color": MUTED}])
    for week in range(0, (END - START).days + 1, 14):
        d = date.fromordinal(START.toordinal() + week)
        x = pos(d)
        if CHART_X - 0.01 <= x <= CHART_X + CHART_W:
            sheet.rect(x, ROW_TOP, 0.004, chart_bottom - ROW_TOP, fill=GRID)

    for i, (name, bs, be, as_, ae, state, note) in enumerate(ROWS):
        top = ROW_TOP + i * ROW_H
        if i % 2 == 0:
            sheet.rect(0.42, top, 12.55, ROW_H, fill=BAND)
        mid = top + ROW_H / 2
        sheet.text(LABEL_X, top + 0.075, LABEL_W, 0.21,
                   [{"text": name, "size": 10.5, "color": INK}])
        if note:
            sheet.text(LABEL_X, top + 0.235, LABEL_W, 0.17,
                       [{"text": note, "size": 8.5, "italic": True, "color": MUTED}])

        # baseline bar (upper)
        b0, b1 = pos(date(*bs)), pos(date(*be))
        sheet.rect(b0, mid - GAP - BAR_H, b1 - b0, BAR_H, fill=PLAN, edge=PLAN_EDGE, edge_w=0.5, rounded=True)

        # delivered bar (lower)
        a0, a1 = pos(date(*as_)), pos(date(*ae))
        if state == "done":
            sheet.rect(a0, mid + GAP, a1 - a0, BAR_H, fill=DONE, rounded=True)
        else:
            sheet.rect(a0, mid + GAP, a1 - a0, BAR_H, fill=None, edge=ACTIVE, edge_w=1.1,
                       rounded=True, dashed=True)
            sheet.rect(a0, mid + GAP, pos(TODAY) - a0, BAR_H, fill=ACTIVE, rounded=True)

        # slip: how much later the work finished than the plan allowed
        slip_days = (date(*ae) - date(*be)).days
        if slip_days > 0:
            anchor = max(a1, b1)
            sheet.text(anchor + 0.05, mid - 0.10, 0.60, 0.19,
                       [{"text": f"+{slip_days}d", "size": 9, "bold": True, "color": SLIP}])

    # Two separate milestone bands. Planned markers sit above delivered ones so that labels from
    # the two families can never collide, however close the dates are.
    plan_y = ROW_TOP + ROW_H * len(ROWS) + 0.16
    done_y = plan_y + 0.46
    planned = [(date(2026, 8, 14), "baseline live"),
               (date(2026, 8, 31), "predictor"),
               (date(2026, 9, 21), "framework planned"),
               (date(2026, 11, 13), "mid-semester review")]
    reached = [(date(2026, 9, 24), "integration"),
               (date(2026, 10, 8), "controller"),
               (date(2026, 10, 15), "official data")]
    for when, label in planned:
        sheet.diamond(pos(when), plan_y, 0.12, WHITE, PLAN_EDGE)
        sheet.text(pos(when) - 0.80, plan_y + 0.10, 1.60, 0.18,
                   [{"text": label, "size": 8.5, "color": MUTED}], align=PP_ALIGN.CENTER)
    for when, label in reached:
        sheet.diamond(pos(when), done_y, 0.12, DONE, WHITE)
        sheet.text(pos(when) - 0.80, done_y + 0.10, 1.60, 0.18,
                   [{"text": label, "size": 8.5, "bold": True, "color": DONE}], align=PP_ALIGN.CENTER)

    # today marker across the whole chart
    tx = pos(TODAY)
    sheet.rect(tx, ROW_TOP - 0.06, 0.011, chart_bottom - ROW_TOP + 0.06, fill=TODAY_COL)
    sheet.text(tx - 0.75, ROW_TOP - 0.62, 1.5, 0.22,
               [{"text": "today, 16 Oct", "size": 9.5, "bold": True, "color": RGBColor(0xB2, 0x7A, 0x0E)}],
               align=PP_ALIGN.CENTER)

    # legend
    lx, ly = 0.55, done_y + 0.34
    items = [(PLAN, "Charter baseline"), (DONE, "Delivered"), (ACTIVE, "In progress"), (SLIP, "Slip in days")]
    for colour, label in items:
        sheet.rect(lx, ly + 0.035, 0.22, 0.115, fill=colour, rounded=True)
        sheet.text(lx + 0.28, ly, 1.6, 0.22, [{"text": label, "size": 9.5, "color": INK}])
        lx += 1.62
    sheet.diamond(lx + 0.11, ly + 0.095, 0.13, WHITE, PLAN_EDGE)
    sheet.text(lx + 0.26, ly, 1.9, 0.22, [{"text": "Milestone planned", "size": 9.5, "color": INK}])
    lx += 2.05
    sheet.diamond(lx + 0.11, ly + 0.095, 0.13, DONE, WHITE)
    sheet.text(lx + 0.26, ly, 1.9, 0.22, [{"text": "Milestone delivered", "size": 9.5, "color": INK}])

    sheet.text(0.55, ly + 0.34, 12.2, 0.30,
               [{"text": "Integration was delivered on 24 September, inside its planned week. The delay sits in "
                         "reconciling the official forecast products.",
                 "size": 9.5, "color": MUTED}])

    sheet.save()
    print("wrote", OUT)


if __name__ == "__main__":
    main()
