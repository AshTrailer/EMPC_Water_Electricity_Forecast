"""Static geometry QA for the two-slide deck: overflow risk, font floor, slide bounds, hinting."""

from pptx import Presentation
from pptx.util import Emu

PPTX = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Assignment_2_PM\Assignment2_PM_Slides_DRAFT_v1.pptx"

SLIDE_W_IN = 13.333
SLIDE_H_IN = 7.5
MIN_FONT_PT = 9.0
# Calibri average glyph width as a fraction of point size, measured from the rendered deck family.
CHAR_W_FACTOR = 0.48
LINE_H_FACTOR = 1.22


def inches(value):
    return Emu(value).inches


def main():
    prs = Presentation(PPTX)
    sw = inches(prs.slide_width)
    sh = inches(prs.slide_height)
    print(f"slide size: {sw:.3f} x {sh:.3f} in  ({len(prs.slides)} slides)")
    problems = []
    warnings = []

    for index, slide in enumerate(prs.slides, start=1):
        print(f"\n--- slide {index} ---")
        for shape in slide.shapes:
            x, y = inches(shape.left), inches(shape.top)
            w, h = inches(shape.width), inches(shape.height)
            if x < 0 or y < 0 or x + w > sw + 0.001 or y + h > sh + 0.001:
                problems.append(f"slide {index}: shape outside slide bounds at ({x:.2f},{y:.2f}) {w:.2f}x{h:.2f}")
            if not shape.has_text_frame:
                continue
            total_needed = 0.0
            text_preview = []
            for para in shape.text_frame.paragraphs:
                text = "".join(run.text for run in para.runs)
                if not text.strip():
                    continue
                size = max((run.font.size.pt for run in para.runs if run.font.size), default=18.0)
                if size < MIN_FONT_PT - 0.001:
                    problems.append(f"slide {index}: font {size}pt below floor in '{text[:40]}'")
                line_spacing = para.line_spacing if isinstance(para.line_spacing, float) else 1.0
                chars_per_line = max(1.0, w / (size * CHAR_W_FACTOR / 72.0))
                lines = 0
                for chunk in text.split("\n"):
                    lines += max(1, int(len(chunk) / chars_per_line) + (1 if len(chunk) % chars_per_line else 0))
                total_needed += lines * (size * LINE_H_FACTOR * line_spacing) / 72.0
                text_preview.append(text[:52])
            headroom = h - total_needed
            flag = "OK " if headroom >= -0.02 else "TIGHT"
            if headroom < -0.02:
                warnings.append(
                    f"slide {index}: text needs {total_needed:.2f}in in a {h:.2f}in box at ({x:.2f},{y:.2f}) -> '{text_preview[0] if text_preview else ''}'"
                )
            print(f"  [{flag}] box ({x:5.2f},{y:5.2f}) {w:5.2f}x{h:4.2f}  need~{total_needed:4.2f}  headroom {headroom:+5.2f}")

    print("\n=== problems ===")
    print("\n".join(problems) if problems else "none")
    print("=== tight boxes (estimate may over-predict) ===")
    print("\n".join(warnings) if warnings else "none")


if __name__ == "__main__":
    main()
