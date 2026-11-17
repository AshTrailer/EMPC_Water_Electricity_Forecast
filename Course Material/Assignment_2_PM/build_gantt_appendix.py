"""Appendix schedule: every task from the charter work breakdown, baseline and current.

Two sheets. Sheet 1 is the baseline as it was submitted. Sheet 2 is the same 32 tasks with what
has actually happened to each. Splitting the two keeps each timeline wide enough to read.
"""

from datetime import date
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml import parse_xml
from pptx.util import Inches, Pt

OUT = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM\Capstone_Schedule_Appendix.pptx"

NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main"
FONT = "Calibri"

INK = RGBColor(0x1B, 0x24, 0x30)
TITLE = RGBColor(0x1E, 0x27, 0x61)
MUTED = RGBColor(0x5A, 0x6B, 0x7B)
GRID = RGBColor(0xE3, 0xE8, 0xED)
PLAN = RGBColor(0xB4, 0xC2, 0xD2)
PLAN_EDGE = RGBColor(0x92, 0xA3, 0xB5)
DONE = RGBColor(0x0E, 0x7C, 0x7B)
PART = RGBColor(0x6F, 0xA8, 0xDC)
ACTIVE = RGBColor(0xE9, 0xA8, 0x20)
IDLE = RGBColor(0xD6, 0xDD, 0xE4)
BAND = RGBColor(0xF6, 0xF9, 0xFB)

START = date(2026, 7, 6)
END = date(2026, 11, 20)
TODAY = date(2026, 10, 16)

LABEL_X, LABEL_W = 0.55, 4.35
CHART_X, CHART_W = 5.05, 7.75
ROW_TOP, ROW_H = 1.42, 0.155
BAR_H = 0.092

# group title, then rows: (number, name, baseline start, baseline finish, status)
GROUPS = [
    ("1  Project kick-off and team meeting", [
        (1, "Project kick-off and first team/mentor meeting", (2026, 8, 7), (2026, 8, 7), "done"),
    ]),
    ("2  Literature review", [
        (2, "Literature review", (2026, 8, 7), (2026, 8, 12), "done"),
        (3, "Read related papers on pumping and price forecasting", (2026, 8, 7), (2026, 8, 12), "done"),
    ]),
    ("4  System infrastructure, baseline control and data preparation", [
        (5, "Download AEMO historical data", (2026, 8, 7), (2026, 8, 7), "done"),
        (6, "Data pipeline, filtering and controller API test system", (2026, 8, 10), (2026, 8, 12), "done"),
        (7, "P controller for simple closed-loop level control", (2026, 8, 13), (2026, 8, 14), "done"),
        (8, "Baseline system operational", (2026, 8, 14), (2026, 8, 14), "done"),
    ]),
    ("9  Predictive modelling, validation and theoretical framework", [
        (10, "Update RLS from filter to recursive AR predictor", (2026, 8, 17), (2026, 8, 18), "done"),
        (11, "Implement Kalman predictor (HSSKF)", (2026, 8, 17), (2026, 8, 18), "done"),
        (12, "Error versus prediction horizon experiment", (2026, 8, 19), (2026, 8, 20), "done"),
        (13, "Theoretical derivation and evaluation metrics", (2026, 8, 21), (2026, 8, 25), "done"),
    ]),
    ("14  Predictor testing", [
        (15, "Test predictor update-time settings", (2026, 8, 26), (2026, 8, 27), "done"),
        (16, "Test weekday versus weekend data", (2026, 8, 26), (2026, 8, 27), "part"),
        (17, "Test different training windows", (2026, 8, 26), (2026, 8, 27), "part"),
        (18, "Prepare mathematical description for report", (2026, 8, 28), (2026, 8, 31), "done"),
        (19, "Predictor validated against target error", (2026, 8, 31), (2026, 8, 31), "done"),
    ]),
    ("20  MPC and EMPC development", [
        (21, "First version MPC controller", (2026, 8, 26), (2026, 8, 31), "done"),
        (22, "Test solver on simple water level control", (2026, 9, 1), (2026, 9, 3), "done"),
        (23, "Integrate price predictor into EMPC objective", (2026, 9, 4), (2026, 9, 10), "done"),
        (24, "Build full tank and pump simulation scenario", (2026, 9, 4), (2026, 9, 10), "done"),
        (25, "EMPC versus baseline comparison and tuning", (2026, 9, 11), (2026, 9, 21), "part"),
        (26, "EMPC framework operational", (2026, 9, 21), (2026, 9, 21), "done"),
    ]),
    ("27  Results and reporting", [
        (28, "Official forecast products and release calibres", (2026, 9, 22), (2026, 9, 25), "done"),
        (29, "Weekly reporting to supervisor", (2026, 7, 9), (2026, 10, 15), "done"),
        (30, "Write Assignment 2 retrospective", (2026, 9, 28), (2026, 10, 9), "active"),
        (31, "Final capstone report submitted", (2026, 9, 28), (2026, 10, 9), "active"),
        (32, "Prepare for mid-semester review", (2026, 10, 12), (2026, 11, 13), "active"),
    ]),
]

# sheet 2 only: what actually happened, and the state at 16 October
CURRENT = {
    1: ((2026, 8, 7), (2026, 8, 7), "done"),
    2: ((2026, 8, 7), (2026, 8, 12), "done"),
    3: ((2026, 8, 7), (2026, 8, 12), "done"),
    5: ((2026, 8, 7), (2026, 8, 7), "done"),
    6: ((2026, 8, 7), (2026, 9, 15), "done"),
    7: ((2026, 8, 10), (2026, 8, 14), "done"),
    8: ((2026, 8, 14), (2026, 8, 14), "done"),
    10: ((2026, 8, 17), (2026, 9, 15), "done"),
    11: ((2026, 8, 17), (2026, 8, 20), "done"),
    12: ((2026, 8, 26), (2026, 9, 23), "done"),
    13: ((2026, 8, 26), (2026, 10, 13), "done"),
    15: ((2026, 8, 26), (2026, 10, 9), "done"),
    16: ((2026, 9, 20), (2026, 10, 9), "part"),
    17: ((2026, 10, 8), (2026, 10, 15), "part"),
    18: ((2026, 9, 20), (2026, 10, 13), "done"),
    19: ((2026, 10, 9), (2026, 10, 9), "done"),
    21: ((2026, 8, 26), (2026, 9, 5), "done"),
    22: ((2026, 9, 5), (2026, 9, 14), "done"),
    23: ((2026, 9, 24), (2026, 9, 24), "done"),
    24: ((2026, 9, 5), (2026, 10, 8), "done"),
    25: ((2026, 10, 9), (2026, 10, 16), "part"),
    26: ((2026, 9, 24), (2026, 9, 24), "done"),
    28: ((2026, 9, 24), (2026, 10, 15), "done"),
    29: ((2026, 7, 9), (2026, 10, 15), "done"),
    30: ((2026, 10, 12), (2026, 10, 16), "active"),
    31: ((2026, 10, 12), (2027, 6, 30), "active"),
    32: ((2026, 10, 12), (2026, 11, 13), "active"),
}

STATUS_TEXT = {"done": "Complete", "part": "Partial", "active": "In progress"}
STATUS_COLOR = {"done": DONE, "part": PART, "active": ACTIVE}


def no_shadow(shape):
    sp_pr = shape._element.spPr
    for tag in ("effectLst", "effectDag"):
        for node in sp_pr.findall(f"{{{NS_A}}}{tag}"):
            sp_pr.remove(node)
    sp_pr.append(parse_xml(f'<a:effectLst xmlns:a="{NS_A}"/>'))


def pos(d):
    return CHART_X + CHART_W * (d - START).days / (END - START).days


class Deck:
    def __init__(self):
        self.prs = Presentation()
        self.prs.slide_width = Inches(13.333)
        self.prs.slide_height = Inches(7.5)
        self.slide = None

    def new(self):
        self.slide = self.prs.slides.add_slide(self.prs.slide_layouts[6])

    def text(self, x, y, w, h, runs, align=PP_ALIGN.LEFT):
        frame = self.slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)).text_frame
        frame.word_wrap = False
        frame.vertical_anchor = MSO_ANCHOR.TOP
        frame.margin_left = frame.margin_right = frame.margin_top = frame.margin_bottom = 0
        for i, spec in enumerate(runs):
            para = frame.paragraphs[0] if i == 0 else frame.add_paragraph()
            para.alignment = align
            para.line_spacing = 0.95
            run = para.add_run()
            run.text = spec["text"]
            run.font.size = Pt(spec["size"])
            run.font.bold = spec.get("bold", False)
            run.font.color.rgb = spec.get("color", INK)
            run.font.name = FONT
        return frame

    def rect(self, x, y, w, h, fill=None, edge=None, edge_w=0.6):
        shape = self.slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(x), Inches(y),
                                            Inches(max(w, 0.008)), Inches(max(h, 0.008)))
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
        no_shadow(shape)
        return shape

    def dot(self, cx, cy, size, fill):
        shape = self.slide.shapes.add_shape(MSO_SHAPE.DIAMOND, Inches(cx - size / 2), Inches(cy - size / 2),
                                            Inches(size), Inches(size))
        shape.fill.solid()
        shape.fill.fore_color.rgb = fill
        shape.line.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        shape.line.width = Pt(0.75)
        no_shadow(shape)


def draw(deck, sheet_no, title, subtitle, use_current):
    deck.new()
    deck.text(0.55, 0.30, 12.2, 0.34,
              [{"text": title, "size": 18, "bold": True, "color": TITLE}])
    deck.text(0.55, 0.68, 12.2, 0.24,
              [{"text": subtitle, "size": 9.5, "color": MUTED}])

    # ruler
    for month, label in [(date(2026, 7, 1), "July"), (date(2026, 8, 1), "August"),
                         (date(2026, 9, 1), "September"), (date(2026, 10, 1), "October"),
                         (date(2026, 11, 1), "November")]:
        x = pos(month)
        if CHART_X <= x <= CHART_X + CHART_W:
            deck.text(x + 0.03, 1.12, 1.0, 0.18, [{"text": label, "size": 8.5, "bold": True, "color": MUTED}])
            deck.rect(x, 1.30, 0.006, ROW_TOP + ROW_H * 40 - 1.30, fill=GRID)

    y = ROW_TOP
    row = 0
    for group, items in GROUPS:
        deck.text(LABEL_X, y - 0.005, LABEL_W, 0.16,
                  [{"text": group, "size": 8.5, "bold": True, "color": TITLE}])
        y += ROW_H
        row += 1
        for number, name, bs, be, status in items:
            if row % 2 == 0:
                deck.rect(0.42, y - 0.012, 12.55, ROW_H - 0.012, fill=BAND)
            deck.text(LABEL_X, y, 0.30, 0.15, [{"text": str(number), "size": 7.5, "color": MUTED}])
            deck.text(LABEL_X + 0.30, y, LABEL_W - 0.30, 0.15,
                      [{"text": name, "size": 7.5, "color": INK}])
            if use_current:
                data = CURRENT.get(number)
                if data is None:
                    deck.text(CHART_X, y, 2.0, 0.15,
                              [{"text": "not started", "size": 7.5, "color": MUTED}])
                else:
                    as_, ae, state = data
                    x0, x1 = pos(date(*as_)), pos(date(*ae))
                    deck.rect(x0, y + 0.022, x1 - x0, BAR_H, fill=STATUS_COLOR[state])
                    deck.text(CHART_X + CHART_W + 0.10, y, 1.3, 0.15,
                              [{"text": STATUS_TEXT[state], "size": 7.5,
                                "color": STATUS_COLOR[state], "bold": True}])
            else:
                x0, x1 = pos(date(*bs)), pos(date(*be))
                deck.rect(x0, y + 0.022, max(x1 - x0, 0.012), BAR_H, fill=PLAN, edge=PLAN_EDGE)
                if bs == be:
                    deck.dot(x0, y + 0.022 + BAR_H / 2, 0.085, PLAN_EDGE)
                deck.text(CHART_X + CHART_W + 0.10, y, 1.3, 0.15,
                          [{"text": "Milestone" if bs == be else "Planned", "size": 7.5, "color": MUTED}])
            y += ROW_H
            row += 1

    if use_current:
        tx = pos(TODAY)
        deck.rect(tx, 1.30, 0.010, ROW_TOP + ROW_H * 40 - 1.30, fill=ACTIVE)
        deck.text(tx - 0.60, 0.94, 1.2, 0.18,
                  [{"text": "today, 16 Oct", "size": 8.5, "bold": True, "color": RGBColor(0xB2, 0x7A, 0x0E)}],
                  align=PP_ALIGN.CENTER)

    footer_y = 7.06
    deck.rect(0.55, footer_y - 0.10, 12.23, 0.008, fill=GRID)
    if use_current:
        items = [("Complete", DONE), ("Partially complete", PART), ("In progress", ACTIVE)]
        lx = 0.55
        for label, colour in items:
            deck.rect(lx, footer_y, 0.18, 0.092, fill=colour)
            deck.text(lx + 0.24, footer_y - 0.012, 1.6, 0.18, [{"text": label, "size": 8.5, "color": INK}])
            lx += 1.75
        deck.text(6.30, footer_y - 0.012, 6.5, 0.18,
                  [{"text": "Task numbers follow the charter work breakdown. Baseline dates are those submitted on 28 August.",
                    "size": 8.5, "color": MUTED}])
    else:
        deck.rect(0.55, footer_y, 0.18, 0.092, fill=PLAN, edge=PLAN_EDGE)
        deck.text(0.79, footer_y - 0.012, 2.0, 0.18, [{"text": "Planned duration", "size": 8.5, "color": INK}])
        deck.dot(3.05, footer_y + 0.046, 0.085, PLAN_EDGE)
        deck.text(3.16, footer_y - 0.012, 2.0, 0.18, [{"text": "Milestone, zero duration", "size": 8.5, "color": INK}])
        deck.text(6.30, footer_y - 0.012, 6.5, 0.18,
                  [{"text": "Task numbers follow the charter work breakdown. This is the plan as submitted on 28 August.",
                    "size": 8.5, "color": MUTED}])
    deck.text(0.55, 7.28, 12.2, 0.18,
              [{"text": f"Appendix sheet {sheet_no} of 2.", "size": 8, "color": MUTED}])


def main():
    deck = Deck()
    draw(deck, 1,
         "Appendix A  Schedule as planned: work breakdown at charter submission",
         "The baseline plan, 7 August to 14 October 2026. Thirty-two tasks in seven work breakdown groups.",
         use_current=False)
    draw(deck, 2,
         "Appendix B  Schedule as delivered: the same work breakdown at 16 October",
         "The same thirty-two tasks with actual dates. The dashed line marks today. Tasks without a bar have not begun.",
         use_current=True)
    deck.prs.save(OUT)
    print("wrote", OUT)
    print("sheets:", len(deck.prs.slides))


if __name__ == "__main__":
    main()
