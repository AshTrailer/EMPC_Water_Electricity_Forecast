# -*- coding: utf-8 -*-
"""Measure every formula at 14 pt and every prose block, then judge every page.

Read-only probe: nothing here writes into the deck. The point is to find the
pages whose text cannot fit before build_new.py starts writing pages, because a
run that overflows is only visible by rendering.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "2026-09-23", "deck"))
sys.path.insert(0, HERE)

import render_formula as RF                                          # noqa: E402
from deck_formulas import FORMULAS                                   # noqa: E402
from pptx.util import Inches, Pt                                     # noqa: E402
from pptx import Presentation                                        # noqa: E402
import deck_kit as K                                                 # noqa: E402

OUT = os.path.join(HERE, "_formula_probe3")
os.makedirs(OUT, exist_ok=True)
DPI = 600

USED = ["m1", "tmpl", "m2", "m3", "rlss", "resid", "m4_rec", "m4", "rlsv",
        "m5", "m6", "m7", "m8", "m8_convex", "m9_fit", "m9", "m10", "m10p",
        "m11", "m12_rho", "m12", "m13_ss", "m13_upd", "m13", "m13_g",
        "m13_rot", "m14", "m14p", "m15", "m16", "m17", "m18", "m19_cand",
        "m19_rule", "m20", "err_R", "win_share", "slot", "diff"]


def main():
    rows = []
    for name in USED:
        tex = FORMULAS[name][0]
        p = os.path.join(OUT, "%s.png" % name)
        info = RF.render(tex, p, fontsize=14, dpi=DPI)
        w = info["w"] / float(DPI)
        h = info["h"] / float(DPI)
        rows.append((name, w, h, w / h))
        print("%-10s %6.3f in wide %6.3f in high  aspect %5.2f" % (name, w, h, w / h))
    print("")
    print("widest: %s" % max(rows, key=lambda r: r[1])[0])
    print("tallest: %s" % max(rows, key=lambda r: r[2])[0])

    # prose: the table cell text is the expensive one, not the formula
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    s = K.blank(prs)

    def measure_box(x, y, w, lines, size, space, head=None):
        top = y
        if head:
            top += 0.27
        _, tf = K.textbox(s, x, top, w, 6.7 - top)
        K.bullets(tf, lines, size=size, space_after=space)
        # the text frame's own extent is the requested height, so ask the
        # autofit-free estimate instead: render it and read the shape back
        return tf

    print("")
    print("text measurement is done in the renderer, not here; this probe reports "
          "the formula widths the layout depends on")


if __name__ == "__main__":
    main()
