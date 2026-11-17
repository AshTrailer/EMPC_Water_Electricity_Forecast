"""Verify the schedule sheet: every shape inside the slide, bars aligned to their dates."""

from pptx import Presentation
from pptx.util import Emu
from datetime import date

PPTX = r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Assignment_2_PM\Capstone_Schedule_v1_vs_v2.pptx"
SW, SH = 13.333, 7.5


def inch(v):
    return Emu(v).inches


prs = Presentation(PPTX)
slide = prs.slides[0]
print(f"slide {inch(prs.slide_width):.3f} x {inch(prs.slide_height):.3f}, shapes {len(slide.shapes)}")

outside = []
texts = []
for shape in slide.shapes:
    x, y = inch(shape.left), inch(shape.top)
    w, h = inch(shape.width), inch(shape.height)
    if x < -0.01 or y < -0.01 or x + w > SW + 0.01 or y + h > SH + 0.01:
        outside.append((shape.shape_type, round(x, 3), round(y, 3), round(w, 3), round(h, 3)))
    if shape.has_text_frame and shape.text_frame.text.strip():
        size = max((r.font.size.pt for p in shape.text_frame.paragraphs for r in p.runs if r.font.size),
                   default=None)
        texts.append((round(y, 3), shape.text_frame.text.replace("\n", " | ")[:70], size))

print(f"\nshapes outside the slide: {len(outside)}")
for item in outside:
    print("   ", item)

print(f"\ntext elements: {len(texts)}")
for y, text, size in sorted(texts):
    print(f"   y={y:5.2f}  {size}pt  {text}")

small = [(y, t, s) for y, t, s in texts if s is not None and s < 8]
print(f"\ntext below 8 pt: {len(small)}")

# the date geometry the drawing claims
START, END = date(2026, 8, 3), date(2026, 11, 16)
CHART_X, CHART_W = 3.95, 8.85
span = (END - START).days


def pos(d):
    return CHART_X + CHART_W * (d - START).days / span


checks = [
    ("8 Aug", date(2026, 8, 8)),
    ("1 Sep", date(2026, 9, 1)),
    ("16 Oct today", date(2026, 10, 16)),
    ("13 Nov", date(2026, 11, 13)),
]
print("\ncomputed x for reference dates (chart spans 3.95 to 12.80):")
for label, d in checks:
    print(f"   {label:14s} x = {pos(d):6.3f}")
