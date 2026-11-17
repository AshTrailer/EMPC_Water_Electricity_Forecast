"""Dump the structure and visual style of the two reference decks."""

import sys
from collections import Counter
from pptx import Presentation
from pptx.util import Emu


def dump(path, max_slides=100):
    print("=" * 100)
    print(path)
    prs = Presentation(path)
    print(f"slide size {prs.slide_width} x {prs.slide_height} EMU "
          f"({prs.slide_width/914400:.2f} x {prs.slide_height/914400:.2f} in)")
    print(f"slides {len(prs.slides)}   layouts {len(prs.slide_layouts)}   masters {len(prs.slide_masters)}")

    fonts = Counter()
    sizes = Counter()
    colors = Counter()
    for m in prs.slide_masters:
        try:
            for ph in m.placeholders:
                pass
        except Exception:
            pass

    for i, s in enumerate(prs.slides, 1):
        if i > max_slides:
            print("  ...")
            break
        print(f"\n--- slide {i}  layout={s.slide_layout.name}")
        for sh in s.shapes:
            kind = sh.shape_type
            name = sh.name
            txt = ""
            if sh.has_text_frame:
                txt = " | ".join(p.text.strip() for p in sh.text_frame.paragraphs if p.text.strip())
            if sh.has_text_frame:
                for p in sh.text_frame.paragraphs:
                    for r in p.runs:
                        if r.font.name:
                            fonts[r.font.name] += 1
                        if r.font.size:
                            sizes[r.font.size.pt] += 1
                        try:
                            if r.font.color and r.font.color.type is not None and r.font.color.rgb:
                                colors[str(r.font.color.rgb)] += 1
                        except Exception:
                            pass
            flag = ""
            if sh.has_table:
                flag = f" TABLE {len(sh.table.rows)}x{len(sh.table.columns)}"
            if sh.shape_type is not None and "PICTURE" in str(sh.shape_type):
                flag = " PICTURE"
            if sh.shape_type is not None and "CHART" in str(sh.shape_type):
                flag = " CHART"
            print(f"    [{name}]{flag} {txt[:150]}")

    print("\nfont usage:", fonts.most_common(12))
    print("size usage:", sizes.most_common(14))
    print("run colours:", colors.most_common(12))
    # theme colours
    try:
        theme = prs.slide_masters[0].part.part_related_by(
            "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme")
        import re
        xml = theme.blob.decode("utf-8", "ignore")
        cs = re.search(r"<a:clrScheme.*?</a:clrScheme>", xml, re.S)
        if cs:
            for m in re.finditer(r'<a:(\w+)>\s*<a:(srgbClr val="([0-9A-Fa-f]{6})"|sysClr[^/]*lastClr="([0-9A-Fa-f]{6})")', cs.group(0)):
                print("  theme colour", m.group(1), m.group(3) or m.group(4))
        fs = re.search(r"<a:fontScheme.*?</a:fontScheme>", xml, re.S)
        if fs:
            for m in re.finditer(r'<a:(majorFont|minorFont)>\s*<a:latin typeface="([^"]*)"', fs.group(0)):
                print("  theme font", m.group(1), m.group(2))
    except Exception as e:
        print("  theme read failed:", e)


for p in sys.argv[1:]:
    dump(p)
