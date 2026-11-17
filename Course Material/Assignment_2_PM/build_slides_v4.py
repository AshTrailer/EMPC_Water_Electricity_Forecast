"""Build Assignment2_PM_Slides_v4.pptx: two-slide sponsor briefing.

Audience: sponsor with no domain background. One idea per band, plain words,
every acronym glossed. 16:9, 13.333 x 7.5 in.
"""

import os
import re
import sys

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

# ---------------------------------------------------------------- palette

INK = "12253F"
BODY = "25364B"
MUTED = "52657A"
BORDER = "D9E2EC"
CANVAS = "F6F8FB"
WHITE = "FFFFFF"
GREEN = "217A52"
TEAL = "137C78"
AMBER = "B96518"
BLUE = "316CCB"
RED = "B3483D"
TINT_GREEN = "E7F4EC"
TINT_TEAL = "E6F4F2"
TINT_AMBER = "FFF1DF"
TINT_BLUE = "EAF1FF"
TINT_RED = "FCECE9"
TINT_GREY = "EEF3F8"
DARK = "12253F"
ON_DARK = "FFFFFF"
ON_DARK_SOFT = "B9C7D6"
ON_DARK_ACCENT = "76D6CA"

HEAD_FONT = "Aptos Display"
TEXT_FONT = "Aptos"

LEFT = PP_ALIGN.LEFT
CENTRE = PP_ALIGN.CENTER
RIGHT = PP_ALIGN.RIGHT

# ---------------------------------------------------------------- helpers


def rgb(value):
    return RGBColor.from_string(value)


def plain(shape):
    """Drop the theme style and any inherited effect so no renderer adds a shadow."""
    style = shape._element.find(qn("p:style"))
    if style is not None:
        shape._element.remove(style)
    shape.shadow.inherit = False


def box(slide, x, y, w, h, fill=None, line=None, width=0.8, radius_in=None):
    kind = MSO_SHAPE.ROUNDED_RECTANGLE if radius_in else MSO_SHAPE.RECTANGLE
    shape = slide.shapes.add_shape(kind, Inches(x), Inches(y), Inches(w), Inches(h))
    if radius_in:
        shape.adjustments[0] = radius_in / min(w, h)
    if fill:
        shape.fill.solid()
        shape.fill.fore_color.rgb = rgb(fill)
    else:
        shape.fill.background()
    if line:
        shape.line.color.rgb = rgb(line)
        shape.line.width = Pt(width)
    else:
        shape.line.fill.background()
    plain(shape)
    shape.text_frame.word_wrap = True
    return shape


def oval(slide, cx, cy, d, fill, line, width=1.4):
    shape = slide.shapes.add_shape(
        MSO_SHAPE.OVAL, Inches(cx - d / 2), Inches(cy - d / 2), Inches(d), Inches(d))
    shape.fill.solid()
    shape.fill.fore_color.rgb = rgb(fill)
    shape.line.color.rgb = rgb(line)
    shape.line.width = Pt(width)
    plain(shape)
    return shape


def pill(slide, x, y, w, h, text, *, fill, colour, size=7.8, spc=60):
    shape = box(slide, x, y, w, h, fill=fill, radius_in=h / 2)
    tf = shape.text_frame
    tf.word_wrap = False
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.alignment = CENTRE
    p.line_spacing = 1.0
    run = p.add_run()
    run.text = text
    style(run, size=size, bold=True, colour=colour, spc=spc)
    return shape


def pill_width(label, size=7.8):
    """Width that keeps a tracked caps label on one line."""
    return max(0.72, 0.34 + len(label) * size * 0.0105 + len(label) * 0.006)


def style(run, *, size, bold=False, colour=INK, font=TEXT_FONT, spc=None, italic=False):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.name = font
    run.font.color.rgb = rgb(colour)
    if spc is not None:
        run.font._rPr.set("spc", str(int(spc)))


def text(slide, x, y, w, h, paras, *, anchor=MSO_ANCHOR.TOP, wrap=True):
    """paras: list of dicts with runs=[(txt, style_kwargs)], align, line, before, after."""
    shape = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = shape.text_frame
    tf.word_wrap = wrap
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    for i, spec in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = spec.get("align", LEFT)
        p.line_spacing = spec.get("line", 1.12)
        p.space_before = Pt(spec.get("before", 0))
        p.space_after = Pt(spec.get("after", 0))
        for txt, kw in spec["runs"]:
            run = p.add_run()
            run.text = txt
            style(run, **kw)
    return shape


def line(slide, x, y, w, colour=BORDER, width=0.9):
    shape = slide.shapes.add_connector(
        MSO_CONNECTOR.STRAIGHT, Inches(x), Inches(y), Inches(x + w), Inches(y))
    shape.line.color.rgb = rgb(colour)
    shape.line.width = Pt(width)
    plain(shape)
    return shape


def vline(slide, x, y, h, colour=BORDER, width=1.1):
    shape = slide.shapes.add_connector(
        MSO_CONNECTOR.STRAIGHT, Inches(x), Inches(y), Inches(x), Inches(y + h))
    shape.line.color.rgb = rgb(colour)
    shape.line.width = Pt(width)
    plain(shape)
    return shape


def canvas(slide):
    slide.background.fill.solid()
    slide.background.fill.fore_color.rgb = rgb(CANVAS)


def header(slide, title, subtitle, page):
    canvas(slide)
    text(slide, 0.62, 0.245, 7.0, 0.20, [
        {"runs": [("PROJECT RETROSPECTIVE  /  PART 2 BRIEFING",
                   dict(size=9.2, bold=True, colour=TEAL, spc=130))]},
    ])
    pill(slide, 10.38, 0.19, 2.37, 0.35, "STATUS AT 16 OCT 2026",
         fill=WHITE, colour=MUTED, size=7.9, spc=90)
    text(slide, 0.58, 0.455, 12.1, 0.56, [
        {"runs": [(title, dict(size=27, bold=True, colour=INK, font=HEAD_FONT))]},
    ])
    text(slide, 0.60, 1.035, 12.0, 0.28, [
        {"runs": [(subtitle, dict(size=13, colour=BODY))]},
    ])
    line(slide, 0.58, 1.435, 12.17)
    footer(slide, page)


def footer(slide, page):
    line(slide, 0.58, 6.865, 12.17)
    text(slide, 0.58, 7.02, 3.4, 0.18, [
        {"runs": [("ENGR90037 Capstone  ·  Assignment 2 Part 2  ·  Ash",
                   dict(size=7.8, colour=MUTED))]},
    ])
    text(slide, 3.70, 7.02, 7.4, 0.18, [
        {"runs": [("AI assistance: drafting, editing and slide layout. All figures and judgements checked by the author.",
                   dict(size=7.8, colour=MUTED))], "align": CENTRE},
    ])
    text(slide, 11.70, 7.02, 1.05, 0.18, [
        {"runs": [(f"{page} / 2", dict(size=7.8, colour=MUTED))], "align": RIGHT},
    ])


def section_label(slide, x, y, w, label, colour=TEAL, size=9.2, align=LEFT):
    text(slide, x, y, w, 0.20, [
        {"runs": [(label, dict(size=size, bold=True, colour=colour, spc=120))],
         "align": align},
    ])


def card(slide, x, y, w, h, *, fill=WHITE, border=BORDER, radius_in=0.10):
    return box(slide, x, y, w, h, fill=fill, line=border, radius_in=radius_in)


def badge(slide, x, y, d, number, *, fill, colour):
    shape = box(slide, x, y, d, d, fill=fill, radius_in=d / 2)
    tf = shape.text_frame
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.alignment = CENTRE
    p.line_spacing = 1.0
    run = p.add_run()
    run.text = str(number)
    style(run, size=10.6, bold=True, colour=colour)


def stacked(slide, x, y, w, h, blocks, *, body_size=12.4, line_spacing=1.24, gap=19):
    """Flowing label/body blocks inside one frame, so text can never overlap."""
    paras = []
    for i, (label, body) in enumerate(blocks):
        paras.append({
            "runs": [(label, dict(size=8.4, bold=True, colour=MUTED, spc=100))],
            "before": 0 if i == 0 else gap, "after": 3,
        })
        paras.append({
            "runs": [(body, dict(size=body_size, colour=BODY))],
            "line": line_spacing, "after": 0,
        })
    return text(slide, x, y, w, h, paras)


# ---------------------------------------------------------------- slide 1

S1_TITLE = "What we are building, and where it stands"
S1_SUB = "Four milestones due by 16 October, all met. The work inside them ran late."

S1_BLOCKS = [
    ("THE PROBLEM",
     "Power prices move every five minutes. A water utility can pump when power is "
     "cheap, but only if it can see the hours ahead and still keep its tank safe."),
    ("WHAT WE DELIVER",
     "A price forecast, and a controller that decides when pumps run."),
    ("HOW WE JUDGE IT",
     "Forecast error against the prices that actually happened. Pumping cost against "
     "the market operator's own forecast."),
]

S1_NODES = [
    ("AUG – SEP", "Three milestones met",
     "Baseline pump control, a price forecast, and a controller.", "done"),
    ("24 SEP", "Forecast and controller joined",
     "The fourth milestone. Our forecast drives the pump plan.", "done"),
    ("13 NOV", "Mid-semester review", "Where we defend the result to you.", "next"),
    ("JUN 2027", "Final report", "Second-half testing, then the write-up.", "planned"),
]


def slide_one(prs):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    header(slide, S1_TITLE, S1_SUB, 1)

    # ---- left card: what the project is
    card(slide, 0.58, 1.56, 6.02, 3.45)
    section_label(slide, 0.82, 1.74, 5.4, "WHAT WE ARE BUILDING")
    stacked(slide, 0.82, 2.06, 5.54, 2.85, S1_BLOCKS,
            body_size=12.6, line_spacing=1.22, gap=26)

    # ---- right card: milestones
    card(slide, 6.73, 1.56, 6.02, 3.45)
    section_label(slide, 6.97, 1.74, 3.4, "WHERE WE STAND")
    section_label(slide, 9.10, 1.74, 3.41, "4 OF 4 MET", colour=GREEN, align=RIGHT)

    spine_x = 7.90
    top, step = 2.12, 0.76
    vline(slide, spine_x, top + 0.05, step * 3)

    for i, (date, title, body, state) in enumerate(S1_NODES):
        cy = top + step * i
        text(slide, 6.97, cy - 0.015, 0.76, 0.16, [
            {"runs": [(date, dict(size=8.2, bold=True,
                                  colour=GREEN if state == "done" else MUTED, spc=30))],
             "align": RIGHT},
        ])
        fill = GREEN if state == "done" else WHITE
        edge = GREEN if state == "done" else (TEAL if state == "next" else BORDER)
        oval(slide, spine_x, cy + 0.07, 0.15, fill, edge)
        text(slide, 8.08, cy, 3.30, 0.22, [
            {"runs": [(title, dict(size=11.8, bold=True, colour=INK))]},
        ])
        text(slide, 8.08, cy + 0.235, 4.42, 0.36, [
            {"runs": [(body, dict(size=9.3, colour=MUTED))], "line": 1.16},
        ])
        if state == "next":
            pill(slide, 11.42, cy - 0.025, 0.72, 0.20, "NEXT",
                 fill=TINT_TEAL, colour=TEAL, size=7.9)

    # ---- first result band
    box(slide, 0.58, 5.20, 12.17, 0.88, fill=DARK)
    text(slide, 0.82, 5.33, 1.7, 0.18, [
        {"runs": [("FIRST RESULT", dict(size=8.6, bold=True,
                                        colour=ON_DARK_ACCENT, spc=120))]},
    ])
    text(slide, 0.82, 5.55, 11.7, 0.26, [
        {"runs": [
            ("6%", dict(size=14.5, bold=True, colour=ON_DARK)),
            (" cheaper than the market operator's forecast, and ", dict(size=13, colour=ON_DARK)),
            ("6%", dict(size=14.5, bold=True, colour=ON_DARK)),
            (" dearer than a plan that already knows tomorrow's prices.",
             dict(size=13, colour=ON_DARK)),
        ]},
    ])
    text(slide, 0.82, 5.85, 11.6, 0.18, [
        {"runs": [("60 days to 15 October. Daily rankings move around, so this is early "
                   "evidence, not a proven saving.",
                   dict(size=9.0, colour=ON_DARK_SOFT))]},
    ])

    # ---- plain terms
    text(slide, 0.60, 6.26, 12.15, 0.36, [
        {"runs": [
            ("IN PLAIN TERMS   ", dict(size=8.2, bold=True, colour=MUTED, spc=100)),
            ("AEMO is the Australian Energy Market Operator. It runs the wholesale "
             "electricity market and publishes its own price forecast, which is the "
             "benchmark for our pumping cost.",
             dict(size=8.5, colour=MUTED)),
        ], "line": 1.22},
    ])
    return slide


# ---------------------------------------------------------------- slide 2

S2_TITLE = "Why the work ran late, and what we changed"
S2_SUB = "Three things took longer than planned. Each one is now covered by a change."

S2_CAUSES = [
    ("ABOUT 1 MONTH", AMBER, TINT_AMBER,
     "The market data took longer to line up",
     "AEMO publishes three forecast products that update at different speeds and look "
     "different distances ahead. Joining them into one series took a month longer than "
     "planned."),
    ("ABOUT 5 WEEKS", AMBER, TINT_AMBER,
     "The forecast needed far more testing",
     "Accuracy moved with how far ahead we looked and with the time of day, so one test "
     "was not enough. The controller then waited on that output and fell four weeks behind."),
    ("1 WEEK", RED, TINT_RED,
     "A fault in our own data code",
     "Our code stamped some prices with the wrong time, and a parsing bug dropped most "
     "records. Our checks watched for stalled tasks, not bad data."),
]

S2_CHANGES = [
    ("1", TEAL, TINT_TEAL,
     "A data gate before any result",
     "Every record is checked for the right time and for missing values, across sources, "
     "before a result is reported."),
    ("2", TEAL, TINT_TEAL,
     "One owner at each handover",
     "Each of us tests one path that crosses into another person's part of the system."),
    ("3", TEAL, TINT_TEAL,
     "Decisions and blockers in writing",
     "Both are logged at each weekly review, against a schedule I rebuilt and now check "
     "weekly."),
]

S2_LEFT_WORDS = [
    ("Check our own data before blaming the feed.",
     "No result is reported until the data gate passes."),
    ("Fix the comparison before choosing a model.",
     "The window and the measure are agreed before any model is run."),
]


def slide_two(prs):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    header(slide, S2_TITLE, S2_SUB, 2)

    section_label(slide, 0.58, 1.50, 5.4, "WHAT SLOWED US DOWN", colour=AMBER)
    section_label(slide, 6.73, 1.50, 5.4, "WHAT WE CHANGED", colour=TEAL)

    top, height, gap = 1.72, 1.10, 0.08
    for i, (tag, ink, tint, title, body) in enumerate(S2_CAUSES):
        y = top + i * (height + gap)
        card(slide, 0.58, y, 6.02, height)
        badge(slide, 0.72, y + 0.15, 0.31, i + 1, fill=tint, colour=ink)
        text(slide, 1.16, y + 0.13, 3.86, 0.22, [
            {"runs": [(title, dict(size=12.4, bold=True, colour=INK))]},
        ])
        tag_w = pill_width(tag)
        pill(slide, 6.46 - tag_w, y + 0.155, tag_w, 0.22, tag, fill=tint, colour=ink, size=7.8)
        text(slide, 1.16, y + 0.44, 5.28, 0.54, [
            {"runs": [(body, dict(size=10.3, colour=BODY))], "line": 1.18},
        ])

    for i, (num, ink, tint, title, body) in enumerate(S2_CHANGES):
        y = top + i * (height + gap)
        card(slide, 6.73, y, 6.02, height)
        badge(slide, 6.87, y + 0.15, 0.31, num, fill=tint, colour=ink)
        text(slide, 7.31, y + 0.13, 5.2, 0.22, [
            {"runs": [(title, dict(size=12.4, bold=True, colour=INK))]},
        ])
        text(slide, 7.31, y + 0.44, 5.26, 0.50, [
            {"runs": [(body, dict(size=10.3, colour=BODY))], "line": 1.18},
        ])

    # ---- what is left
    box(slide, 0.58, 5.30, 12.17, 0.48, fill=TINT_GREY)
    box(slide, 0.58, 5.30, 0.07, 0.48, fill=TEAL)
    text(slide, 0.82, 5.30, 1.5, 0.48, [
        {"runs": [("WHAT IS LEFT", dict(size=8.6, bold=True, colour=TEAL, spc=110))]},
    ], anchor=MSO_ANCHOR.MIDDLE)
    text(slide, 2.16, 5.30, 10.4, 0.48, [
        {"runs": [("One task now sits on the critical path: prove the 6% saving holds day "
                   "by day before 13 November. Together the slips used up our slack.",
                   dict(size=10.6, colour=BODY))]},
    ], anchor=MSO_ANCHOR.MIDDLE)

    # ---- lessons
    card(slide, 0.58, 5.88, 12.17, 0.78)
    box(slide, 0.58, 5.88, 0.07, 0.78, fill=AMBER)
    text(slide, 0.82, 5.99, 1.5, 0.18, [
        {"runs": [("TWO LESSONS", dict(size=8.6, bold=True, colour=AMBER, spc=110))]},
    ])
    for i, (lesson, action) in enumerate(S2_LEFT_WORDS):
        text(slide, 2.16, 5.96 + i * 0.32, 10.4, 0.28, [
            {"runs": [
                (f"{i + 1}  ", dict(size=10.8, bold=True, colour=AMBER)),
                (lesson, dict(size=11.2, bold=True, colour=INK)),
                ("    Action: " + action, dict(size=10.3, colour=MUTED)),
            ]},
        ])
    return slide


# ---------------------------------------------------------------- notes

NOTES_1 = """Good morning. I am Ash, the project manager. Two slides: what we are building, where we are, what slowed us down, and what we changed.

The project is a cheaper way to pump water. A water utility keeps its tanks filled and supplies homes around the clock, and it pays the wholesale power price, which moves every five minutes. Pumping in the cheap intervals costs far less, but you cannot simply pump at three in the morning: the tank still has to stay inside its safe limits.

So we built two things: a price forecast, and a controller that turns that forecast into a pump plan. The forecast is judged on how close it gets to the prices that actually happened. The controller is judged on pumping cost, against running on the market operator's own forecast.

That operator is AEMO, the Australian Energy Market Operator. It runs the wholesale electricity market and publishes its own price forecast, which is our benchmark. The other benchmark on the slide, a plan that already knows tomorrow's prices, is the theoretical best case.

Where we are: four milestones were due by 16 October, and all four are met. Three of them were the pieces, built between August and September. The fourth was joining the forecast to the controller, live since 24 September. Ahead is the mid-semester review on 13 November, then the final report in June.

The first cost result is at the bottom. Over 60 days our plan cost about 6% less than running on AEMO's own forecast, and about 6% more than that theoretical best. Daily rankings move around, so this is early evidence, not a proven saving.

The milestones were met. The work inside them was not on time."""

NOTES_2 = """Three things ran late.

First, the market data. AEMO publishes three forecast products. They update at different speeds, look different distances ahead, and are not in the same format. Turning them into one series took about a month longer than we planned.

Second, testing. We assumed one horizon and one time of day would be enough. Accuracy moved with both, so testing ran about five weeks long, and the controller, which needed that output, fell four weeks behind.

Third, our own mistake, and the only red one on the slide. Our capture code stamped some prices with the wrong clock, and a parsing bug dropped most records. Our controls showed us stalled tasks; they did not look at the data itself. Repair and rebuild took a week.

Each now has a change behind it. Before any number leaves the team, a cross-source check confirms every price record has the right time and nothing is missing. The three of us each own one end-to-end test that crosses into someone else's part, so a handover cannot fail quietly. And decisions and blockers are written down every week, against a schedule I rebuilt and now check weekly.

One task now sits on the critical path. We have an early saving and we do not yet know whether it holds day to day. That has to be settled before 13 November, and the slips have used up our slack, so the second half has less room than the charter assumed.

Two lessons. First, check our own data before blaming the feed: the fault that cost a week was ours, so no result is reported until the data gate passes. Second, fix the comparison before choosing a model: the window and the measure are now agreed first.

Thank you. Happy to take questions."""


def main():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    slide_one(prs)
    slide_two(prs)
    for slide, note in zip(prs.slides, (NOTES_1, NOTES_2)):
        slide.notes_slide.notes_text_frame.text = note
    out = sys.argv[1] if len(sys.argv) > 1 else "Assignment2_PM_Slides_v4.pptx"
    prs.save(out)

    notes_path = os.path.join(os.path.dirname(os.path.abspath(out)),
                              "Assignment2_PM_Speaker_Notes_v4.txt")
    counts = [len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'%.,-]*", n)) for n in (NOTES_1, NOTES_2)]
    body = (
        "ENGR90037 Capstone - Assignment 2 Part 2\n"
        "Speaker notes for Assignment2_PM_Slides_v4.pptx\n"
        f"Length: {sum(counts)} words, about {sum(counts) / 140:.1f} minutes at 140 words per minute.\n\n"
        f"SLIDE 1 - What we are building, and where it stands  ({counts[0]} words, "
        f"about {counts[0] / 140:.1f} min)\n\n{NOTES_1}\n\n"
        f"SLIDE 2 - Why the work ran late, and what we changed  ({counts[1]} words, "
        f"about {counts[1] / 140:.1f} min)\n\n{NOTES_2}\n"
    )
    with open(notes_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(body)

    print("saved", out, "slides", len(prs.slides))
    print("saved", notes_path, f"{sum(counts)} words")


if __name__ == "__main__":
    main()
