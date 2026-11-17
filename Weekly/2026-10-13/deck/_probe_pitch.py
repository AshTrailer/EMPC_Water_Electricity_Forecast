# -*- coding: utf-8 -*-
"""Measure the rendered line pitch of body text and the symbol table.

The first build of the predictor pages lost its symbol table off the bottom of
the page because the layout assumed 0.185 in per row and the renderer charged
0.37 in. This writes one page per type size with a known number of rows, renders
it through the same path the previews use, and reports the pitch actually
measured between consecutive ink runs.

The renderer draws at a fixed 175 px per inch and rasterises a fixed 1334 px
canvas, so one inch of the ORIGINAL slide is 1334 / 13.3333 px. Only the top-left
57 percent of a page is ever in frame, so each case keeps its rows in the top
2.5 inches.
"""

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

from pptx import Presentation                                        # noqa: E402
from pptx.util import Inches, Pt                                     # noqa: E402

import deck_kit as K                                                 # noqa: E402

NODE = r"C:\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe"
CLI = (r"C:\DeepSeek Harness\resources\app.asar.unpacked\dsh\node_modules"
       r"\@deepseek-ai\libreoffice-kit\lib\cli.js")
TMP = os.path.join(HERE, "_preview_tmp")
PPI = 1334.0 / 13.3333
NROWS = 6


def build(cases):
    """One page per case. A case is (size, spacing or None, space_after pt)."""
    prs = Presentation()
    prs.slide_width = Inches(13.3333)
    prs.slide_height = Inches(7.5)
    for size, spacing, after in cases:
        s = K.blank(prs)
        _, tf = K.textbox(s, 0.55, 0.55, 7.60, 2.6)
        for i in range(NROWS):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            if spacing is not None:
                p.line_spacing = spacing
            p.space_before = Pt(0)
            p.space_after = Pt(after)
            r = p.add_run()
            r.text = "row %02d  the price of interval k, clamped to the target day" % i
            K.style_run(r, size, K.INK)
    path = os.path.join(TMP, "pitch.pptx")
    prs.save(path)
    return path


def render(path, tag, dpi=175):
    outdir = os.path.join(TMP, "pitch_%s" % tag)
    log = os.path.join(TMP, "pitch_%s.json" % tag)
    cmd = [NODE, CLI, "render", "--input", path, "--output-dir", outdir,
           "--dpi", str(dpi)]
    with open(log, "w", encoding="utf-8") as fh:
        subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT, check=False)
    with open(log, encoding="utf-8") as fh:
        return json.load(fh)["images"]


def runs_of(png, x0=60, x1=760, ytop=20):
    from PIL import Image
    with Image.open(png) as img:
        g = img.convert("L")
        w, h = g.size
        px = g.load()
        out = []
        cur = None
        for y in range(ytop, h - 2):
            n = sum(1 for x in range(x0, min(x1, w - 2)) if px[x, y] < 120)
            if n and cur is None:
                cur = y
            elif not n and cur is not None:
                out.append((cur, y - 1))
                cur = None
        if cur is not None:
            out.append((cur, h - 3))
        return out


if __name__ == "__main__":
    os.makedirs(TMP, exist_ok=True)
    cases = [
        (11, 1.0, 2.0),
        (11, None, 2.0),
        (11, 0.9, 2.0),
        (11, 1.0, 0.0),
        (10, 1.0, 2.0),
        (9, 1.0, 2.0),
    ]
    path = build(cases)
    ims = render(path, "s")
    for (size, spacing, after), im in zip(cases, ims):
        rr = runs_of(im["path"])
        tops = [a for a, b in rr]
        d = [(tops[i + 1] - tops[i]) / PPI for i in range(len(tops) - 1)]
        med = sorted(d)[len(d) // 2] if d else -1
        first = tops[0] / PPI if tops else -1
        print("%2d pt  spacing %-5s after %3.1f pt  rows %2d  pitch %.4f in  "
              "first ink top %.3f in" % (size, spacing, after, len(rr), med, first))
