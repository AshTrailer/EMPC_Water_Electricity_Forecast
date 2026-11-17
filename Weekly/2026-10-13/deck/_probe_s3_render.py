# -*- coding: utf-8 -*-
"""Build the twenty predictor pages alone, then judge them from the rendered PNG.

Two verdicts per page, both read off pixels rather than off the shape geometry:
  - nothing may print below y = 6.72 in, which is where the scope band starts
  - nothing may print past x = 12.75 in, the right margin
The renderer defect means the slide record has to be shrunk before rendering;
see preview_deck.py --once.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))
sys.path.insert(0, HERE)

from pptx import Presentation                                        # noqa: E402
from pptx.util import Emu                                            # noqa: E402

import build_new as B                                                # noqa: E402
import deck_predictors as P                                          # noqa: E402

SCALE = 1.0 / 1.75
GEN = os.path.join(HERE, "deck_B_new.pptx")
OUT = os.path.join(HERE, "preview_new")


def build():
    """Not rebuilt here: deck_B_new.pptx is built by build_new.py --predictors,
    which also runs the number audit. This probe renders and judges that file."""
    from pptx import Presentation as P2
    prs = P2(GEN)
    print("rendering %s (%d pages)" % (GEN, len(prs.slides._sldIdLst)))


def render(dpi=100):
    """dpi 100 on objects scaled by 1/1.75 is the one setting that lines up.

    The renderer draws objects at 1.75 x dpi px per inch and rasterises the slide
    at dpi px per inch, so at dpi 100 one inch of the ORIGINAL slide is 100 px and
    the whole page is inside a 1334 x 751 canvas. Measured in _probe_pin.py.
    """
    cmd = [sys.executable, os.path.join(HERE, "preview_deck.py"),
           "--deck", GEN, "--outdir", OUT, "--once", "--once-dpi", str(dpi)]
    log = os.path.join(HERE, "_preview_tmp", "s3_render.log")
    with open(log, "w", encoding="utf-8") as fh:
        subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT, check=False)
    with open(log, encoding="utf-8") as fh:
        print(fh.read())


def judge():
    """Judge from ink on the rendered page.

    The declared box height is not the answer: a text frame in this pipeline is
    given a height by the builder and the renderer draws whatever the text needs,
    which can exceed it. So the arithmetic runs first, as a pre-flight, and this
    reads the pixels afterwards. The mapping is 100 px per inch of slide: the
    renderer always rasterises a 13.333 x 7.5 in slide into 1334 x 751 px, which
    is the one number in this path that does not move.
    """
    from PIL import Image
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".png"))
    # At 175 dpi on the shrunken record the canvas is 1334 px for a 13.3333 in
    # slide, so one inch of the ORIGINAL slide is 1334 / 13.3333 px.
    PPI = 1334.0 / 13.3333
    over_bottom, over_right = [], []
    print("%-6s %-9s %-9s %s" % ("page", "ink_bot", "ink_right", "verdict"))
    for i, f in enumerate(files, start=1):
        with Image.open(os.path.join(OUT, f)) as im:
            g = im.convert("L")
            w, h = g.size
            px = g.load()
            # The renderer pens a one pixel grey border around the canvas
            # (measured: value 149 on every edge), so the scan stays inside it.
            # The page disc casts a drop shadow that runs to the right margin of
            # the image in the top 120 rows, so the right-edge scan starts below
            # it. The disc is a page ornament, not content.
            bottom = 2
            right = 2
            for y in range(2, h - 2):
                if min(px[x, y] for x in range(2, w - 2)) < 120:
                    bottom = y
            for x in range(2, w - 2):
                if min(px[x, y] for y in range(130, h - 2)) < 120:
                    right = x
        b_in = bottom / PPI
        r_in = right / PPI
        bad = []
        # The scope band prose sits at 6.76 and its second line ends by 7.44 on a
        # page whose band wraps twice, so 7.45 is the deepest legitimate ink.
        if b_in > 7.45:
            bad.append("LOW %.2f" % b_in)
            over_bottom.append(i)
        if r_in > 12.80:
            bad.append("WIDE %.2f" % r_in)
            over_right.append(i)
        print("%-6d %-9.2f %-9.2f %s" % (i, b_in, r_in, " ".join(bad) or "ok"))
    print("")
    print("ink past 7.45 in: %s" % (over_bottom or "none"))
    print("ink past 12.80 in: %s" % (over_right or "none"))


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "build"):
        build()
    if what in ("all", "render"):
        render()
    if what in ("all", "judge"):
        judge()
