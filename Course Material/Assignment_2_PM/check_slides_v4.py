"""Structural checks for Assignment2_PM_Slides_v4.pptx.

Exit code 0 only when every check passes.
"""

import sys

from pptx import Presentation

SLIDE_W = 13.333
SLIDE_H = 7.5

MUST = {
    0: ["What we are building, and where it stands",
        "Four milestones due by 16 October, all met",
        "Power prices move every five minutes",
        "A price forecast, and a controller that decides when pumps run",
        "Three milestones met",
        "Forecast and controller joined",
        "Mid-semester review",
        "Final report",
        "6%", "AEMO is the Australian Energy Market Operator"],
    1: ["Why the work ran late, and what we changed",
        "The market data took longer to line up",
        "The forecast needed far more testing",
        "A fault in our own data code",
        "A data gate before any result",
        "One owner at each handover",
        "Decisions and blockers in writing",
        "WHAT IS LEFT",
        "Check our own data before blaming the feed.",
        "Fix the comparison before choosing a model.",
        "13 November"],
}

MUST_NOT = ["EMPC", "perfect foresight", "irrelevant", "TODO", "XXX"]


def collect_text(slide):
    parts = []
    for shapes in slide.shapes:
        if shapes.has_text_frame:
            parts.append(shapes.text_frame.text)
    return "\n".join(parts)


def main(path):
    prs = Presentation(path)
    problems = []

    if len(prs.slides) != 2:
        problems.append(f"expected 2 slides, found {len(prs.slides)}")
    if abs(prs.slide_width / 914400 - SLIDE_W) > 0.01:
        problems.append(f"slide width {prs.slide_width / 914400:.3f} in")
    if abs(prs.slide_height / 914400 - SLIDE_H) > 0.01:
        problems.append(f"slide height {prs.slide_height / 914400:.3f} in")

    smallest = 99.0
    for i, slide in enumerate(prs.slides):
        body = collect_text(slide)
        for needle in MUST.get(i, []):
            if needle not in body:
                problems.append(f"slide {i + 1}: missing text {needle!r}")
        for needle in MUST_NOT:
            if needle in body:
                problems.append(f"slide {i + 1}: unwanted text {needle!r}")

        for shape in slide.shapes:
            left = shape.left / 914400
            top = shape.top / 914400
            right = left + shape.width / 914400
            bottom = top + shape.height / 914400
            if left < -0.01 or top < -0.01 or right > SLIDE_W + 0.01 or bottom > SLIDE_H + 0.01:
                problems.append(
                    f"slide {i + 1}: {shape.name} out of bounds "
                    f"({left:.2f},{top:.2f})-({right:.2f},{bottom:.2f})")
            if shape.has_text_frame:
                for para in shape.text_frame.paragraphs:
                    for run in para.runs:
                        if run.text.strip() and run.font.size:
                            smallest = min(smallest, run.font.size.pt)

        if not slide.has_notes_slide or not slide.notes_slide.notes_text_frame.text.strip():
            problems.append(f"slide {i + 1}: no speaker notes")

    if smallest < 7.8:
        problems.append(f"smallest font {smallest:.1f} pt is below 7.8 pt")

    print(f"slides: {len(prs.slides)}   smallest font: {smallest:.1f} pt")
    if problems:
        print("FAIL")
        for p in problems:
            print("  -", p)
        return 1
    print("PASS: text, bounds, font floor and notes all satisfy the checks")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
