# -*- coding: utf-8 -*-
"""Pin the renderer down: pixels per inch, per page size and per --dpi.

A single vertical bar is drawn at a known x, and one horizontal rule sits at a
known y. The bar's left edge in the PNG gives the pixels-per-inch the renderer
used for content; the canvas size gives the pixels-per-inch it used for the
page. Four combinations decide the preview workaround, and guessing it wrong
crops every preview.
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

BAR_X = 2.00          # bar left edge, inches
BAR_W = 0.50          # bar width, inches
BAR_Y = 2.00          # rule top edge, inches


def make(tag, page_w, page_h, scale):
    prs = Presentation()
    prs.slide_width = Inches(page_w)
    prs.slide_height = Inches(page_h)
    s = K.blank(prs)
    bar = K.add_rect(s, BAR_X * scale, 0.20 * scale, BAR_W * scale, 1.00 * scale,
                     fill=K.NAVY)
    bar.shadow.inherit = False
    rule = K.add_rect(s, 0.20 * scale, BAR_Y * scale, 1.00 * scale, 0.05 * scale,
                      fill=K.AMBER)
    rule.shadow.inherit = False
    path = os.path.join(TMP, "pin_%s.pptx" % tag)
    prs.save(path)
    return path


def run(tag, path, dpi):
    outdir = os.path.join(TMP, "pin_%s" % tag)
    log = os.path.join(TMP, "pin_%s.json" % tag)
    cmd = [NODE, CLI, "render", "--input", path, "--output-dir", outdir,
           "--dpi", str(dpi)]
    with open(log, "w", encoding="utf-8") as fh:
        subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT, check=False)
    with open(log, encoding="utf-8") as fh:
        info = json.load(fh)
    im = info["images"][0]
    from PIL import Image
    with Image.open(im["path"]) as img:
        g = img.convert("L")
        w, h = g.size
        px = g.load()
        # the navy bar is the only tall dark block: find it in the top half
        bar_left = None
        for x in range(2, w - 2):
            col = [px[x, y] for y in range(2, h // 2)]
            if sum(1 for v in col if v < 120) > (h // 2) * 0.3:
                bar_left = x
                break
        rule_top = None
        for y in range(2, h - 2):
            if sum(1 for x in range(2, min(w - 2, 400)) if px[x, y] < 200) > 100:
                rule_top = y
                break
    return w, h, bar_left, rule_top


if __name__ == "__main__":
    os.makedirs(TMP, exist_ok=True)
    cases = [
        ("full100", 13.3333, 7.5, 1.0, 100),
        ("full175", 13.3333, 7.5, 1.0, 175),
        ("half175", 13.3333, 7.5, 1.0 / 1.75, 175),
        ("half100", 13.3333, 7.5, 1.0 / 1.75, 100),
    ]
    print("bar left edge drawn at %.2f in x scale, rule top at %.2f in x scale"
          % (BAR_X, BAR_Y))
    for tag, pw, ph, scale, dpi in cases:
        path = make(tag, pw, ph, scale)
        w, h, bl, rt = run(tag, path, dpi)
        ppi_canvas = w / pw
        ppi_content = (bl / (BAR_X * scale)) if bl else -1
        ppi_vertical = (rt / (BAR_Y * scale)) if rt else -1
        print("%-8s scale %.4f dpi %-4d  canvas %4dx%-4d  ppi_canvas %6.2f  "
              "bar_left %4s -> ppi_content %6.2f   rule_top %4s -> ppi_vert %6.2f"
              % (tag, scale, dpi, w, h, ppi_canvas, bl, ppi_content, rt, ppi_vertical))
