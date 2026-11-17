"""Build the Assignment 2 Part 2 briefing deck: exactly two 16:9 slides, based on the v7 report.

The brief allows at most two slides for the oral presentation, so the deck carries no backup slide:
background and context occupy the left half of slide 1, progress the right half, and slide 2 is the
retrospective proper (the surprise, the hardest part, how the team handled it) followed by two
lessons, each paired with an action that is already in place.

Layout rule: every text box height is computed from the text it holds with a conservative Calibri
glyph-width estimate, then asserted against the footer rule. Autoshapes have their theme style
stripped, so no shape inherits the template's shadow or accent references.
"""

import sys

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml import parse_xml
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main"
NS_P = "http://schemas.openxmlformats.org/presentationml/2006/main"

OUT_PPTX = (r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM"
            r"\Assignment2_PM_Slides_v2.pptx")

# ---------------------------------------------------------------- palette
NAVY = RGBColor(0x1F, 0x33, 0x55)
INK = RGBColor(0x22, 0x2B, 0x38)
BODY = RGBColor(0x3E, 0x47, 0x53)
MUTED = RGBColor(0x75, 0x80, 0x8C)
ACCENT = RGBColor(0x2F, 0x6F, 0xB5)
AMBER = RGBColor(0xB2, 0x62, 0x0F)
GREEN = RGBColor(0x1E, 0x7A, 0x46)
PANEL = RGBColor(0xF5, 0xF8, 0xFB)
CARD = RGBColor(0xF7, 0xFA, 0xF8)
RULE = RGBColor(0xDD, 0xE3, 0xEA)
HAIR = RGBColor(0xE8, 0xED, 0xF2)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

FONT = "Calibri"
EM = 0.48           # conservative average glyph width, em units
LINE = 1.22         # Calibri single-line height, em units
PAD = 0.05          # internal slack added to every computed box height

SW, SH = 13.333, 7.5
MARGIN = 0.62
CONTENT_W = SW - 2 * MARGIN           # 12.093
FOOTER_RULE_Y = 6.98
CONTENT_BOTTOM = 6.80

# ---------------------------------------------------------------- copy
TITLE_1 = "From plan to first results"
SUB_1 = "What the project is for, what we have delivered, and where it stands at the midpoint"

TITLE_2 = "What surprised us, and what we changed"
SUB_2 = "The hardest part of the project, and two lessons with actions already in place"

INTRO = [
    ("THE PROBLEM",
     "A water utility pays the wholesale power price, which changes every five minutes. Pumping can "
     "shift to the cheaper intervals, but only if the hours ahead can be predicted."),
    ("WHAT WE DELIVER",
     "Two linked deliverables: a price forecaster, and a controller that decides when each pump runs. "
     "The forecaster supplies prices; the controller keeps tanks within limits and moves pumping to "
     "the cheaper periods."),
    ("HOW WE ARE JUDGED",
     "Forecast error against the prices that actually occurred, and pumping cost against a schedule "
     "driven by the market operator's official forecast."),
]

STATUS = [
    ("MILESTONES", "All four milestones due by 16 October are met. The 13 November review is still "
                   "ahead."),
    ("WORK PACKAGES", "Work packages ran late behind the milestones: data by about a month; testing "
                      "and controller by four to five weeks."),
    ("INTEGRATION", "Live since 24 September. Our own forecast now drives the controller."),
    ("NEXT", "Cost comparison due 18 October, with one owner. Economic validation is the critical path."),
]

CARDS = [
    ("MILESTONES DUE", "4 / 4", "met by 16 October; the 13 November review is still ahead"),
    ("INTEGRATION", "24 Sep", "forecaster and controller running as one system"),
    ("EARLY COST EVIDENCE", "6%",
     "lower pumping cost over 60 days to 15 October than on the official forecast; daily rankings "
     "vary, so not yet a robust saving"),
]

SURPRISE = (
    "The charter flagged data integrity as a risk, and it did go wrong. Our controls caught stalled "
    "tasks, but nothing checked the data itself. The fault was internal: our data-capture code logged "
    "prices against the wrong clock, and another fault discarded most records. Our own audit found "
    "both. Fixing the code and rebuilding the series took a week."
)
HARDEST = (
    "Making the market operator's own forecast products comparable. They update at different "
    "intervals, look different distances ahead and are not all quoted the same way. Turning them into "
    "one series pushed integration to 24 September. The fix was to settle the target early: one "
    "actual five-minute price series, chosen on 4 September, now scores every model."
)
NOW = (
    "Decisions and blockers are logged at every weekly review, and each of us owns one end-to-end test "
    "across the components, so handovers no longer rely on memory. I rebuilt the stale shared "
    "schedule and check it weekly. Visible weekly targets keep the team moving."
)

LESSON_1 = ("Validate our own data before blaming the feed.",
            "The defects that cost us a week were in our own capture code, not the market feed.",
            "Action: before any result is reported, a cross-source check confirms every price record "
            "has the right time and is complete.")
LESSON_2 = ("Define the comparison before choosing models.",
            "Forecast accuracy moved with how far ahead we looked and with the time of day, so one "
            "average hid the pattern.",
            "Action: every result states its window and measure, and error is reported by how far "
            "ahead and by time of day.")
CLOSING = "Both actions are in place. Neither waits for the second half."

# ---------------------------------------------------------------- speaker notes
NOTES_1 = (
    "Our project turns a price forecast into pumping decisions for a water utility. Power prices "
    "move every five minutes, and pumping can follow the cheap intervals only if we can see the hours "
    "ahead. We build two connected pieces: the forecaster that supplies those prices, and the "
    "controller that decides when each pump runs while keeping the tank within its limits.\n\n"
    "We judge the work two ways: forecast error against prices that actually occurred, and pumping "
    "cost against a schedule driven by the market operator's official forecast. That second measure "
    "is the one the sponsor cares about, because it is the cost outcome.\n\n"
    "The four milestones were the baseline control running in mid-August, the first forecast model at "
    "the end of August, the controller framework in September, and the integration on 24 September. "
    "The mid-semester review on 13 November is the next formal checkpoint.\n\n"
    "At the midpoint, every milestone due by 16 October is met. The work behind them ran late: data "
    "by about a month, testing and controller by four to five weeks. Integration went live on "
    "24 September, and the early cost evidence is about six per cent lower pumping cost than on the "
    "official forecast. Daily rankings vary, so I present that as early evidence, not a proven "
    "saving. The cost comparison due on 18 October is the remaining critical path."
)
NOTES_2 = (
    "The surprise was not the market data. Our controls caught stalled tasks, but nothing checked the "
    "data itself. Our data-capture code logged prices against the wrong clock, and another fault "
    "discarded most records. Our own audit found both, and fixing the code and rebuilding the series "
    "took a week. "
    "That is the gap the charter's risk response did not cover.\n\n"
    "The hardest part was making the market operator's own forecast products comparable. They update "
    "at different intervals, look different distances ahead and are not quoted the same way. Turning "
    "them into one series pushed integration to 24 September. We handled it by fixing the target "
    "early: one actual five-minute price series, chosen on 4 September, now scores every model.\n\n"
    "On the team side, decisions and blockers are logged at each weekly review, each of us owns one "
    "end-to-end test across the components, and I rebuilt the stale shared schedule and check it "
    "weekly. Visible weekly targets keep the team engaged through validation.\n\n"
    "Two lessons, each with an action already in place. First, validate our own data before blaming "
    "the feed: before any result is reported, a cross-source check confirms every price record "
    "has the right time and is complete. Second, define the comparison before choosing models: every result now "
    "states its window and measure, and error is reported by how far ahead and by time of day. "
    "Neither action waits for the second half.\n\n"
    "The cost comparison due on 18 October will show whether that early cost edge holds. That "
    "evidence, not today's number, is what I will bring to the 13 November review."
)


# ---------------------------------------------------------------- measuring
def wrap_lines(text, size_pt, width_in):
    per_line = max(1.0, width_in / (size_pt * EM / 72.0))
    total = 0
    for chunk in text.split("\n"):
        n = len(chunk)
        total += max(1, int(n / per_line) + (1 if n % per_line else 0))
    return total


def specs_height(specs, width_in):
    total = 0.0
    for spec in specs:
        size = spec.get("size", 12)
        spacing = spec.get("line", 1.0)
        total += wrap_lines(spec["text"], size, width_in) * size * LINE * spacing / 72.0
        total += spec.get("after", 0) / 72.0
        total += spec.get("before", 0) / 72.0
    return total


class Deck:
    def __init__(self):
        self.prs = Presentation()
        self.prs.slide_width = Inches(SW)
        self.prs.slide_height = Inches(SH)
        self.boxes = []      # (tag, x, y, w, h)

    def slide(self):
        return self.prs.slides.add_slide(self.prs.slide_layouts[6])

    # ------------------------------------------------------------ primitives
    @staticmethod
    def strip_style(shape):
        """Remove the template's p:style so no theme shadow or accent leaks in."""
        element = shape._element
        for node in element.findall(f"{{{NS_P}}}style"):
            element.remove(node)

    def text(self, slide, x, y, w, specs, align=PP_ALIGN.LEFT, tag=""):
        needed = specs_height(specs, w)
        h = needed + PAD
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
            para.line_spacing = spec.get("line", 1.0)
            para.space_after = Pt(spec.get("after", 0))
            para.space_before = Pt(spec.get("before", 0))
            run = para.add_run()
            run.text = spec["text"]
            run.font.size = Pt(spec.get("size", 12))
            run.font.bold = spec.get("bold", False)
            run.font.italic = spec.get("italic", False)
            run.font.color.rgb = spec.get("color", INK)
            run.font.name = FONT
            if spec.get("track"):
                run._r.get_or_add_rPr().set("spc", str(spec["track"]))
        self.boxes.append((tag, x, y, w, h))
        return h

    def panel(self, slide, x, y, w, h, fill=PANEL, line=RULE, radius=0.035):
        shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,
                                       Inches(x), Inches(y), Inches(w), Inches(h))
        self.strip_style(shape)
        shape.fill.solid()
        shape.fill.fore_color.rgb = fill
        shape.line.color.rgb = line
        shape.line.width = Pt(0.75)
        shape.adjustments[0] = radius
        return shape

    def bar(self, slide, x, y, w, h, color):
        shape = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
        self.strip_style(shape)
        shape.fill.solid()
        shape.fill.fore_color.rgb = color
        shape.line.fill.background()
        return shape

    def rule(self, slide, x, y, w, color=RULE, height=0.012):
        self.bar(slide, x, y, w, height, color)

    def section_label(self, slide, x, y, text, color=ACCENT):
        self.bar(slide, x, y + 0.085, 0.15, 0.026, color)
        width = SW - (x + 0.24) - 0.20
        self.text(slide, x + 0.24, y, width,
                  [{"text": text, "size": 10, "bold": True, "color": color, "track": 110}],
                  tag=f"label:{text[:10]}")

    def section(self, slide, x, y, text, color=ACCENT):
        """Draw a section label and return the y for the body text under it."""
        self.section_label(slide, x, y, text, color)
        return y + 0.29

    # ------------------------------------------------------------ components
    def status_panel(self, slide, x, y, w):
        inner = w - 0.52
        row_h = 0.72
        height = 0.14 + row_h * len(STATUS) + 0.10
        self.panel(slide, x, y, w, height)
        cursor = y + 0.15
        for index, (label, value) in enumerate(STATUS):
            specs = [{"text": label, "size": 9, "bold": True, "color": MUTED, "track": 80,
                      "after": 2},
                     {"text": value, "size": 11.5, "color": BODY, "line": 1.04}]
            self.text(slide, x + 0.26, cursor, inner, specs, tag=f"status{index}")
            if index < len(STATUS) - 1:
                self.rule(slide, x + 0.26, cursor + row_h - 0.07, inner, HAIR)
            cursor += row_h
        return height

    def metric_cards(self, slide, y, h=1.26):
        gap = 0.135
        width = (CONTENT_W - 2 * gap) / 3
        accents = (NAVY, GREEN, AMBER)
        for index, (label, value, caption) in enumerate(CARDS):
            x = MARGIN + index * (width + gap)
            self.panel(slide, x, y, width, h, fill=WHITE)
            self.bar(slide, x + 0.16, y, width - 0.32, 0.045, accents[index])
            self.text(slide, x + 0.18, y + 0.15, width - 0.36,
                      [{"text": label, "size": 9, "bold": True, "color": MUTED, "track": 80,
                        "after": 2},
                       {"text": value, "size": 23, "bold": True, "color": NAVY, "line": 0.95,
                        "after": 3},
                       {"text": caption, "size": 9.5, "color": BODY, "line": 1.03}],
                      tag=f"card{index}")

    def lesson_card(self, slide, x, y, w, number, heading, body, action):
        inner = w - 0.92
        specs = [{"text": heading, "size": 14.5, "bold": True, "color": NAVY, "line": 1.02,
                  "after": 5},
                 {"text": body, "size": 12, "color": BODY, "line": 1.08, "after": 0},
                 {"text": action, "size": 11.5, "color": GREEN, "line": 1.08, "before": 7}]
        height = specs_height(specs, inner) + 0.38
        self.panel(slide, x, y, w, height, fill=CARD, line=RULE)
        self.bar(slide, x, y + 0.10, 0.055, height - 0.20, GREEN)
        circle = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(x + 0.22), Inches(y + 0.20),
                                        Inches(0.30), Inches(0.30))
        self.strip_style(circle)
        circle.fill.solid()
        circle.fill.fore_color.rgb = GREEN
        circle.line.fill.background()
        frame = circle.text_frame
        frame.margin_left = 0
        frame.margin_right = 0
        frame.margin_top = 0
        frame.margin_bottom = 0
        frame.vertical_anchor = MSO_ANCHOR.MIDDLE
        para = frame.paragraphs[0]
        para.alignment = PP_ALIGN.CENTER
        run = para.add_run()
        run.text = str(number)
        run.font.size = Pt(13)
        run.font.bold = True
        run.font.color.rgb = WHITE
        run.font.name = FONT
        self.text(slide, x + 0.68, y + 0.19, inner, specs, tag=f"lesson{number}")
        return height

    def footer(self, slide, page, total):
        self.rule(slide, MARGIN, FOOTER_RULE_Y, CONTENT_W)
        self.text(slide, MARGIN, FOOTER_RULE_Y + 0.07, 4.9,
                  [{"text": "ENGR90037 Capstone  ·  Assignment 2 Part 2  ·  Ash",
                    "size": 9, "color": MUTED}], tag=f"foot-left-{page}")
        self.text(slide, 4.1, FOOTER_RULE_Y + 0.07, 5.1,
                  [{"text": "Drafted with AI assistance; figures checked and text reviewed by the author",
                    "size": 9, "color": MUTED, "italic": True}], align=PP_ALIGN.CENTER,
                  tag=f"foot-ai-{page}")
        self.text(slide, SW - MARGIN - 0.9, FOOTER_RULE_Y + 0.07, 0.9,
                  [{"text": f"{page} / {total}", "size": 9, "color": MUTED}],
                  align=PP_ALIGN.RIGHT, tag=f"foot-page-{page}")

    def header(self, slide, title, subtitle, tag):
        self.text(slide, MARGIN, 0.33, CONTENT_W,
                  [{"text": "PROJECT RETROSPECTIVE  ·  PART 2 BRIEFING", "size": 9.5, "bold": True,
                    "color": ACCENT, "track": 150}], tag=f"{tag}.kicker")
        self.text(slide, MARGIN, 0.56, CONTENT_W,
                  [{"text": title, "size": 29, "bold": True, "color": NAVY, "line": 1.0}],
                  tag=f"{tag}.title")
        self.text(slide, MARGIN, 1.09, CONTENT_W,
                  [{"text": subtitle, "size": 12.5, "color": MUTED, "line": 1.05}],
                  tag=f"{tag}.sub")
        self.rule(slide, MARGIN, 1.40, CONTENT_W)

    def save(self):
        self.prs.save(OUT_PPTX)


def build():
    deck = Deck()
    LX, LW = MARGIN, 6.05
    RX, RW = 7.02, 5.70

    # ============================================================ slide 1
    s1 = deck.slide()
    deck.header(s1, TITLE_1, SUB_1, "s1")

    y = deck.section(s1, LX, 1.56, INTRO[0][0])
    for index, (label, paragraph) in enumerate(INTRO):
        if index:
            y += 0.26
            deck.section_label(s1, LX, y, label, ACCENT)
            y += 0.27
        y += deck.text(s1, LX, y, LW,
                       [{"text": paragraph, "size": 12.5, "color": BODY, "line": 1.05}],
                       tag=f"intro{index}")

    deck.section_label(s1, RX, 1.56, "WHERE WE STAND", GREEN)
    deck.status_panel(s1, RX, 1.85, RW)
    deck.metric_cards(s1, 5.16)

    # ============================================================ slide 2
    s2 = deck.slide()
    deck.header(s2, TITLE_2, SUB_2, "s2")

    y = deck.section(s2, LX, 1.56, "THE SURPRISE", AMBER)
    y = 1.85
    y += deck.text(s2, LX, y, LW, [{"text": SURPRISE, "size": 12.5, "color": BODY, "line": 1.05}],
                   tag="surprise")
    y += 0.26

    deck.section_label(s2, LX, y, "THE HARDEST PART", AMBER)
    y += 0.27
    y += deck.text(s2, LX, y, LW, [{"text": HARDEST, "size": 12.5, "color": BODY, "line": 1.05}],
                   tag="hardest")
    y += 0.26

    deck.section_label(s2, LX, y, "HOW WE WORK NOW", GREEN)
    y += 0.27
    deck.text(s2, LX, y, LW, [{"text": NOW, "size": 12.5, "color": BODY, "line": 1.05}], tag="now")

    deck.section_label(s2, RX, 1.56, "TWO LESSONS, EACH WITH AN ACTION", GREEN)
    h1 = deck.lesson_card(s2, RX, 1.85, RW, 1, *LESSON_1)
    h2 = deck.lesson_card(s2, RX, 1.85 + h1 + 0.18, RW, 2, *LESSON_2)
    deck.text(s2, RX, 1.85 + h1 + 0.18 + h2 + 0.16, RW,
              [{"text": CLOSING, "size": 10.5, "bold": True, "color": GREEN}], tag="closing")

    s1.notes_slide.notes_text_frame.text = NOTES_1
    s2.notes_slide.notes_text_frame.text = NOTES_2

    deck.footer(s1, 1, 2)
    deck.footer(s2, 2, 2)
    deck.save()

    # ============================================================ QA report
    print("saved:", OUT_PPTX)
    print(f"slides: {len(deck.prs.slides)}")
    worst = 0.0
    for tag, x, y, w, h in deck.boxes:
        if tag.startswith("foot-"):
            continue
        bottom = y + h
        if bottom > CONTENT_BOTTOM:
            print(f"  OVERFLOW-RISK {tag}: bottom {bottom:.2f} > {CONTENT_BOTTOM}")
        worst = max(worst, bottom)
    print(f"lowest content bottom: {worst:.2f} in (footer rule at {FOOTER_RULE_Y})")
    return 0


if __name__ == "__main__":
    sys.exit(build())
