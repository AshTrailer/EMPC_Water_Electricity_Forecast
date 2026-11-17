# -*- coding: utf-8 -*-
"""Read-only dump of the three source decks: per-slide text with geometry, and
the picture inventory with alt text, so the carry-over can be diffed later.

Usage:
  python probe_decks.py --deck 4 --slides 6-11 --out dump.txt
  python probe_decks.py --alpha --out alpha.txt
"""

import argparse
import io
import os
import sys

from pptx import Presentation
from pptx.util import Emu

DECKS = {
    "1": r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Forecasting_Deck.pptx",
    "2": r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Capstone_Weekly_2026-09-23.pptx",
    "3": r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Course Material\Predicitor.pptx",
    "4": r"C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-08\deck\Capstone_Forecasting_v1.pptx",
}


def parse_range(spec, n):
    if not spec:
        return list(range(1, n + 1))
    out = []
    for part in spec.split(","):
        if "-" in part:
            a, b = part.split("-")
            out.extend(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return [i for i in out if 1 <= i <= n]


def walk(shapes, depth=0):
    for sh in shapes:
        yield sh, depth
        if sh.shape_type == 6:  # GROUP
            for sub, d in walk(sh.shapes, depth + 1):
                yield sub, d


def dump_slide(idx, slide, fh):
    fh.write("\n=== slide %d ===\n" % idx)
    for sh, depth in walk(slide.shapes):
        pad = "  " * depth
        kind = str(sh.shape_type)
        try:
            geom = "(%.2f,%.2f) %.2fx%.2f" % (
                sh.left / 914400, sh.top / 914400,
                sh.width / 914400, sh.height / 914400)
        except TypeError:
            geom = "(no geom)"
        if sh.shape_type == 13 or sh.__class__.__name__ == "Picture":
            fh.write("%s[%s] %s  name=%s  descr=%r\n" % (pad, kind, geom, sh.name, sh._element._nvXxPr.cNvPr.get("descr")))
            continue
        if sh.has_text_frame and sh.text_frame.text.strip():
            fh.write("%s[%s] %s\n" % (pad, kind, geom))
            for p in sh.text_frame.paragraphs:
                if not p.text.strip():
                    continue
                sizes = sorted({r.font.size.pt for r in p.runs if r.font.size})
                fonts = sorted({r.font.name for r in p.runs if r.font.name})
                cols = sorted({str(r.font.color.rgb) for r in p.runs
                               if r.font.color and r.font.color.type is not None
                               and str(r.font.color.type) == "MSO_THEME_COLOR.NOT_THEME_COLOR"})
                fh.write("%s   | %s\n" % (pad, p.text))
                fh.write("%s     size=%s font=%s colour=%s\n" %
                         (pad, sizes or "inherit", fonts or "inherit", cols or "inherit"))
        elif sh.has_table:
            fh.write("%s[TABLE] %s\n" % (pad, geom))
            for row in sh.table.rows:
                fh.write("%s   || %s\n" % (pad, " | ".join(c.text.replace("\n", " ") for c in row.cells)))


def dump_alpha(fh):
    from PIL import Image
    for k in ("4",):
        prs = Presentation(DECKS[k])
        fh.write("### deck %s formula images\n" % k)
        for i, slide in enumerate(prs.slides, 1):
            for sh, _ in walk(slide.shapes):
                if sh.__class__.__name__ != "Picture":
                    continue
                descr = sh._element._nvXxPr.cNvPr.get("descr")
                blob = sh.image.blob
                im = Image.open(io.BytesIO(blob)).convert("RGBA")
                alpha = im.getchannel("A")
                lo, hi = alpha.getextrema()
                fh.write("slide %-2d  %-22s px=%dx%d  bytes=%7d  aspect=%6.3f  alpha=[%d,%d]  corner=%s  "
                         "placed=%.2fx%.2f in at (%.2f,%.2f)\n" % (
                             i, descr, im.width, im.height, len(blob), im.width / im.height,
                             lo, hi, im.getpixel((0, 0)),
                             sh.width / 914400, sh.height / 914400,
                             sh.left / 914400, sh.top / 914400))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deck", required=True)
    ap.add_argument("--slides", default="")
    ap.add_argument("--alpha", action="store_true")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    with open(args.out, "w", encoding="utf-8") as fh:
        if args.alpha:
            dump_alpha(fh)
            return
        prs = Presentation(DECKS[args.deck])
        for idx in parse_range(args.slides, len(prs.slides._sldIdLst)):
            dump_slide(idx, prs.slides[idx - 1], fh)
    print("wrote", args.out, os.path.getsize(args.out), "bytes")


if __name__ == "__main__":
    main()
