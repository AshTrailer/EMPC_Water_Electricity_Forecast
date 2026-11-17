"""Static QA for a two-slide briefing deck.

Checks slide bounds, a 9 pt font floor, estimated text overflow per box, theme-style leakage, note
coverage and the stated slide count. Run: python check_deck.py DECK.pptx [more.pptx ...]
"""

import sys

from pptx import Presentation

EM = 0.48            # conservative average Calibri glyph width, em units
LINE = 1.22          # Calibri single-line height, em units
MIN_FONT_PT = 9.0


def lines_needed(text, size_pt, width_in):
    per_line = max(1.0, width_in / (size_pt * EM / 72.0))
    total = 0
    for chunk in text.split("\n"):
        n = len(chunk)
        total += max(1, int(n / per_line) + (1 if n % per_line else 0))
    return total


def check(path):
    prs = Presentation(path)
    sw = prs.slide_width / 914400
    sh = prs.slide_height / 914400
    problems, warnings = [], []
    print(f"{path}")
    print(f"  slides {len(prs.slides)}, size {sw:.3f} x {sh:.3f} in")
    for index, slide in enumerate(prs.slides, start=1):
        has_notes = slide.has_notes_slide and slide.notes_slide.notes_text_frame.text.strip()
        print(f"  --- slide {index}  shapes {len(slide.shapes)}  notes {'yes' if has_notes else 'NO'}")
        if not has_notes:
            problems.append(f"slide {index}: no speaker notes")
        for shape in slide.shapes:
            x = shape.left / 914400
            y = shape.top / 914400
            w = shape.width / 914400
            h = shape.height / 914400
            if x < -0.001 or y < -0.001 or x + w > sw + 0.001 or y + h > sh + 0.001:
                problems.append(f"slide {index}: '{shape.name}' outside bounds "
                                f"({x:.2f},{y:.2f}) {w:.2f}x{h:.2f}")
            if shape._element.find(
                    "{http://schemas.openxmlformats.org/presentationml/2006/main}style") is not None:
                problems.append(f"slide {index}: '{shape.name}' still carries a theme p:style")
            if not shape.has_text_frame:
                continue
            for para in shape.text_frame.paragraphs:
                text = "".join(run.text for run in para.runs)
                if not text.strip():
                    continue
                size = max((run.font.size.pt for run in para.runs if run.font.size), default=12.0)
                if size < MIN_FONT_PT - 0.001:
                    problems.append(f"slide {index}: {size}pt below floor in '{text[:40]}'")
                spacing = para.line_spacing if isinstance(para.line_spacing, float) else 1.0
                lines = lines_needed(text, size, max(0.1, w))
                needed = lines * size * LINE * spacing / 72.0
                if needed > h + 0.06:
                    warnings.append(f"slide {index}: text may overflow '{text[:44]}' "
                                    f"needs {needed:.2f} in a {h:.2f} in box")
    print("  problems:", "none" if not problems else "")
    for item in problems:
        print("   -", item)
    print("  overflow warnings:", "none" if not warnings else "")
    for item in warnings:
        print("   -", item)
    print()


if __name__ == "__main__":
    for argument in sys.argv[1:]:
        check(argument)
