# -*- coding: utf-8 -*-
"""What does the renderer actually do with page size and --dpi?

The preview workaround depends on two numbers agreeing: the pixels the renderer
gives one inch of slide, and the pixels the canvas gives one inch of slide. This
probe measures both by drawing a mark at a known coordinate on four page sizes
and reading where it lands.
"""

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))

from pptx import Presentation                                        # noqa: E402
from pptx.util import Inches                                         # noqa: E402

import deck_kit as K                                                 # noqa: E402

NODE = r"C:\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe"
CLI = (r"C:\DeepSeek Harness\resources\app.asar.unpacked\dsh\node_modules"
       r"\@deepseek-ai\libreoffice-kit\lib\cli.js")
TMP = os.path.join(HERE, "_preview_tmp")


def once(tag, page_w, page_h, dpi):
    prs = Presentation()
    prs.slide_width = Inches(page_w)
    prs.slide_height = Inches(page_h)
    s = K.blank(prs)
    # a bar at x = 1.00 in, 0.10 in wide, and a bar at y = 1.00 in
    K.add_rect(s, 1.00, 0.50, 0.10, 1.00, fill=K.AMBER)
    K.add_rect(s, 0.50, 1.00, 1.00, 0.10, fill=K.NAVY)
    path = os.path.join(TMP, "ps_%s.pptx" % tag)
    prs.save(path)
    outdir = os.path.join(TMP, "ps_%s" % tag)
    cmd = [NODE, CLI, "render", "--input", path, "--output-dir", outdir, "--dpi", str(dpi)]
    log = os.path.join(TMP, "ps_%s.json" % tag)
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
        # the amber bar is the tallest dark column block; find its left edge and
        # the navy bar's top edge
        def first_dark_col(y):
            for x in range(w):
                if px[x, y] < 200:
                    return x
            return None

        def first_dark_row(x):
            for y in range(h):
                if px[x, y] < 200:
                    return y
            return None
        amber_left = None
        for x in range(w):
            if sum(1 for y in range(h) if px[x, y] < 200) > h * 0.4:
                amber_left = x
                break
        navy_top = None
        for y in range(h):
            if sum(1 for x in range(w) if px[x, y] < 200) > w * 0.2:
                navy_top = y
                break
    print("%-10s page %6.3f x %6.3f in  dpi %-4d canvas %4dx%-4d  "
          "amber bar left %s px  navy bar top %s px"
          % (tag, page_w, page_h, dpi, w, h, amber_left, navy_top))
    return w, h, amber_left, navy_top


if __name__ == "__main__":
    os.makedirs(TMP, exist_ok=True)
    once("a", 13.3333, 7.5, 100)
    once("b", 13.3333, 7.5, 175)
    once("c", 7.6190, 4.2857, 175)
    once("d", 7.6190, 4.2857, 100)
    once("e", 26.6667, 15.0, 100)
